// lib/src/ws_stub.dart
abstract class WsClientBase {
  final String uri;
  WsClientBase(this.uri);

  Future<void> connect();
  void send(String msg);
  Future<void> close();

  void Function()? onOpen;
  void Function()? onClose;
  void Function(String data)? onMessage;
}
