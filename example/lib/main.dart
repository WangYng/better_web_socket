import 'package:better_web_socket/better_web_socket.dart';
import 'package:better_web_socket_example/constant.dart';
import 'package:better_web_socket_example/normal_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    return ChangeNotifierProvider(
      create: (_) => BetterWebSocketController(serverUrl),
      child: MaterialApp(home: MainPage()),
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
