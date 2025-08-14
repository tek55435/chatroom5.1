import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

const String SERVER_BASE = String.fromEnvironment('SERVER_BASE', defaultValue: 'http://localhost:3000');

class ChatMessage {
  final String sender;
  final String text;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.text,
    this.isSystem = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HearAll',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3498db),
        scaffoldBackgroundColor: const Color(0xFF1e1e1e),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3498db),
          secondary: const Color(0xFF2ecc71),
          background: const Color(0xFF1e1e1e),
          surface: const Color(0xFF2c3e50),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controllers
  final TextEditingController roomController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController inputController = TextEditingController();
  final ScrollController transcriptController = ScrollController();
  final ScrollController diagnosticController = ScrollController();

  // State variables
  List<ChatMessage> messages = [];
  List<String> participants = [];
  List<String> diagnosticLogs = [];
  bool joined = false;
  bool joining = false;
  bool micOn = false;
  bool showDiagnosticPanel = false;

  @override
  void initState() {
    super.initState();
    _verifyJavaScriptLoaded();
  }

  @override
  void dispose() {
    roomController.dispose();
    nameController.dispose();
    inputController.dispose();
    transcriptController.dispose();
    diagnosticController.dispose();
    super.dispose();
  }

  /// Verify that required JavaScript files are loaded
  void _verifyJavaScriptLoaded() {
    final hasWebRTC = js.context.hasProperty('webrtcJoin');
    
    if (!hasWebRTC) {
      _addDiagnosticLog('[error] Required JavaScript files not loaded: webrtc_helper.js');
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('JavaScript Files Not Loaded'),
            content: const Text(
              'The application cannot connect to the server correctly. This may be because:\n\n'
              '1. The server is not running\n'
              '2. The JavaScript files failed to load\n\n'
              'Please check that the server is running on http://localhost:3000 and refresh the page.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      _addDiagnosticLog('[system] JavaScript helpers verified');
    }
  }

  void _addDiagnosticLog(String message) {
    setState(() {
      diagnosticLogs.add('${DateTime.now().toIso8601String()}: $message');
    });
    // Auto-scroll to bottom
    if (diagnosticController.hasClients) {
      diagnosticController.animateTo(
        diagnosticController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _addTranscriptMessage(String message) {
    setState(() {
      messages.add(ChatMessage(text: message, sender: 'System', isSystem: true));
    });
    // Auto-scroll to bottom
    if (transcriptController.hasClients) {
      transcriptController.animateTo(
        transcriptController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _joinRoom() async {
    final roomId = roomController.text.trim();
    final userName = nameController.text.trim();

    if (roomId.isEmpty || userName.isEmpty) {
      _addTranscriptMessage('[error] Please enter both room ID and your name');
      return;
    }

    try {
      _addDiagnosticLog('[webrtc] Attempting to join room: $roomId as $userName');
      
      // Check if webrtcJoin function exists
      if (!js.context.hasProperty('webrtcJoin')) {
        _addDiagnosticLog('[error] webrtcJoin function not found');
        _addTranscriptMessage('[error] WebRTC helper not loaded');
        return;
      }

      setState(() {
        joining = true;
      });

      // Call webrtcJoin with room ID and user name
      final result = js.context.callMethod('webrtcJoin', [
        roomId,
        userName,
        js.allowInterop((dynamic message) => _handleWebRTCMessage(message))
      ]);

      if (result != null) {
        setState(() {
          joined = true;
          joining = false;
        });

        _addDiagnosticLog('[webrtc] Successfully joined room');
        _addTranscriptMessage('[system] Connected to room: $roomId');
      } else {
        _addDiagnosticLog('[error] webrtcJoin failed');
        setState(() {
          joining = false;
        });
      }

    } catch (e) {
      _addTranscriptMessage('[error] Failed to join room: $e');
      _addDiagnosticLog('[error] Failed to join room: $e');
      setState(() {
        joining = false;
      });
    }
  }

  Future<void> _leaveRoom() async {
    try {
      _addDiagnosticLog('[webrtc] Attempting to leave room');

      // Check if webrtcLeave function exists
      if (!js.context.hasProperty('webrtcLeave')) {
        _addDiagnosticLog('[error] webrtcLeave function not found');
        _addTranscriptMessage('[error] WebRTC helper not loaded. Disconnecting locally.');
        setState(() {
          joined = false;
          joining = false;
          micOn = false;
        });
        return;
      }

      final result = js.context.callMethod('webrtcLeave', []);
      
      _addDiagnosticLog('[webrtc] Leave result: $result');

      setState(() {
        joined = false;
        joining = false;
        micOn = false;
        participants.clear();
      });

    } catch (e) {
      _addDiagnosticLog('[error] Error leaving room: $e');
      _addTranscriptMessage('[error] Error leaving room: $e');
      setState(() {
        joining = false;
      });
    }
  }

  void _handleWebRTCMessage(dynamic message) {
    try {
      final type = message['type'];
      final data = message['data'];
      final user = message['user'] ?? 'Unknown';

      _addDiagnosticLog('[webrtc] Received message type: $type from $user');

      switch (type) {
        case 'chat':
          if (user == nameController.text) {
            _addTranscriptMessage('(You) $data');
          } else {
            _addTranscriptMessage('($user) $data');
          }
          
          final chatMessage = ChatMessage(text: data, sender: user, isSystem: false);
          setState(() {
            messages.add(chatMessage);
          });
          break;

        case 'error':
          _addTranscriptMessage('[error] $data');
          _addDiagnosticLog('[error] $data');
          break;

        default:
          break;
      }
    } catch (e) {
      _addTranscriptMessage('[error] Failed to handle message: $e');
      _addDiagnosticLog('[error] Failed to handle message: $e');
    }
  }

  Future<void> _toggleMic() async {
    if (!joined) return;

    setState(() => micOn = !micOn);

    try {
      if (micOn) {
        if (js.context.hasProperty('webrtcStartMic')) {
          js.context.callMethod('webrtcStartMic', []);
          _addTranscriptMessage('[system] Microphone ON.');
          _addDiagnosticLog('[audio] Microphone started.');
        }
      } else {
        if (js.context.hasProperty('webrtcStopMic')) {
          js.context.callMethod('webrtcStopMic', []);
          _addTranscriptMessage('[system] Microphone OFF.');
          _addDiagnosticLog('[audio] Microphone stopped.');
        }
      }
    } catch (e) {
      _addTranscriptMessage('[error] Mic toggle failed: $e');
      _addDiagnosticLog('[error] Mic toggle failed: $e');
      setState(() => micOn = !micOn); // Revert state on error
    }
  }

  void _sendMessage() {
    if (inputController.text.isNotEmpty && joined) {
      final text = inputController.text;
      
      // Check if sendChat function exists
      if (!js.context.hasProperty('sendChat')) {
        _addTranscriptMessage('[error] sendChat function not found');
        return;
      }

      js.context.callMethod('sendChat', [text]);
      
      setState(() {
        messages.add(ChatMessage(text: text, sender: 'Me', isSystem: false));
      });
      _addTranscriptMessage('(You) $text');
      inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                _buildMainContent(),
              ],
            ),
          ),
          if (showDiagnosticPanel) _buildDiagnosticPanel(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'HearAll',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time chat with WebRTC',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          
          // Participants
          if (joined) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Participants', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.white),
                    title: Text('👤 ${participants[index]}', style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
          ],
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'Join my HearAll room: ${roomController.text}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room link copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Room Link'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      showDiagnosticPanel = !showDiagnosticPanel;
                    });
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Diagnostics'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: Column(
        children: [
          // Join form or chat interface
          if (!joined) ...[
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: roomController,
                        decoration: const InputDecoration(
                          labelText: 'Room ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: joining ? null : _joinRoom,
                          icon: joining ?
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ) :
                            const Icon(Icons.video_call),
                          label: Text(joining ? 'Connecting...' : 'Join Room'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Chat messages
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.background,
                child: ListView.builder(
                  controller: transcriptController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageTile(message);
                  },
                ),
              ),
            ),
            if (joined) _buildInputArea(),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageTile(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isSystem
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: message.isSystem
                      ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              Text(
                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: message.isSystem
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.text,
            style: TextStyle(
              color: message.isSystem
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: inputController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Icon(Icons.send),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _toggleMic,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: Icon(micOn ? Icons.mic : Icons.mic_off),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _leaveRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: micOn ? Colors.red : Colors.grey.shade700,
            ),
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticPanel() {
    return Container(
      height: 200,
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Text('Diagnostic Logs', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => showDiagnosticPanel = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: diagnosticController,
              itemCount: diagnosticLogs.length,
              itemBuilder: (context, index) {
                final log = diagnosticLogs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    log,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
