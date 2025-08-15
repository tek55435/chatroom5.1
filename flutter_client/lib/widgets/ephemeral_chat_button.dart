// screens/ephemeral_chat_button.dart
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';

class EphemeralChatButton extends StatelessWidget {
  const EphemeralChatButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToChatScreen(context),
      icon: const Icon(Icons.chat_bubble_outline),
      label: const Text('New Chat'),
      tooltip: 'Start ephemeral chat',
    );
  }
  
  void _navigateToChatScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }
}
