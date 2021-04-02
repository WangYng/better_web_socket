import 'dart:convert';

import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:better_web_socket_example/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class NormalPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _NormalPageState();
  }
}

class _NormalPageState extends State<NormalPage> {
  List<String> receiveDataList = [];

  ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceWebSocketController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('web socket'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  controller: scrollController,
                  reverse: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: receiveDataList.map((e) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.all(10),
                          child: Text(e),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              constraints: BoxConstraints.expand(),
              color: Colors.grey.withOpacity(0.3),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      child: Text("url : ${controller.value.url}"),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      child: Text(
                          "socket connected : ${controller.value.socketState ? "🟢" : "🔴"}"),
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      child: Text(
                          "socket login state : ${controller.value.loginState ? "🟢" : "🔴"}"),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          child: Text("connect"),
                          onPressed: () {
                            connect(context);
                          },
                        ),
                        CupertinoButton(
                          child: Text("disconnect"),
                          onPressed: () {
                            disconnect(context);
                          },
                        ),
                      ],
                    ),
                    CupertinoButton(
                      child: Text("login"),
                      onPressed: () {
                        login(context);
                      },
                    ),
                    CupertinoButton(
                      child: Text("clear log"),
                      onPressed: () {
                        clear(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void login(BuildContext context) {
    final loginData = {
      "authorization": "HBAPI MTEyNjA0MjU6cnFldGdqYXZhbDhxZDAzZzEzcGU0Zmtlb2s=",
      "msgType": 1
    };

    context.read<DeviceWebSocketController>().setupLoginData(
      jsonEncode(loginData),
      (data) async {
        setState(() {
          receiveDataList
              .add("${DateTime.now().toString().substring(0, 19)} $data");
          scrollController.animateTo(0,
              duration: Duration(milliseconds: 350), curve: Curves.linear);
        });
        return BetterWebSocketLoginResult.SUCCESS;
      },
    );
  }

  void connect(BuildContext context) {
    context
        .read<DeviceWebSocketController>()
        .startWebSocketConnect((data) async {
      setState(() {
        receiveDataList
            .add("${DateTime.now().toString().substring(0, 19)} $data");
        scrollController.animateTo(0,
            duration: Duration(milliseconds: 350), curve: Curves.linear);
      });
    });
  }

  void disconnect(BuildContext context) {
    context
        .read<DeviceWebSocketController>()
        .stopWebSocketConnect(duration: Duration(seconds: 3));
  }

  void clear(BuildContext context) {
    setState(() {
      receiveDataList.clear();
    });
  }
}
