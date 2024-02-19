import 'dart:async';
import 'dart:io';

import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:flutter/cupertino.dart';

enum BetterWebSocketResponseState {
  SUCCESS, // 消息发送成功
  FAIL, // 消息发送失败
  TIMEOUT, // 消息发送超时
}

class BetterWebSocketController extends ValueNotifier<BetterWebSocketValue> {

  BetterWebSocketController(String url) : super(BetterWebSocketValue(url: url));

  BetterWebSocketApi? _api;

  StreamSubscription? _stopSocketSubscription;

  StreamController<BetterWebSocketConnectState> _socketConnectStateStreamController = StreamController.broadcast();

  Stream<BetterWebSocketConnectState> get socketConnectStateStream => _socketConnectStateStreamController.stream;

  // 监听数据流
  StreamController<dynamic> _receiveDataStreamController = StreamController.broadcast();

  Stream<dynamic> get receiveDataStream => _receiveDataStreamController.stream;

  /// 连接 web socket
  void startWebSocketConnect({
    int? retryCount,
    Duration retryDuration = const Duration(seconds: 1),
    ValueChanged<int>? retryCallback,
    Duration pingInterval = const Duration(seconds: 30),
    Iterable<String>? protocols,
    Map<String, dynamic>? headers,
    CompressionOptions compression = CompressionOptions.compressionDefault,
    String? proxy,
  }) {
    // 如果socket没有中断，再次连接时，直接复用
    if (_api != null && _api?.isStopSocket == false) {
      // 停止关闭socket
      _stopSocketSubscription?.cancel();
      return;
    }

    _api = BetterWebSocketApi();

    _api?.socketStateCallback = (state) {
      value = value.copyWith(socketState: state);
      _socketConnectStateStreamController.sink.add(state);
    };

    _api?.receiveDataCallback = (data) {
      _receiveDataStreamController.sink.add(data);
    };

    _api?.startWebSocketConnect(
      value.url,
      retryCount: retryCount,
      retryDuration: retryDuration,
      retryCallback: (int remainingCount) {
        if (retryCallback != null) {
          retryCallback(remainingCount);
        }
      },
      pingInterval: pingInterval,
      protocols: protocols,
      headers: headers,
      compression: compression,
      proxy: proxy,
    );
  }

  /// 断开 web socket
  void stopWebSocketConnectAfter({Duration duration = const Duration(seconds: 3)}) {
    if (duration != Duration.zero) {
      // 延迟断开
      Stream<int> handler() async* {
        await Future.delayed(duration);
        yield 1;

        _api?.stopWebSocketConnect();
        _api = null;
      }

      _stopSocketSubscription?.cancel();
      _stopSocketSubscription = handler().listen((event) {});
    } else {
      // 立即断开
      _stopSocketSubscription?.cancel();
      _api?.stopWebSocketConnect();
      _api = null;
    }
  }

  void sendData(dynamic data) {
    _api?.sendData(data);
  }

  @override
  void dispose() {
    stopWebSocketConnectAfter();
    _socketConnectStateStreamController.close();
    _receiveDataStreamController.close();
    super.dispose();
  }
}

class BetterWebSocketValue {
  final String url;

  final BetterWebSocketConnectState socketState;

  const BetterWebSocketValue({
    required this.url,
    this.socketState = BetterWebSocketConnectState.FAIL,
  });

  BetterWebSocketValue copyWith({
    String? url,
    BetterWebSocketConnectState? socketState,
  }) {
    return BetterWebSocketValue(
      url: url ?? this.url,
      socketState: socketState ?? this.socketState,
    );
  }
}
