// flutter_client/lib/main.dart
import 'dart:async';
import 'dart:convert';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HearAll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF5856D6),
          surface: Color(0xFF2D2D2D),
          background: Color(0xFF1A1A1A),
          error: Color(0xFFFF3B30),
        ),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            height: 1.5,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.5,
            color: Colors.grey,
          ),
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
  bool showDiagnosticPanel = false;
  bool showWelcomeGuide = true;
  bool joined = false;
  bool micOn = false;
  bool isRecording = false;
  String selectedVoice = 'Orion';
  String interactionMode = 'Speaker';
  bool darkMode = true;
  bool singleDeviceAudio = false;
  bool playIncomingAudio = true;
  List<String> transcriptLines = [];
  List<String> diagnosticLogs = [];

  void _showWelcomeGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to HearAll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Getting Started:'),
              SizedBox(height: 8),
              Text('1. Enter a Room ID to join or create a room'),
              Text('2. Enter your display name'),
              Text('3. Click "Join Room" to start'),
              SizedBox(height: 16),
              Text('Key Features:'),
              SizedBox(height: 8),
              Text('• Real-time voice chat'),
              Text('• Text-to-speech messaging'),
              Text('• Live transcript'),
              Text('• Diagnostic tools'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Room Link'),
              subtitle: Text('$SERVER_BASE/room/${roomController.text}'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  final link = '$SERVER_BASE/room/${roomController.text}';
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('QR Code'),
              onTap: () {
                // Show QR code dialog
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: darkMode,
                    onChanged: (value) {
                      setState(() => darkMode = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Single Device Audio'),
                    subtitle: const Text('Only one device can speak at a time'),
                    value: singleDeviceAudio,
                    onChanged: (value) {
                      setState(() => singleDeviceAudio = value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Play Incoming Audio'),
                    value: playIncomingAudio,
                    onChanged: (value) {
                      setState(() => playIncomingAudio = value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Voice'),
                    subtitle: DropdownButton<String>(
                      value: selectedVoice,
                      items: ['Orion', 'Nova', 'Echo'].map((voice) {
                        return DropdownMenuItem(
                          value: voice,
                          child: Text(voice),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedVoice = value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Interaction Mode'),
                    subtitle: DropdownButton<String>(
                      value: interactionMode,
                      items: ['Speaker', 'Listener', 'Both'].map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => interactionMode = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> joinSession() async {
    setState(() {
      joined = true;
      transcriptLines.add('[system] Joined room "${roomController.text}"');
    });
  }

  Future<void> leaveSession() async {
    setState(() {
      joined = false;
      transcriptLines.add('[system] Left room "${roomController.text}"');
    });
  }

  Future<void> startMic() async {
    setState(() {
      micOn = true;
      transcriptLines.add('[system] Started microphone');
    });
  }

  Future<void> stopMic() async {
    setState(() {
      micOn = false;
      transcriptLines.add('[system] Stopped microphone');
    });
  }

  Future<void> playTestSound() async {
    transcriptLines.add('[system] Playing test sound...');
  }

  Future<void> startRecording() async {
    setState(() {
      isRecording = true;
      transcriptLines.add('[system] Started recording');
    });
  }

  Future<void> stopRecording() async {
    setState(() {
      isRecording = false;
      transcriptLines.add('[system] Stopped recording');
    });
  }

  Future<void> sendTypedAsTTS(String text) async {
    if (text.isNotEmpty) {
      transcriptLines.add('(You) $text');
      // Add TTS logic here
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HearAll',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showWelcomeGuide,
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showShareOptions,
            tooltip: 'Share Room',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Room info and controls bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roomController,
                    decoration: InputDecoration(
                      labelText: 'Room ID',
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                if (!joined)
                  ElevatedButton.icon(
                    onPressed: joinSession,
                    icon: const Icon(Icons.login),
                    label: const Text('Join Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: leaveSession,
                        icon: const Icon(Icons.logout),
                        label: const Text('Leave'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(micOn ? Icons.mic : Icons.mic_off),
                        onPressed: micOn ? stopMic : startMic,
                        style: IconButton.styleFrom(
                          backgroundColor: micOn ? const Color(0xFFFF3B30) : const Color(0xFF2D2D2D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: micOn ? 'Stop Microphone' : 'Start Microphone',
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        onPressed: playTestSound,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF2D2D2D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: 'Test Audio',
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main transcript area
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.record_voice_over, color: Color(0xFF007AFF)),
                              const SizedBox(width: 12),
                              const Text(
                                'Live Transcript',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              if (isRecording)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF007AFF),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Recording',
                                        style: TextStyle(
                                          color: Color(0xFF007AFF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Transcript list
                        Expanded(
                          child: ListView.builder(
                            controller: transcriptController,
                            padding: const EdgeInsets.all(16),
                            itemCount: transcriptLines.length,
                            itemBuilder: (context, index) {
                              final line = transcriptLines[index];
                              final isAI = line.startsWith('[AI]');
                              final isEvent = line.startsWith('[event]');
                              final isRaw = line.startsWith('[raw]');
                              final isSystem = !isAI && !line.startsWith('(You)');
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isAI 
                                    ? const Color(0xFF007AFF).withOpacity(0.1)
                                    : const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: isAI ? 16 : 14,
                                    height: 1.5,
                                    color: isAI 
                                      ? const Color(0xFF007AFF)
                                      : isEvent 
                                        ? const Color(0xFFAF52DE)
                                        : isRaw 
                                          ? const Color(0xFFFFCC00)
                                          : isSystem 
                                            ? Colors.grey
                                            : Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Diagnostic panel
                if (showDiagnosticPanel)
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.settings, color: Color(0xFF5856D6)),
                                const SizedBox(width: 12),
                                const Text(
                                  'Controls & Diagnostics',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Audio control buttons
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: startRecording,
                                        icon: const Icon(Icons.mic),
                                        label: const Text('Start Recording'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF34C759),
                                          side: const BorderSide(color: Color(0xFF34C759)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: stopRecording,
                                        icon: const Icon(Icons.stop),
                                        label: const Text('Stop Recording'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFF3B30),
                                          side: const BorderSide(color: Color(0xFFFF3B30)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Diagnostic log area
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A1A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        controller: diagnosticController,
                                        itemCount: diagnosticLogs.length,
                                        itemBuilder: (context, index) {
                                          final log = diagnosticLogs[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Text(
                                              log,
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 12,
                                                height: 1.5,
                                                color: log.contains("[error]")
                                                  ? const Color(0xFFFF3B30)
                                                  : log.contains("[audio]")
                                                    ? const Color(0xFF5856D6)
                                                    : log.contains("[system]")
                                                      ? const Color(0xFF34C759)
                                                      : const Color(0xFFBBBBBB),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Message input
          if (joined) Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: const Color(0xFF2D2D2D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        sendTypedAsTTS(text);
                        inputController.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    if (inputController.text.isNotEmpty) {
                      sendTypedAsTTS(inputController.text);
                      inputController.clear();
                    }
                  },
                  icon: const Icon(Icons.mic),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                  tooltip: 'Send as Speech',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
