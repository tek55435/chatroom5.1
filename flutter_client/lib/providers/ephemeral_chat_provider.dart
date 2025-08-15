// providers/ephemeral_chat_provider.dart
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/chat_message.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class EphemeralChatProvider extends ChangeNotifier {
  String _sessionId = '';
  String _username = 'Guest';
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<ChatMessage> _messages = [];
  
  String get sessionId => _sessionId;
  String get username => _username;
  ConnectionStatus get status => _status;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  
  // Set up listeners for chat events
  EphemeralChatProvider() {
    // Set up callback for receiving messages
    js.context['dartChatMessageReceived'] = js.allowInterop((dynamic messageData) {
      print('Message received in Dart: $messageData');
      try {
        final Map<String, dynamic> data = jsonDecode(messageData.toString());
        final message = ChatMessage.fromJson(data);
        _messages.add(message);
        notifyListeners();
      } catch (e) {
        print('Error parsing message: $e');
        // Add error message to chat
        _messages.add(ChatMessage(
          type: 'system',
          message: 'Error processing message',
          timestamp: DateTime.now(),
        ));
        notifyListeners();
      }
    });
    
    // Set up callback for connection status
    js.context['dartChatConnectionChanged'] = js.allowInterop((bool isConnected, String? errorMessage) {
      print('Connection status changed: $isConnected, error: $errorMessage');
      _status = isConnected ? ConnectionStatus.connected : ConnectionStatus.disconnected;
      
      if (errorMessage != null) {
        _status = ConnectionStatus.error;
        _messages.add(ChatMessage(
          type: 'system',
          message: 'Connection error: $errorMessage',
          timestamp: DateTime.now(),
        ));
      }
      
      notifyListeners();
    });
  }
  
  // Set username
  void setUsername(String name) {
    _username = name;
    notifyListeners();
  }
  
  // Set session ID directly
  void setSessionId(String id) {
    _sessionId = id;
    notifyListeners();
  }
  
  // Check URL for session ID
  void checkUrlForSession() {
    // Use JavaScript integration to check URL
    final sessionId = js.context.callMethod('eval', 
      ['window.EphemeralChat.getSessionIdFromUrl()']);
    
    if (sessionId != null && sessionId.toString().isNotEmpty) {
      _sessionId = sessionId.toString();
      notifyListeners();
    }
  }
  
  // Generate new session ID
  void generateNewSession() {
    final sessionId = js.context.callMethod('eval', 
      ['window.EphemeralChat.generateSessionId()']);
    
    if (sessionId != null && sessionId.toString().isNotEmpty) {
      _sessionId = sessionId.toString();
      notifyListeners();
    }
  }
  
  // Connect to chat session
  Future<void> connectToSession() async {
    if (_sessionId.isEmpty) {
      generateNewSession();
    }
    
    // Update status
    _status = ConnectionStatus.connecting;
    notifyListeners();
    
    // Clear previous messages
    _messages.clear();
    
    // Add system message
    _messages.add(ChatMessage(
      type: 'system',
      message: 'Connecting to session $_sessionId...',
      timestamp: DateTime.now(),
    ));
    
    // Use JavaScript integration to connect
    try {
      print('Attempting to connect to session: $_sessionId');
      js.context.callMethod('eval', ["""
        console.log('Connecting to chat from Dart with session ID: $_sessionId');
        window.EphemeralChat.connect(
          '$_sessionId',
          function(sessionId) {
            // On connect
            console.log('Connected to chat from callback');
            window.dartChatConnectionChanged(true, null);
          },
          function(data) {
            // On message received
            console.log('Received message in callback', data);
            window.dartChatMessageReceived(JSON.stringify(data));
          },
          function() {
            // On close
            console.log('Connection closed from callback');
            window.dartChatConnectionChanged(false, null);
          },
          function(error) {
            // On error
            console.error('Connection error from callback:', error);
            window.dartChatConnectionChanged(false, error.toString());
          }
        );
      """]);
    } catch (e) {
      print('Error connecting to chat: $e');
      _status = ConnectionStatus.error;
      _messages.add(ChatMessage(
        type: 'system',
        message: 'Error connecting: $e',
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    }
  }
  
  // Send a message
  void sendMessage(String content) {
    if (content.trim().isEmpty) return;
    
    final result = js.context.callMethod('eval', 
      ['window.EphemeralChat.sendMessage("${content.replaceAll('"', '\\"')}", "$_username")']);
    
    if (result == true) {
      // Message sent successfully - will come back through the websocket
      // but we can add a local copy now for immediate feedback
      _messages.add(ChatMessage(
        type: 'chat',
        clientId: 'self',  // Mark as sent by self
        sender: _username,
        message: content,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    } else {
      // Message failed to send
      _messages.add(ChatMessage(
        type: 'system',
        message: 'Failed to send message',
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    }
  }
  
  // Disconnect from the session
  void disconnect() {
    js.context.callMethod('eval', ['window.EphemeralChat.disconnect()']);
    _status = ConnectionStatus.disconnected;
    
    _messages.add(ChatMessage(
      type: 'system',
      message: 'Disconnected from session',
      timestamp: DateTime.now(),
    ));
    
    notifyListeners();
  }
  
  // Get shareable URL for current session
  String getShareableUrl() {
    final location = html.window.location;
    final baseUrl = '${location.protocol}//${location.host}${location.pathname}';
    return '$baseUrl?sessionId=$_sessionId&chat=true';
  }
}
