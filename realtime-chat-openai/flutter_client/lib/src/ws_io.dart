// lib/src/ws_io.dart
import 'dart:io' as io;
import 'ws_stub.dart';

class WsClient extends WsClientBase {
  io.WebSocket? _socket;
  WsClient(String uri) : super(uri);

  @override
  Future<void> connect() async {
    // Remove ws:// or wss:// prefix as io.WebSocket.connect requires full uri
    _socket = await io.WebSocket.connect(uri);
    onOpen?.call();
    _socket!.listen((data) {
      onMessage?.call(data.toString());
    }, onDone: () {
      onClose?.call();
    }, onError: (e) {
      onClose?.call();
    });
  }

  @override
  void send(String msg) {
    _socket?.add(msg);
  }

  @override
  Future<void> close() async {
    await _socket?.close();
    _socket = null;
  }
}
