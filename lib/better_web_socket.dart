import 'dart:async';
import 'dart:io';

import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:flutter/cupertino.dart';

class BetterWebSocketController extends ValueNotifier<BetterWebSocketValue> {
  BetterWebSocketController(String url) : super(BetterWebSocketValue(url: url));

  BetterWebSocketApi _api;

  StreamSubscription _stopSocketSubscription;

  BetterWebSocketReceiveDataCallback _onReceiveDataCallback;

  set onReceiveDataCallback(BetterWebSocketReceiveDataCallback value) {
    _onReceiveDataCallback = value;
  }

  /// 连接 web socket
  startWebSocketConnect({
    Duration pingInterval = const Duration(seconds: 30),
    Iterable<String> protocols,
    Map<String, dynamic> headers,
    CompressionOptions compression = CompressionOptions.compressionDefault,
  }) {
    // 复用socket
    if (_api != null) {
      _api.onReceiveDataCallback = _onReceiveDataCallback;
      // 停止关闭socket
      if (_stopSocketSubscription != null) {
        _stopSocketSubscription.cancel();
        _stopSocketSubscription = null;
      }
      return;
    }

    _api = BetterWebSocketApi();
    _api.onReceiveDataCallback = _onReceiveDataCallback;
    _api.startWebSocketConnect(
      value.url,
      socketStateCallback: (bool state) {
        value = value.copyWith(socketState: state);
      },
      loginStateCallback: (bool state) {
        value = value.copyWith(loginState: state);
      },
      pingInterval: pingInterval,
      protocols: protocols,
      headers: headers,
      compression: compression,
    );
  }

  /// 断开 web socket
  stopWebSocketConnect({Duration duration = const Duration(seconds: 3)}) {
    if (duration != null && duration != Duration.zero) {
      // 延迟断开
      if (_stopSocketSubscription != null) {
        _stopSocketSubscription.cancel();
      }
      Stream<int> stream() async* {
        await Future.delayed(duration);
        yield 1;
        _api?.stopWebSocketConnect();
        _api?.onReceiveDataCallback = null;
        _api = null;
        _stopSocketSubscription = null;
      }

      _stopSocketSubscription = stream().listen((event) {});
    } else {
      // 立即断开
      _api?.stopWebSocketConnect();
      _api?.onReceiveDataCallback = null;
      _api = null;
    }
  }

  /// 设备登录数据
  setupLoginData(
    String loginData,
    BetterWebSocketLoginCallback onLoginCallback,
  ) {
    _api?.setLoginData(loginData, onLoginCallback);
  }

  /// 发送数据
  sendData(String data) {
    _api?.sendData(data);
  }
}

class BetterWebSocketValue {
  final String url;

  final bool socketState;

  final bool loginState;

  const BetterWebSocketValue({
    this.url,
    this.socketState = false,
    this.loginState = false,
  });

  BetterWebSocketValue copyWith({
    String url,
    bool socketState,
    bool loginState,
  }) {
    return BetterWebSocketValue(
      url: url ?? this.url,
      socketState: socketState ?? this.socketState,
      loginState: loginState ?? this.loginState,
    );
  }
}
