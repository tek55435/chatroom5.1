// screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../providers/chat_session_provider.dart';
import '../models/chat_message.dart';
import '../widgets/app_menu_drawer.dart';
import '../widgets/share_dialog.dart';
import 'help_dialog.dart';
import 'dart:html' as html;

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  
  const ChatScreen({Key? key, this.sessionId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _connectionTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Connect to chat room after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToChat();
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    _connectionTimer?.cancel();
    super.dispose();
  }
  
  // Connect to chat room
  Future<void> _connectToChat() async {
    final provider = Provider.of<ChatSessionProvider>(context, listen: false);
    
    // Try to connect with session ID from widget or URL
    final success = await provider.connectToChatRoom(widget.sessionId);
    
    if (!success) {
      // If connection failed, retry every 5 seconds
      _connectionTimer?.cancel();
      _connectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        provider.connectToChatRoom(widget.sessionId);
      });
    }
  }
  
  // Send message
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final provider = Provider.of<ChatSessionProvider>(context, listen: false);
    provider.sendMessage(text);
    
    _messageController.clear();
    
    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  // Name is set through flows accessed from the Drawer.
  
  // Name dialog and sharing are now accessible via the Drawer.
  
  // Render a single chat message
  Widget _buildMessageItem(ChatMessage message) {
    final provider = Provider.of<ChatSessionProvider>(context, listen: false);
    final isOwnMessage = message.clientId == provider.clientId;
    
    // Format timestamp
    final time = '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}';
    
    if (message.type == 'system') {
      // System message
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        alignment: Alignment.center,
        child: Text(
          message.message,
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
            fontSize: 12.0,
          ),
        ),
      );
    } else {
      // Chat message
      return Align(
        alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: isOwnMessage 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300],
            borderRadius: BorderRadius.circular(16.0),
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOwnMessage && message.sender != null)
                Text(
                  message.sender!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOwnMessage 
                      ? Theme.of(context).colorScheme.onPrimary
                      : Colors.black87,
                  ),
                ),
              Text(
                message.message,
                style: TextStyle(
                  color: isOwnMessage 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.black87,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 10.0,
                    color: isOwnMessage 
                      ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                      : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Consumer<ChatSessionProvider>(
          builder: (context, provider, child) {
            if (provider.isConnecting) {
              return const Text('Connecting...');
            }
            
            return Text(provider.sessionId != null 
              ? 'Chat Room #${provider.sessionId}' 
              : 'Chat Room'
            );
          },
        ),
      ),
      drawer: AppMenuDrawer(
        onInvite: () {
          final base = html.window.location.href.split('?').first;
          final uri = Uri.parse(html.window.location.href);
          final sessionId = uri.queryParameters['sessionId'] ?? 'unknown';
          final url = '$base?sessionId=$sessionId';
          showDialog(context: context, builder: (_) => ShareDialog(sessionId: sessionId, shareUrl: url));
        },
        onHelp: () => showDialog(context: context, builder: (_) => const HelpDialog()),
        onDiagnostics: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open diagnostics from Home'))),
      ),
      body: Consumer<ChatSessionProvider>(
        builder: (context, provider, child) {
          // Show error message if there is one
          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error: ${provider.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _connectToChat,
                    child: const Text('Retry Connection'),
                  ),
                ],
              ),
            );
          }
          
          // Show connecting indicator
          if (provider.isConnecting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16.0),
                  Text('Connecting to chat room...'),
                ],
              ),
            );
          }
          
          // Show chat UI
          return Column(
            children: [
              // Messages list
              Expanded(
                child: provider.messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8.0),
                      itemCount: provider.messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(provider.messages[index]);
                      },
                    ),
              ),
              
              // Input field
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
