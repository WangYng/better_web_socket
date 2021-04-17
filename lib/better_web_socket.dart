import 'dart:async';
import 'dart:io';

import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:tuple/tuple.dart';

enum BetterWebSocketResponseState {
  SUCCESS, // 消息发送成功
  FAIL, // 消息发送失败
  TIMEOUT, // 消息发送超时
}

class BetterWebSocketController extends ValueNotifier<BetterWebSocketValue> {
  BetterWebSocketController(String url) : super(BetterWebSocketValue(url: url));

  BetterWebSocketApi _api;

  StreamSubscription _stopSocketSubscription;

  StreamController<BetterWebSocketConnectState> _socketConnectStateStreamController = StreamController.broadcast();

  Stream<BetterWebSocketConnectState> get socketConnectStateStream => _socketConnectStateStreamController.stream;

  // 监听数据流
  StreamController<dynamic> _receiveDataStreamController = StreamController.broadcast();

  Stream<dynamic> get receiveDataStream => _receiveDataStreamController.stream;

  // 消息重试监听
  Map<int, StreamSubscription> _sendDataRetrySubscriptionMap = {};

  // 监听消息发送状态
  StreamController<Tuple2<int, BetterWebSocketResponseState>> _responseStateStreamController =
      StreamController.broadcast();

  Stream<Tuple2<int, BetterWebSocketResponseState>> get responseStateStream => _responseStateStreamController.stream;

  /// 连接 web socket
  void startWebSocketConnect({
    int retryCount,
    Duration retryDuration = const Duration(seconds: 1),
    ValueChanged<int> retryCallback,
    Duration pingInterval = const Duration(seconds: 30),
    Iterable<String> protocols,
    Map<String, dynamic> headers,
    CompressionOptions compression = CompressionOptions.compressionDefault,
  }) {
    // 复用socket
    if (_api != null) {
      // 停止关闭socket
      _stopSocketSubscription?.cancel();
      return;
    }

    _api = BetterWebSocketApi();

    _api.socketStateCallback = (state) {
      if (state == BetterWebSocketConnectState.FAIL) {
        _cancelAllSendingWhenSocketAbort();
      }
      value = value.copyWith(socketState: state);
      _socketConnectStateStreamController.sink.add(state);
    };

    _api.receiveDataCallback = (data) {
      _receiveDataStreamController.sink.add(data);
    };

    _api.startWebSocketConnect(
      value.url,
      retryCount: retryCount,
      retryDuration: retryDuration,
      retryCallback: (int remainingCount) {
        if (retryCallback != null) {
          if (remainingCount == 0) {
            _api = null;
          }
          retryCallback(remainingCount);
        }
      },
      pingInterval: pingInterval,
      protocols: protocols,
      headers: headers,
      compression: compression,
    );
  }

  /// 断开 web socket
  void stopWebSocketConnectAfter({Duration duration = const Duration(seconds: 3)}) {
    if (duration != null && duration != Duration.zero) {
      // 延迟断开
      _stopSocketSubscription?.cancel();
      Stream<int> stream() async* {
        await Future.delayed(duration);

        yield 1;

        _api?.stopWebSocketConnect();
        _api?.receiveDataCallback = null;
        _api?.socketStateCallback = null;
        _api = null;
      }

      _stopSocketSubscription = stream().listen((event) {});
    } else {
      // 立即断开
      _api?.stopWebSocketConnect();
      _api?.receiveDataCallback = null;
      _api?.socketStateCallback = null;
      _api = null;
    }
  }

  /// 发送数据. 需要调用 handleSendDataResponse 确认消息回执已经收到
  void sendDataAndWaitResponse(
    int requestId,
    dynamic data, {
    Duration timeoutDuration = const Duration(seconds: 1),
    int retryCount,
    Duration retryDuration,
  }) {
    bool result = _api?.sendData(data) ?? false;
    if (result) {
      print("web socket send data");
    } else {
      // 当前没有连接web socket, 返回失败
      Future.microtask(() {
        handleResponse(requestId, BetterWebSocketResponseState.FAIL);
      });
      return;
    }

    // 监听消息发送超时
    stream() async* {
      // 等待服务器返回结果
      await Future.delayed(timeoutDuration);
      yield 1;

      // 重复发送消息
      if (retryCount != null && retryCount > 0 && retryDuration != null) {
        int count = retryCount;
        while (count > 0) {
          bool result = _api?.sendData(data) ?? false;
          if (result) {
            print("web socket send data");
          } else {
            // 当前没有连接web socket, 返回失败
            handleResponse(requestId, BetterWebSocketResponseState.FAIL);
            return;
          }

          await Future.delayed(retryDuration);
          yield 1;
          count--;
        }
      }

      handleResponse(requestId, BetterWebSocketResponseState.TIMEOUT);
    }

    _sendDataRetrySubscriptionMap[requestId] = stream().listen((event) {});
  }

  // 处理发消息的回执
  void handleResponse(int requestId, BetterWebSocketResponseState state) {
    if (_sendDataRetrySubscriptionMap.containsKey(requestId)) {
      _sendDataRetrySubscriptionMap[requestId]?.cancel();
      _sendDataRetrySubscriptionMap.remove(requestId);
    }

    _responseStateStreamController.sink.add(Tuple2(requestId, state));
  }

  void sendData(dynamic data) {
    _api?.sendData(data);
  }

  // 取消所有发送中的消息
  void _cancelAllSendingWhenSocketAbort() {
    _sendDataRetrySubscriptionMap.keys.forEach((requestId) {
      _sendDataRetrySubscriptionMap[requestId]?.cancel();

      final state = BetterWebSocketResponseState.FAIL;
      _responseStateStreamController.sink.add(Tuple2(requestId, state));
    });

    _sendDataRetrySubscriptionMap.clear();
  }

  @override
  void dispose() {
    stopWebSocketConnectAfter();
    _socketConnectStateStreamController.close();
    _receiveDataStreamController.close();
    _responseStateStreamController.close();
    super.dispose();
  }
}

class BetterWebSocketValue {
  final String url;

  final BetterWebSocketConnectState socketState;

  const BetterWebSocketValue({
    this.url,
    this.socketState = BetterWebSocketConnectState.FAIL,
  });

  BetterWebSocketValue copyWith({
    String url,
    BetterWebSocketConnectState socketState,
  }) {
    return BetterWebSocketValue(
      url: url ?? this.url,
      socketState: socketState ?? this.socketState,
    );
  }
}
