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
  // Configurable endpoints (override at build time with --dart-define)
  static const String CHAT_WS = String.fromEnvironment(
    'CHAT_WS',
    defaultValue: 'ws://localhost:3001',
  );
  static const String CHAT_HTTP = String.fromEnvironment(
    'CHAT_HTTP',
    defaultValue: 'http://localhost:3001',
  );
  // Connection properties
  WebSocketChannel? _channel;
  String? _sessionId;
  String? _clientId;
  String? _userName;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _errorMessage;
  Timer? _pollTimer;
  int _activeParticipants = 0;
  int _connectedAtMs = 0;

  // Session properties
  List<ChatMessage> _messages = [];
  Map<String, String> _participants = {}; // clientId -> name
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Map<String, String> get participants => Map.unmodifiable(_participants);
  String? get sessionId => _sessionId;
  String? get clientId => _clientId;
  String? get userName => _userName;
  int get activeParticipants => _activeParticipants;
  int get connectedAtMs => _connectedAtMs;
  
  ChatSessionProvider();
  
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
    // Avoid duplicate connects
    if (_isConnected || _isConnecting) {
      return true;
    }
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
        final response = await http.get(Uri.parse('$CHAT_HTTP/api/chat/new-session'));
        
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
      
  // Connect to WebSocket with sessionId (supports ws:// or wss:// via CHAT_WS)
  final separator = CHAT_WS.contains('?') ? '&' : '?';
  final wsUri = Uri.parse('$CHAT_WS${separator}sessionId=$sessionId');
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
  _connectedAtMs = DateTime.now().millisecondsSinceEpoch;
  _startParticipantsPolling();
    
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
  _stopParticipantsPolling();
    notifyListeners();
  }
  
  // Handle WebSocket disconnect
  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
  _connectedAtMs = 0;
  _stopParticipantsPolling();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _stopParticipantsPolling();
    disconnect();
    super.dispose();
  }

  void _startParticipantsPolling() {
    _stopParticipantsPolling();
    if (_sessionId == null || _sessionId!.isEmpty) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
  final resp = await http.get(Uri.parse('$CHAT_HTTP/api/chat/session/${_sessionId}/active'));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final count = (data['participants'] as num?)?.toInt() ?? 0;
          if (count != _activeParticipants) {
            _activeParticipants = count;
            notifyListeners();
          }
        }
      } catch (_) {
        // ignore polling errors
      }
    });
  }

  void _stopParticipantsPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activeParticipants = 0;
  }
}
