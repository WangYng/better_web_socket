import 'dart:async';
import 'dart:convert';

import 'package:better_web_socket/better_web_socket.dart';
import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:better_web_socket_example/constant.dart';
import 'package:better_web_socket_example/normal_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: MyWebSocketController()),
      ],
      child: MaterialApp(
        home: MainPage(),
      ),
    );
  }
}

class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('better web socket example app'),
      ),
      body: Center(
        child: Container(
          child: CupertinoButton(
            child: Text("WebSocket Test"),
            onPressed: () {
              Navigator.of(context).push(CupertinoPageRoute(
                builder: (context) {
                  return NormalPage();
                },
              ));
            },
          ),
        ),
      ),
    );
  }
}

class MyWebSocketController extends BetterWebSocketController {
  StreamController<void> _loginCompleteStreamController = StreamController.broadcast();

  Stream<dynamic> get loginCompleteStream => _loginCompleteStreamController.stream;

  StreamSubscription _socketConnectSubscription;

  StreamSubscription<dynamic> _receiveDataSubscription;
  StreamSubscription<Tuple2<int, BetterWebSocketResponseState>> _responseStateSubscription;
  int _clientRequestId;

  MyWebSocketController() : super(serverUrl) {
    // login when socket connected
    _socketConnectSubscription?.cancel();
    _socketConnectSubscription = socketConnectStateStream.listen((event) {
      if (event == BetterWebSocketConnectState.SUCCESS) {
        _stopLogin();
        _login();
      } else {
        _stopLogin();
      }
    });
  }

  void _login() async {
    _receiveDataSubscription = receiveDataStream.listen((data) {
      handleResponse(_clientRequestId, BetterWebSocketResponseState.SUCCESS);
    });

    _responseStateSubscription = responseStateStream.listen((data) {
      if (data.item1 == _clientRequestId && data.item2 == BetterWebSocketResponseState.SUCCESS) {
        _loginComplete();
        _loginCompleteStreamController.sink.add(null);
      }
    });

    _clientRequestId = DateTime.now().millisecondsSinceEpoch;
    sendDataAndWaitResponse(
      _clientRequestId,
      jsonEncode(loginData),
      retryCount: double.maxFinite.toInt(),
      retryDuration: Duration(seconds: 1),
    );
  }

  _stopLogin() {
    if (_clientRequestId != null) {
      handleResponse(_clientRequestId, BetterWebSocketResponseState.FAIL);
    }
    _receiveDataSubscription?.cancel();
    _responseStateSubscription?.cancel();
  }

  _loginComplete() {
    _clientRequestId = null;
    _receiveDataSubscription?.cancel();
    _responseStateSubscription?.cancel();
  }

  @override
  void dispose() {
    _stopLogin();
    _socketConnectSubscription?.cancel();
    _loginCompleteStreamController.close();
    super.dispose();
  }
}
