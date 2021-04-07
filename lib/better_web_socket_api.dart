import 'dart:async';
import 'dart:io';

import 'package:connectivity/connectivity.dart';
import 'package:web_socket_channel/io.dart';

enum BetterWebSocketLoginResult {
  SUCCESS,
  FAIL,
  TIMEOUT,
}

typedef BetterWebSocketLoginCallback = Future<BetterWebSocketLoginResult>
    Function(String data);

typedef BetterWebSocketReceiveDataCallback = Future<void> Function(String data);

typedef BetterWebSocketStateCallback = void Function(bool state);

typedef BetterWebSocketLoginStateCallback = void Function(bool state);

class BetterWebSocketApi {
  // web socket 连接时必要信息
  String _url;
  BetterWebSocketStateCallback _socketStateCallback;
  BetterWebSocketReceiveDataCallback _onReceiveDataCallback;
  set onReceiveDataCallback(BetterWebSocketReceiveDataCallback value) {
    _onReceiveDataCallback = value;
  }
  Duration _pingInterval;
  Iterable<String> _protocols;
  Map<String, dynamic> _headers;
  CompressionOptions _compression;

  // web socket 信道
  IOWebSocketChannel _channel;

  // 数据监听
  StreamSubscription _subscription;

  // 网络监听
  StreamSubscription _connectivitySubscription;

  // 是否已经关闭
  bool _isStopSocket = false;

  // 是否在连接中
  bool _isSocketConnecting = false;

  // 登录相关的数据
  String _loginData;

  // 登录结果回调
  BetterWebSocketLoginCallback _onLoginCallback;

  // 等待登录结果回调
  Completer<BetterWebSocketLoginResult> _loginCompleter;

  // 等待流程事件
  StreamSubscription _loginSubscription;

  // 登录状态
  BetterWebSocketLoginStateCallback _loginStateCallback;

  /// 启动WebSocket连接
  startWebSocketConnect(
    String url, {
    BetterWebSocketStateCallback socketStateCallback,
    BetterWebSocketLoginStateCallback loginStateCallback,
    Duration pingInterval,
    Iterable<String> protocols,
    Map<String, dynamic> headers,
    CompressionOptions compression = CompressionOptions.compressionDefault,
  }) async {
    _url = url;
    _socketStateCallback = socketStateCallback;
    _loginStateCallback = loginStateCallback;
    _pingInterval = pingInterval;
    _protocols = protocols;
    _headers = headers;
    _compression = compression;

    _connectWebSocket();
  }

  _connectWebSocket() async {
    // 开始连接
    if (_socketStateCallback != null) {
      _socketStateCallback(false);
    }
    if (_loginStateCallback != null) {
      _loginStateCallback(false);
    }
    _isSocketConnecting = true;

    // 创建连接
    WebSocket socket;
    while (!_isStopSocket) {
      print("web socket 连接中...");
      try {
        socket = await WebSocket.connect(
          _url,
          protocols: _protocols,
          headers: _headers,
          compression: _compression,
        );
      } catch (error) {
        print("web socket 连接失败, 1s 后重试");
        // 关闭连接, 并重试
        socket?.close();
        await Future.delayed(Duration(seconds: 1));

        continue;
      }

      print("web socket 连接成功");
      socket.pingInterval = _pingInterval;

      // 关闭连接
      if (_isStopSocket) {
        socket?.close();
        return;
      }

      break;
    }

    // 创建通道
    _channel = IOWebSocketChannel(socket);

    // 连接成功
    if (_socketStateCallback != null) {
      _socketStateCallback(true);
    }
    _isSocketConnecting = false;

    // 处理连接错误
    void handleSocketError() {
      _channel = null;
      if (_socketStateCallback != null) {
        _socketStateCallback(false);
      }
      if (_loginStateCallback != null) {
        _loginStateCallback(false);
      }

      // 连接断开, 进行重连
      if (!_isStopSocket) {
        _reConnectWebSocket();
      }
    }

    // 监听数据
    _subscription = _channel.stream.listen((data) async {
      if (!_isStopSocket) {
        if (_loginCompleter != null && !_loginCompleter.isCompleted) {
          print("web socket 收到登录结果");

          // 处理登录结果
          final loginResult = await _onLoginCallback(data);
          _loginCompleter.complete(loginResult);
        } else if (_onReceiveDataCallback != null) {
          print("web socket 收到消息");

          // 解析数据, 更新设备信息
          _onReceiveDataCallback(data);
        }
      }
    }, onError: (error) {
      handleSocketError();
    }, onDone: () async {
      handleSocketError();
    });

    // 监听网络变化
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (_channel != null) {
        _channel.sink.close();
      }
      handleSocketError();
    });
  }

  // 发生错误重连
  _reConnectWebSocket() async {

    if (_isSocketConnecting || _isStopSocket) {
      return;
    }

    _isSocketConnecting = true;

    print("web socket 连接异常断开, 1s 后重试");
    await Future.delayed(Duration(seconds: 1));

    if (_isStopSocket) {
      return;
    }

    // 重连web socket
    _connectWebSocket();

    // 重新登录
    if (_loginData != null && _onLoginCallback != null) {
      final loginData = _loginData;
      final onLoginCallback = _onLoginCallback;
      _loginData = null;
      _onLoginCallback = null;
      setLoginData(loginData, onLoginCallback);
    }
  }

  /// 中断WebSocket连接
  stopWebSocketConnect() async {
    if (_isStopSocket) {
      return;
    }

    print("web socket 连接关闭");

    _isStopSocket = true;
    _isSocketConnecting = false;

    // 取消重登
    if (_loginSubscription != null) {
      _loginSubscription.cancel();
    }

    // 如果登录没有完成, 强制结束登录
    if (_loginCompleter != null && !_loginCompleter.isCompleted) {
      _loginCompleter.complete(BetterWebSocketLoginResult.FAIL);
    }

    // 更新状态
    if (_socketStateCallback != null) {
      _socketStateCallback(false);
    }
    if (_loginStateCallback != null) {
      _loginStateCallback(false);
    }

    // 关闭socket
    if (_channel != null) {
      _channel.sink.close();
    }

    // 关闭数据监听
    if (_subscription != null) {
      _subscription.cancel();
    }

    // 关闭网络监听
    if (_connectivitySubscription != null) {
      _connectivitySubscription.cancel();
    }
  }

  /// 设置登录数据
  void setLoginData(
    String loginData,
    BetterWebSocketLoginCallback onLoginCallback,
  ) {
    if (_loginData == loginData) {
      return;
    }

    _loginData = loginData;
    _onLoginCallback = onLoginCallback;

    if (_loginSubscription != null) {
      _loginSubscription.cancel();
    }

    _loginSubscription = _login(loginData, onLoginCallback).listen((event) {});
    _loginSubscription.onDone(() {
      _loginSubscription = null;
    });
  }

  /// 登录
  Stream<int> _login(
    String loginData,
    BetterWebSocketLoginCallback onLoginCallback,
  ) async* {
    if (_loginStateCallback != null) {
      _loginStateCallback(false);
    }

    _loginCompleter = Completer();

    // 发送数据给服务器进行登录
    if (_channel != null && loginData != null) {
      _channel.sink.add(loginData);

      print("web socket 发送登录信息");

      // 控制登录超时时间
      Future.delayed(Duration(seconds: 3)).then((value) {
        if (!_loginCompleter.isCompleted) {
          _loginCompleter.complete(BetterWebSocketLoginResult.TIMEOUT);
        }
      });
    } else {
      // socket连接中, 等待一会再试
      await Future.delayed(Duration(seconds: 1));
      if (!_loginCompleter.isCompleted) {
        _loginCompleter.complete(BetterWebSocketLoginResult.TIMEOUT);
      }
    }

    // 等待服务器返回登录结果
    final result = await _loginCompleter.future;

    yield 1;

    // 登录成功
    if (result == BetterWebSocketLoginResult.SUCCESS) {
      if (_loginStateCallback != null) {
        _loginStateCallback(true);
      }
      return;
    }

    // 登录失败
    if (result == BetterWebSocketLoginResult.FAIL) {
      // 等待一会再重试登录
      await Future.delayed(Duration(seconds: 3));

      yield 2;

      yield* _login(loginData, onLoginCallback);
    }

    // 登录超时
    if (result == BetterWebSocketLoginResult.TIMEOUT) {
      yield* _login(loginData, onLoginCallback);
    }
  }

  void sendData(String data) {
    if (_channel != null && data != null) {
      _channel.sink.add(data);
    }
  }
}
