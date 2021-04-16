import 'dart:async';
import 'dart:convert';

import 'package:better_web_socket/better_web_socket.dart';
import 'package:better_web_socket/better_web_socket_api.dart';
import 'package:better_web_socket_example/constant.dart';
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
  TextEditingController textEditingController = TextEditingController();

  StreamSubscription receiveDataSubscription;
  StreamSubscription sendDataResponseStateSubscription;

  int sendingDataId;

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
                            disconnect(context, Duration(seconds: 3));
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
                            disconnect(context, Duration.zero);
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

  void connect(BuildContext context) {
    // 监听数据
    receiveDataSubscription?.cancel();
    receiveDataSubscription = context.read<DeviceWebSocketController>().receiveDataStream.listen((data) {
      context.read<DeviceWebSocketController>().handleSendDataResponse(sendingDataId ?? 0, true);
      setState(() {
        receiveDataList.add("${DateTime.now().toString().substring(0, 19)} $data");
        scrollController.animateTo(0, duration: Duration(milliseconds: 350), curve: Curves.linear);
      });
    });

    // 监听socket请求数据响应结果
    sendDataResponseStateSubscription?.cancel();
    sendDataResponseStateSubscription = context.read<DeviceWebSocketController>().sendDataResponseStateStream.listen((data) {
      String result = "";
      switch(data.item2) {
        case BetterWebSocketSendDataResponseState.SUCCESS:
          result = "send data success";
          break;
        case BetterWebSocketSendDataResponseState.FAIL:
          result = "send data failure";
          break;
        case BetterWebSocketSendDataResponseState.TIMEOUT:
          result = "send data timeout";
          break;
      }
      print(result);
    });

    // 连接 web socket
    context.read<DeviceWebSocketController>().startWebSocketConnect(retryCount: double.maxFinite.toInt());
  }

  void disconnect(BuildContext context, Duration duration) {
    context.read<DeviceWebSocketController>().stopWebSocketConnectAfter(duration: duration);
  }

  void clear(BuildContext context) {
    setState(() {
      receiveDataList.clear();
    });
  }

  void sendText(String content) {
    sendingDataId = context.read<DeviceWebSocketController>().sendData(content, retryCount: 3);
  }

  void sendData() {
    sendingDataId = context.read<DeviceWebSocketController>().sendData(jsonEncode(loginData), retryCount: 3);
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
    receiveDataSubscription.cancel();
    sendDataResponseStateSubscription.cancel();
    super.dispose();
  }
}
