import 'dart:async';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/cupertino.dart';
import 'package:tuple/tuple.dart';
import 'package:web_socket_channel/io.dart';

enum BetterWebSocketConnectState {
  SUCCESS, // 连接成功
  FAIL, // 连接失败
  CONNECTING, // 连接中
}

class BetterWebSocketApi {
  // web socket 连接时必要信息
  String _url;

  // web socket 连接时可选信息
  Duration _pingInterval;
  Iterable<String> _protocols;
  Map<String, dynamic> _headers;
  CompressionOptions _compression;

  // 监听socket状态
  ValueChanged<BetterWebSocketConnectState> socketStateCallback;

  // 监听数据流
  ValueChanged<dynamic> receiveDataCallback;

  // 重试
  int _retryCount;
  int _originRetryCount;
  Duration _retryDuration;
  ValueChanged<int> _retryCallback;

  // web socket 信道
  IOWebSocketChannel _channel;

  // 数据监听
  StreamSubscription _socketSubscription;

  // 网络监听
  StreamSubscription _connectivitySubscription;

  // 连接中
  bool _webSocketConnecting = false;

  // 是否已经关闭
  bool _isStopSocket = false;

  /// 启动WebSocket连接
  startWebSocketConnect(
    String url, {
    int retryCount,
    Duration retryDuration,
    ValueChanged<int> retryCallback,
    Duration pingInterval,
    Iterable<String> protocols,
    Map<String, dynamic> headers,
    CompressionOptions compression = CompressionOptions.compressionDefault,
  }) async {
    _url = url;
    _retryCount = retryCount;
    _originRetryCount = retryCount;
    _retryDuration = retryDuration ?? const Duration(seconds: 1);
    _retryCallback = retryCallback;
    _pingInterval = pingInterval;
    _protocols = protocols;
    _headers = headers;
    _compression = compression;

    _connectWebSocket();
  }

  // 连接web socket, 需要防止多次调用
  _connectWebSocket() async {
    if (_webSocketConnecting) {
      return;
    }

    _webSocketConnecting = true;
    if (socketStateCallback != null) {
      socketStateCallback(BetterWebSocketConnectState.CONNECTING);
    }
    print("web socket 连接中...");

    // 创建连接
    WebSocket socket;
    while (true) {
      try {
        socket = await WebSocket.connect(
          _url,
          protocols: _protocols,
          headers: _headers,
          compression: _compression,
        );
      } catch (error) {
        socket?.close();

        if (_isStopSocket) {
          _webSocketConnecting = false;
          return;
        }

        if (_hasRetryLogic() && _retryCount > 0) {
          print("web socket 连接失败, ${_retryDuration.inSeconds}s 后重试");

          if (_retryCallback != null) {
            _retryCallback(_retryCount);
          }
          _retryCount--;

          await Future.delayed(_retryDuration);

          if (_isStopSocket) {
            _webSocketConnecting = false;
            return;
          }

          continue;
        }

        if (_hasRetryLogic() && _retryCount == 0) {
          print("web socket 连接失败, 重试次数已经用完");
          if (_retryCallback != null) {
            _retryCallback(_retryCount);
          }

          _webSocketConnecting = false;

          if (socketStateCallback != null) {
            socketStateCallback(BetterWebSocketConnectState.FAIL);
          }
          return;
        }

        print("web socket 连接失败");
        _webSocketConnecting = false;
        if (socketStateCallback != null) {
          socketStateCallback(BetterWebSocketConnectState.FAIL);
        }
        return;
      }

      // 关闭连接
      if (_isStopSocket) {
        socket?.close();
        _webSocketConnecting = false;
        return;
      }

      print("web socket 连接成功");
      socket.pingInterval = _pingInterval;
      if (_hasRetryLogic()) {
        _retryCount = _originRetryCount;
      }
      if (socketStateCallback != null) {
        socketStateCallback(BetterWebSocketConnectState.SUCCESS);
      }
      break;
    }

    // 创建通道
    _channel = IOWebSocketChannel(socket);

    // 监听数据
    _socketSubscription = _channel.stream.listen((data) {
      _handleSocketData(data);
    }, onError: (error) {
      print("连接异常");
      _handleSocketError();
    }, onDone: () async {
      print("服务器中断连接");
      _handleSocketError();
    });

    // 监听网络变化
    final currentConnectivity = Connectivity().checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      final initResult = await currentConnectivity;
      if (initResult != result) {
        print("网络波动, 连接中断");
        _handleSocketError();
      }
    });

    _webSocketConnecting = false;
  }

  // 处理连接错误
  _handleSocketError() {
    if (_isStopSocket) {
      return;
    }

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _socketSubscription?.cancel();
    _socketSubscription = null;

    _channel?.sink?.close();
    _channel = null;

    if (socketStateCallback != null) {
      socketStateCallback(BetterWebSocketConnectState.FAIL);
    }

    // 连接断开, 进行重连
    _reconnectWebSocket();
  }

  // 重连
  _reconnectWebSocket() async {
    if (!_hasRetryLogic()) {
      print("web socket 连接异常断开");
      return;
    }

    if (_retryCount == 0) {
      print("web socket 连接异常断开, 重试次数已经用完");
      if (_retryCallback != null) {
        _retryCallback(_retryCount);
      }
      return;
    }

    print("web socket 连接异常断开, ${_retryDuration.inSeconds}s 后重试");

    if (_retryCallback != null) {
      _retryCallback(_retryCount);
    }
    _retryCount--;

    await Future.delayed(_retryDuration);

    if (_isStopSocket) {
      return;
    }

    // 重连web socket
    _connectWebSocket();
  }

  // 处理监听到的数据
  _handleSocketData(dynamic data) async {
    if (_isStopSocket) {
      return;
    }

    print("web socket 收到消息");

    if (receiveDataCallback != null) {
      receiveDataCallback(data);
    }
  }

  /// 中断WebSocket连接
  stopWebSocketConnect() async {
    if (_isStopSocket) {
      return;
    }
    _isStopSocket = true;

    print("web socket 连接关闭");

    if (socketStateCallback != null) {
      socketStateCallback(BetterWebSocketConnectState.FAIL);
    }

    // 关闭网络监听
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // 关闭socket监听
    _socketSubscription?.cancel();
    _socketSubscription = null;

    // 关闭socket
    _channel?.sink?.close();
    _channel = null;
  }

  bool sendData(dynamic data) {
    if (_channel != null && data != null) {
      _channel.sink.add(data);
      return true;
    } else {
      return false;
    }
  }

  // 判断是否有重连逻辑
  bool _hasRetryLogic() {
    return _retryCount != null;
  }
}
