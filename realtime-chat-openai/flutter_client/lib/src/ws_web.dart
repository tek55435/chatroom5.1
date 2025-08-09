// lib/src/ws_web.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'ws_stub.dart';

class WsClient extends WsClientBase {
  html.WebSocket? _socket;
  WsClient(String uri) : super(uri);

  @override
  Future<void> connect() async {
    _socket = html.WebSocket(uri);
    _socket!.onOpen.listen((_) {
      onOpen?.call();
    });
    _socket!.onMessage.listen((event) {
      onMessage?.call(event.data as String);
    });
    _socket!.onClose.listen((_) {
      onClose?.call();
    });
  }

  @override
  void send(String msg) => _socket?.send(msg);

  @override
  Future<void> close() async {
    _socket?.close();
    _socket = null;
  }
}
