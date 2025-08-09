import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime Chat MVP',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<String> messages = [];
  final TextEditingController _controller = TextEditingController();

  // WebRTC objects
  RTCPeerConnection? _pc;
  RTCDataChannel? _dataChannel;

  // WebSocket for non-WebRTC platforms
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebRTC();
    } else {
      _initWebSocket();
    }
  }

  // ----------------------------
  // WebRTC for Web
  // ----------------------------
  Future<void> _initWebRTC() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    };

    _pc = await createPeerConnection(config);

    _dataChannel = await _pc!.createDataChannel('chat');
    _dataChannel!.onMessage = (msg) {
      setState(() => messages.add("Bot: ${msg.text}"));
    };

    _pc!.onIceCandidate = (candidate) {
      // send ICE candidates to server via fetch/websocket
      // in your backend signaling
    };

    // Create offer
    RTCSessionDescription offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    // TODO: send offer to backend signaling endpoint and wait for answer
  }

  // ----------------------------
  // WebSocket for Mobile/Desktop
  // ----------------------------
  void _initWebSocket() {
    _wsChannel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:3000'), // your server WebSocket URL
    );

    _wsChannel!.stream.listen((event) {
      setState(() => messages.add("Bot: $event"));
    });
  }

  void _sendMessage() {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => messages.add("Me: $text"));
    _controller.clear();

    if (kIsWeb) {
      _dataChannel?.send(RTCDataChannelMessage(text));
    } else {
      _wsChannel?.sink.add(jsonEncode({"message": text}));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataChannel?.close();
    _pc?.close();
    _wsChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime Chat MVP')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(messages[index]),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration:
                      const InputDecoration(hintText: "Type a message..."),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
