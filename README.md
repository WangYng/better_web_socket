# better_web_socket

Advanced web socket based on web_socket_channel.

## Install Started

1. Add this to your **pubspec.yaml** file:

```yaml
dependencies:
  better_web_socket: ^0.0.5
```

2. Install it

```bash
$ flutter packages get
```

## Normal usage

```dart
void connect(BuildContext context) {
  // 监听数据
  receiveDataSubscription?.cancel();
  receiveDataSubscription = context.read<DeviceWebSocketController>().receiveDataStream.listen((data) {
    context.read<DeviceWebSocketController>().handleSendDataResponse(sendingDataId ?? 0, true);
    setState(() {
      receiveDataList.add("${DateTime.now().toString().substring(0, 19)} $data");
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

void sendData() {
  sendingDataId = context.read<DeviceWebSocketController>().sendData(jsonEncode(loginData), retryCount: 3);
}
```

## Feature
- [x] reconnect
- [x] delay disconnect
- [x] simulate HTTP request
