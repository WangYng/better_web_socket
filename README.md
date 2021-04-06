# better_web_socket

Advanced web socket based on web_socket_channel.

## Install Started

1. Add this to your **pubspec.yaml** file:

```yaml
dependencies:
  better_web_socket: ^0.0.2
```

2. Install it

```bash
$ flutter packages get
```

## Normal usage

```dart
context.read<DeviceWebSocketController>().startWebSocketConnect(
  (data) async {
    setState(() {
      receiveDataList
          .add("${DateTime.now().toString().substring(0, 19)} $data");
      scrollController.animateTo(0,
          duration: Duration(milliseconds: 350), curve: Curves.linear);
    });
  },
  pingInterval: Duration(seconds: 15),
);
```

## Feature
- [x] reconnect
- [x] delay disconnect
- [x] login logic


