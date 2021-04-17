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
  StreamSubscription responseStateSubscription;
  StreamSubscription loginCompleteSubscription;

  List<int> clientRequestIdList = [];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MyWebSocketController>();
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

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      MyWebSocketController controller = context.read<MyWebSocketController>();

      receiveDataSubscription?.cancel();
      receiveDataSubscription = controller.receiveDataStream.listen((data) {
        int clientRequestId =
            clientRequestIdList.length > 0 ? clientRequestIdList.first : 0; // TODO  clientRequestId from server
        if (clientRequestIdList.contains(clientRequestId)) {
          controller.handleResponse(clientRequestId, BetterWebSocketResponseState.SUCCESS);
        }
        setState(() {
          receiveDataList.add("${DateTime.now().toString().substring(0, 19)} $data");
          scrollController.animateTo(0, duration: Duration(milliseconds: 350), curve: Curves.linear);
        });
      });

      responseStateSubscription?.cancel();
      responseStateSubscription = controller.responseStateStream.listen((data) {
        int clientRequestId = data.item1;
        if (clientRequestIdList.contains(clientRequestId)) {
          clientRequestIdList.remove(clientRequestId);

          String result = "";
          switch (data.item2) {
            case BetterWebSocketResponseState.SUCCESS:
              result = "send data success";
              break;
            case BetterWebSocketResponseState.FAIL:
              result = "send data failure";
              break;
            case BetterWebSocketResponseState.TIMEOUT:
              result = "send data timeout";
              break;
          }
          print(result);
        }
      });

      loginCompleteSubscription?.cancel();
      loginCompleteSubscription = controller.loginCompleteStream.listen((data) {
        setState(() {
          receiveDataList.add("${DateTime.now().toString().substring(0, 19)} login success");
          scrollController.animateTo(0, duration: Duration(milliseconds: 350), curve: Curves.linear);
        });
      });
    });
  }

  void connect(BuildContext context) {
    MyWebSocketController controller = context.read<MyWebSocketController>();

    // 连接 web socket
    controller.startWebSocketConnect(retryCount: double.maxFinite.toInt(), retryDuration: Duration(seconds: 1));
  }

  void disconnect(BuildContext context, Duration duration) {
    MyWebSocketController controller = context.read<MyWebSocketController>();

    controller?.stopWebSocketConnectAfter(duration: duration);
  }

  void clear(BuildContext context) {
    setState(() {
      receiveDataList.clear();
    });
  }

  void sendData() {
    MyWebSocketController controller = context.read<MyWebSocketController>();

    int clientRequestId = DateTime.now().millisecondsSinceEpoch;
    clientRequestIdList.add(clientRequestId);

    controller.sendDataAndWaitResponse(clientRequestId, jsonEncode(commonData), retryCount: 3);
  }

  void sendText(String content) {
    MyWebSocketController controller = context.read<MyWebSocketController>();
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
    responseStateSubscription?.cancel();
    loginCompleteSubscription?.cancel();
    super.dispose();
  }
}
