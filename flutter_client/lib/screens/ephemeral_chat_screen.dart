// screens/ephemeral_chat_screen.dart
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/ephemeral_chat_provider.dart';
import '../models/chat_message.dart';

class EphemeralChatScreen extends StatefulWidget {
  const EphemeralChatScreen({Key? key}) : super(key: key);

  @override
  State<EphemeralChatScreen> createState() => _EphemeralChatScreenState();
}

class _EphemeralChatScreenState extends State<EphemeralChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(text: 'Guest');
  final ScrollController _scrollController = ScrollController();
  bool _showConnectDialog = false;
  
  @override
  void initState() {
    super.initState();
    // Check if we should auto-connect from URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<EphemeralChatProvider>(context, listen: false);
      provider.checkUrlForSession();
      
      // Get query parameters to check if we should auto-connect
      final uri = Uri.parse(html.window.location.href);
      final sessionId = uri.queryParameters['sessionId'];
      final autoConnect = uri.queryParameters['chat'] == 'true';
      
      if (provider.sessionId.isNotEmpty || (sessionId != null && autoConnect)) {
        // We have a session ID from the URL, auto-connect
        provider.connectToSession();
      } else {
        // No session ID, show connect dialog
        setState(() {
          _showConnectDialog = true;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _usernameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      Provider.of<EphemeralChatProvider>(context, listen: false).sendMessage(message);
      _messageController.clear();
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }
  
  void _showShareDialog() {
    final provider = Provider.of<EphemeralChatProvider>(context, listen: false);
    final url = provider.getShareableUrl();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share This Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this link with others to join your chat session:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ephemeral Chat'),
        actions: [
          Consumer<EphemeralChatProvider>(builder: (context, provider, _) {
            if (provider.status == ConnectionStatus.connected) {
              return IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share this chat',
                onPressed: _showShareDialog,
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Consumer<EphemeralChatProvider>(builder: (context, provider, _) {
        // If we need to show connect dialog
        if (_showConnectDialog && provider.status == ConnectionStatus.disconnected) {
          // Show it after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _buildConnectDialog(context),
            );
          });
        }
        
        // Update scroll position when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        
        return Column(
          children: [
            // Session info
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.meeting_room),
                  const SizedBox(width: 8),
                  Text(
                    'Session ID: ${provider.sessionId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  _buildConnectionStatus(provider.status),
                ],
              ),
            ),
            
            // Chat messages
            Expanded(
              child: provider.messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: provider.messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(provider.messages[index]);
                      },
                    ),
            ),
            
            // Input field
            if (provider.status == ConnectionStatus.connected)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
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
      }),
    );
  }
  
  Widget _buildConnectionStatus(ConnectionStatus status) {
    late final Color color;
    late final String text;
    
    switch (status) {
      case ConnectionStatus.disconnected:
        color = Colors.grey;
        text = 'Disconnected';
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        text = 'Connecting...';
        break;
      case ConnectionStatus.connected:
        color = Colors.green;
        text = 'Connected';
        break;
      case ConnectionStatus.error:
        color = Colors.red;
        text = 'Connection Error';
        break;
    }
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
  
  Widget _buildMessageItem(ChatMessage message) {
    final bool isSystem = message.type == 'system';
    final bool isSelf = message.clientId == 'self';
    
    if (isSystem) {
      // System message
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.message,
            style: TextStyle(color: Colors.grey[800], fontSize: 12),
          ),
        ),
      );
    }
    
    // User message
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: isSelf ? Colors.blue[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender name
            if (!isSelf && message.sender != null)
              Text(
                message.sender!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            // Message content
            Text(message.message),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectDialog(BuildContext context) {
    // Create a controller for the session ID field
    final TextEditingController sessionIdController = TextEditingController(
      text: Provider.of<EphemeralChatProvider>(context, listen: false).sessionId
    );
    
    return AlertDialog(
      title: const Text('Join Ephemeral Chat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: sessionIdController,
            decoration: const InputDecoration(
              labelText: 'Session ID (optional)',
              hintText: 'Enter session ID to join',
              prefixIcon: Icon(Icons.meeting_room),
              helperText: 'Leave blank to create a new room',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This chat is ephemeral - all messages will be lost when everyone leaves.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        ElevatedButton(
          child: const Text('Join Chat'),
          onPressed: () {
            final provider = Provider.of<EphemeralChatProvider>(context, listen: false);
            
            // Set the username
            provider.setUsername(_usernameController.text.isNotEmpty 
                ? _usernameController.text 
                : 'Guest');
            
            // Use provided session ID or generate new one
            if (sessionIdController.text.isNotEmpty) {
              provider.setSessionId(sessionIdController.text);
              print('Using provided session ID: ${sessionIdController.text}');
            } else {
              provider.generateNewSession();
              print('Generated new session ID: ${provider.sessionId}');
            }
            
            // Connect to the session
            provider.connectToSession();
            
            // Close dialog and update state
            Navigator.pop(context);
            setState(() => _showConnectDialog = false);
          },
        ),
      ],
    );
  }
}
