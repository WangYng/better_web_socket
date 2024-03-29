import 'dart:async';
import 'dart:convert';

import 'package:better_web_socket/better_web_socket.dart';
import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:better_web_socket_example/constant.dart';
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
  TextEditingController textEditingController = TextEditingController();
  BetterWebSocketController controller;

  StreamSubscription receiveDataSubscription;

  List<int> clientRequestIdList = [];

  UniqueKey visibilityDetectorKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BetterWebSocketController>();
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
                      child: Text("socket connected : ${socketState(controller.value.socketState)}"),
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
                            disconnectAfter3Second(context);
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          child: Text("sendData"),
                          onPressed: () {
                            sendData();
                          },
                        ),
                        CupertinoButton(
                          child: Text("disconnect_immediately"),
                          onPressed: () {
                            disconnect(context);
                          },
                        ),
                      ],
                    ),
                    CupertinoButton(
                      child: Text("clear log"),
                      onPressed: () {
                        clear(context);
                      },
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 200,
                          height: 44,
                          child: TextField(
                            decoration: InputDecoration(hintText: "message"),
                            onSubmitted: (String content) {
                              sendText(textEditingController.text);
                              textEditingController.text = "";
                            },
                            controller: textEditingController,
                          ),
                        ),
                        CupertinoButton(
                          child: Text("send"),
                          onPressed: () {
                            sendText(textEditingController.text);
                            textEditingController.text = "";
                          },
                        ),
                      ],
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

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      controller = context.read<BetterWebSocketController>();

      receiveDataSubscription?.cancel();
      receiveDataSubscription = controller.receiveDataStream.listen((data) {
        setState(() {
          receiveDataList.add("${DateTime.now().toString().substring(0, 19)} $data");
          scrollController.animateTo(0, duration: Duration(milliseconds: 350), curve: Curves.linear);
        });
      });
    });
  }

  void connect(BuildContext context) {
    controller.startWebSocketConnect(retryCount: double.maxFinite.toInt(), retryDuration: Duration(seconds: 1));
  }

  void disconnect(BuildContext context) {
    controller?.stopWebSocketConnectAfter(duration: Duration.zero);
  }

  void disconnectAfter3Second(BuildContext context) {
    controller?.stopWebSocketConnectAfter(duration: Duration(seconds: 3));
  }

  void clear(BuildContext context) {
    setState(() {
      receiveDataList.clear();
    });
  }

  void sendData() {
    controller.sendData(jsonEncode(commonData));
  }

  void sendText(String content) {
    controller.sendData(content);
  }

  String socketState(BetterWebSocketConnectState state) {
    String result;
    switch (state) {
      case BetterWebSocketConnectState.SUCCESS:
        result = "🟢";
        break;
      case BetterWebSocketConnectState.FAIL:
        result = "🔴";
        break;
      case BetterWebSocketConnectState.CONNECTING:
        result = "🟡";
        break;
    }

    return result;
  }

  @override
  void dispose() {
    scrollController.dispose();
    textEditingController.dispose();
    receiveDataSubscription?.cancel();
    controller.stopWebSocketConnectAfter();

    super.dispose();
  }
}
