import 'dart:async';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/cupertino.dart';
import 'package:tuple/tuple.dart';
import 'package:web_socket_channel/io.dart';

enum BetterWebSocketConnectState {
  SUCCESS,
  FAIL,
  CONNECTING,
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

  // 重连
  int _retryCount;
  int _originRetryCount;
  Duration _retryDuration;
  ValueChanged<int> _retryCallback;

  // web socket 信道
  WebSocket _socket;
  IOWebSocketChannel _channel;

  // 数据监听
  StreamSubscription _socketSubscription;

  // 网络监听
  StreamSubscription _connectivitySubscription;

  // 连接中
  bool _webSocketConnecting = false;

  // 是否已经关闭
  bool _isStopSocket = false;

  bool get isStopSocket => _isStopSocket;

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
    _retryDuration = retryDuration;
    _retryCallback = retryCallback;
    _pingInterval = pingInterval;
    _protocols = protocols;
    _headers = headers;
    _compression = compression;

    _connectWebSocket();
  }

  // 连接web socket, 需要防止多次调用
  _connectWebSocket() async {
    if (_webSocketConnecting || _isStopSocket) {
      return;
    }

    _webSocketConnecting = true;
    if (socketStateCallback != null) {
      socketStateCallback(BetterWebSocketConnectState.CONNECTING);
    }
    print("web socket connecting...");

    // 创建连接
    while (true) {
      try {
        _socket = await WebSocket.connect(_url, protocols: _protocols, headers: _headers, compression: _compression);
      } catch (error) {
        _socket?.close();

        if (_isStopSocket) {
          return;
        }

        // 重连
        if (_hasRetryLogic() && _retryCount > 0) {
          print("web socket retry after ${_retryDuration.inSeconds}s");

          if (_retryCallback != null) {
            _retryCallback(_retryCount);
          }
          _retryCount--;

          await Future.delayed(_retryDuration);

          if (_isStopSocket) {
            return;
          }

          continue;
        }

        // 重连结束
        if (_hasRetryLogic() && _retryCount == 0) {
          print("web socket connectivity failure");
          if (_retryCallback != null) {
            _retryCallback(_retryCount);
          }

          _webSocketConnecting = false;
          _isStopSocket = true;

          if (socketStateCallback != null) {
            socketStateCallback(BetterWebSocketConnectState.FAIL);
          }
          return;
        }

        // 没有重连流程，正常结束
        print("web socket connectivity failure");
        _webSocketConnecting = false;
        _isStopSocket = true;

        if (socketStateCallback != null) {
          socketStateCallback(BetterWebSocketConnectState.FAIL);
        }
        return;
      }

      // 关闭连接
      if (_isStopSocket) {
        _socket?.close();
        return;
      }

      print("web socket connectivity success");
      _socket.pingInterval = _pingInterval;
      if (_hasRetryLogic()) {
        _retryCount = _originRetryCount;
      }
      if (socketStateCallback != null) {
        socketStateCallback(BetterWebSocketConnectState.SUCCESS);
      }
      break;
    }

    // 创建通道
    _channel = IOWebSocketChannel(_socket);

    // 监听数据
    _socketSubscription = _channel.stream.listen((data) {
      _handleSocketData(data);
    }, onError: (error) {
      print("web socket connectivity error");
      _handleSocketError();
    }, onDone: () async {
      print("web socket connectivity broken");
      _handleSocketError(duration: _retryDuration);
    });

    // 监听网络变化
    final currentConnectivity = Connectivity().checkConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      final initResult = await currentConnectivity;
      if (initResult != result) {
        print("web socket connectivity broken");
        _handleSocketError();
      }
    });

    _webSocketConnecting = false;
  }

  // 处理连接错误
  _handleSocketError({Duration duration}) async {
    if (_isStopSocket) {
      return;
    }

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _socketSubscription?.cancel();
    _socketSubscription = null;

    _channel?.sink?.close();
    _socket = null;
    _channel = null;

    if (_hasRetryLogic()) {
      if (duration != null) {
        if (socketStateCallback != null) {
          socketStateCallback(BetterWebSocketConnectState.FAIL);
        }

        await Future.delayed(duration);
      }
      // 异常中断进行重连
      _connectWebSocket();
    } else {
      // 没有重连流程，正常结束
      _isStopSocket = true;

      if (socketStateCallback != null) {
        socketStateCallback(BetterWebSocketConnectState.FAIL);
      }
    }
  }

  // 处理监听到的数据
  _handleSocketData(dynamic data) async {
    if (_isStopSocket) {
      return;
    }

    print("web socket receive data");

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

    print("web socket stop connectivity");

    // 关闭网络监听
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // 关闭socket监听
    _socketSubscription?.cancel();
    _socketSubscription = null;

    // 关闭socket
    _channel?.sink?.close();
    _socket = null;
    _channel = null;

    if (socketStateCallback != null) {
      socketStateCallback(BetterWebSocketConnectState.FAIL);
    }

    receiveDataCallback = null;
    socketStateCallback = null;
  }

  bool sendData(dynamic data) {
    if (_isStopSocket == false && _channel != null && data != null) {
      _channel.sink.add(data);
      return true;
    } else {
      return false;
    }
  }

  // 判断是否有重连逻辑
  bool _hasRetryLogic() {
    return _retryCount != null && _retryCount > 0 && _retryDuration != null && _retryDuration != Duration.zero;
  }
}
