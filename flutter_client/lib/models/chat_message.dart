// models/chat_message.dart
import 'dart:convert';

class ChatMessage {
  final String type; // 'chat', 'system'
  final String? clientId;
  final String? sender;
  final String message;
  final DateTime timestamp;
  
  ChatMessage({
    required this.type,
    this.clientId,
    this.sender,
    required this.message,
    required this.timestamp,
  });
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      type: json['type'],
      clientId: json['clientId'],
      sender: json['sender'],
      message: json['message'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'clientId': clientId,
      'sender': sender,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
