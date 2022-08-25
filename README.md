# better_web_socket

Advanced web socket based on web_socket_channel.

## Install Started

1. Add this to your **pubspec.yaml** file:

```yaml
dependencies:
  better_web_socket: ^0.1.0
```

2. Install it

```bash
$ flutter packages get
```

## Normal usage

```dart
void receiveData(BuildContext context) {
  MyWebSocketController controller = context.read<MyWebSocketController>();

  receiveDataSubscription?.cancel();
  receiveDataSubscription = controller.receiveDataStream.listen((data) {
    int clientRequestId = parse(data).clientRequestId; // TODO  clientRequestId from server
    controller.handleSendDataResponse(clientRequestId, BetterWebSocketSendDataResponseState.SUCCESS);
  });

  sendDataResponseStateSubscription?.cancel();
  sendDataResponseStateSubscription = controller.sendDataResponseStateStream.listen((data) {
    int clientRequestId = data.item1;
    if (clientRequestIdList.contains(clientRequestId)) {
      clientRequestIdList.remove(clientRequestId);

      String result = "";
      switch (data.item2) {
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
    }
  });
}

void connect(BuildContext context) {
  context.read<DeviceWebSocketController>().startWebSocketConnect(retryCount: double.maxFinite.toInt());
}

void disconnect(BuildContext context, Duration duration) {
  context.read<DeviceWebSocketController>().stopWebSocketConnectAfter(duration: duration);
}

void sendData() {
  context.read<DeviceWebSocketController>().sendDataAndWaitResponse(clientRequestId, data, retryCount: 3);
}
```

## Feature
- [x] reconnect
- [x] delay disconnect
- [x] simulate HTTP request
- [x] auto login when socket connected
