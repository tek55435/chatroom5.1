// providers/chat_session_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class ChatSessionProvider extends ChangeNotifier {
  // Connection properties
  WebSocketChannel? _channel;
  String? _sessionId;
  String? _clientId;
  String? _userName;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _errorMessage;

  // Session properties
  List<ChatMessage> _messages = [];
  Map<String, String> _participants = {}; // clientId -> name
  
  // Constants
  static const String _serverUrl = 'localhost:3001';
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, String> get participants => Map.unmodifiable(_participants);
  String? get sessionId => _sessionId;
  String? get clientId => _clientId;
  String? get userName => _userName;
  
  // Get the full share URL for the current session
  String getShareUrl() {
    final url = html.window.location.href.split('?').first;
    return '$url?sessionId=$_sessionId';
  }
  
  // Set user name
  void setUserName(String name) {
    _userName = name;
    
    // Update server if connected
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'update-user',
        'name': name,
      }));
    }
    
    notifyListeners();
  }
  
  // Connect to chat room
  Future<bool> connectToChatRoom(String? sessionId) async {
    // Reset state
    _errorMessage = null;
    _isConnecting = true;
    notifyListeners();
    
    try {
      // If no sessionId provided, check URL parameters
      if (sessionId == null || sessionId.isEmpty) {
        final uri = Uri.parse(html.window.location.href);
        sessionId = uri.queryParameters['sessionId'];
      }
      
      // If still no sessionId, create a new session
      if (sessionId == null || sessionId.isEmpty) {
        final response = await http.get(Uri.parse('http://$_serverUrl/api/chat/new-session'));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          sessionId = data['sessionId'];
          
          // Update URL with sessionId without refreshing page
          final newUrl = '${html.window.location.href.split('?').first}?sessionId=$sessionId';
          html.window.history.pushState(null, 'Chat Room $sessionId', newUrl);
        } else {
          throw Exception('Failed to create new session');
        }
      }
      
      // Connect to WebSocket with sessionId
      final wsUri = Uri.parse('ws://$_serverUrl?sessionId=$sessionId');
      _channel = WebSocketChannel.connect(wsUri);
      
      // Listen for incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      // Set sessionId state
      _sessionId = sessionId;
      
      return true;
    } catch (e) {
      _errorMessage = 'Failed to connect: ${e.toString()}';
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }
  
  // Disconnect from chat room
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    _isConnecting = false;
    
    // Don't clear the messages so they're still visible after disconnect
    notifyListeners();
  }
  
  // Send a chat message
  void sendMessage(String text) {
    if (!_isConnected || _channel == null) return;
    
    final message = {
      'type': 'chat',
      'text': text,
    };
    
    _channel!.sink.add(jsonEncode(message));
  }
  
  // Handle incoming messages from the server
  void _handleMessage(dynamic data) {
    final message = jsonDecode(data);
    
    switch (message['type']) {
      case 'session':
        _handleSessionMessage(message);
        break;
        
      case 'chat':
        _handleChatMessage(message);
        break;
        
      case 'system':
        _handleSystemMessage(message);
        break;
        
      case 'history':
        _handleHistoryMessage(message);
        break;
        
      default:
        print('Unknown message type: ${message['type']}');
    }
  }
  
  // Handle session initialization message
  void _handleSessionMessage(Map<String, dynamic> message) {
    _sessionId = message['sessionId'];
    _clientId = message['clientId'];
    _isConnected = true;
    _isConnecting = false;
    
    // If we have a username, send it to the server
    if (_userName != null && _userName!.isNotEmpty) {
      _channel!.sink.add(jsonEncode({
        'type': 'update-user',
        'name': _userName,
      }));
    }
    
    notifyListeners();
  }
  
  // Handle chat message
  void _handleChatMessage(Map<String, dynamic> message) {
    final chatMessage = ChatMessage.fromJson(message);
    _messages.add(chatMessage);
    
    // Update participants
    if (message['clientId'] != null && message['sender'] != null) {
      _participants[message['clientId']] = message['sender'];
    }
    
    notifyListeners();
  }
  
  // Handle system message
  void _handleSystemMessage(Map<String, dynamic> message) {
    final systemMessage = ChatMessage.fromJson(message);
    _messages.add(systemMessage);
    notifyListeners();
  }
  
  // Handle history message
  void _handleHistoryMessage(Map<String, dynamic> message) {
    final messagesList = message['messages'] as List;
    final history = messagesList.map((m) => ChatMessage.fromJson(m)).toList();
    
    _messages.addAll(history);
    
    // Extract participants from history
    for (final msg in history) {
      if (msg.type == 'chat' && msg.clientId != null && msg.sender != null) {
        _participants[msg.clientId!] = msg.sender!;
      }
    }
    
    notifyListeners();
  }
  
  // Handle WebSocket error
  void _handleError(error) {
    _errorMessage = 'Connection error: ${error.toString()}';
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }
  
  // Handle WebSocket disconnect
  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
