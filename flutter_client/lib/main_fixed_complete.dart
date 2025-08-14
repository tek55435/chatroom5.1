// flutter_client/lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  // Initialize and check for shared room link
  _checkForSharedRoomId();
  runApp(const MyApp());
}

// Global variable to store shared room ID from URL
String? sharedRoomId;

void _checkForSharedRoomId() {
  // First check if JavaScript has captured the room ID from the URL
  try {
    final jsSharedRoomId = js.context.hasProperty('sharedRoomId') 
        ? js.context['sharedRoomId'] as String? 
        : null;
        
    if (jsSharedRoomId != null && jsSharedRoomId.isNotEmpty) {
      sharedRoomId = jsSharedRoomId;
      print('Found shared room ID from JavaScript: $sharedRoomId');
      return;
    }
  } catch (e) {
    print('Error accessing JavaScript sharedRoomId: $e');
  }
  
  // Fallback: parse URL parameters directly
  try {
    final uri = Uri.parse(html.window.location.href);
    final params = uri.queryParameters;
    if (params.containsKey('room')) {
      sharedRoomId = params['room'];
      print('Found shared room ID from URL: $sharedRoomId');
    }
  } catch (e) {
    print('Error parsing URL parameters: $e');
  }
}

const String SERVER_BASE = String.fromEnvironment('SERVER_BASE', defaultValue: 'http://localhost:3000');

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Realtime TTS+STT',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  // We won't use these directly but keep as markers
  dynamic pc;
  dynamic dataChannel;

  // WebSocket connection for real-time communication
  html.WebSocket? webSocket;

  // State variables for connection and diagnostics
  bool joined = false;
  bool micOn = false;
  bool isRecording = false;
  bool isTranscribing = false;

  // Text controllers
  final inputController = TextEditingController();
  final transcriptController = ScrollController();
  final List<String> transcriptLines = [];
  final List<String> chatLines = [];

  final roomController = TextEditingController(text: 'main');
  final nameController = TextEditingController(text: 'Guest');
  String selectedVoice = 'alloy';
  final List<String> availableVoices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
  bool personaDialogOpen = false;
  bool isSpeakerMode = false; // Type-to-Speak mode
  bool singleDeviceAudio = false; // For Speaker Mode only
  String? roomId; // Current room ID
  
  // Log entries for the diagnostic panel
  final List<String> diagnosticLogs = [];
  final ScrollController diagnosticController = ScrollController(); 
  bool showDiagnosticPanel = false;
  String connectionStatus = "Disconnected";

  // Audio recording variables for STT
  dynamic mediaRecorder;
  dynamic simpleRecorder; // JS-based fallback recorder
  bool useSimpleRecorder = false;
  dynamic fallbackBlob; // Blob from fallback recorder
  List<dynamic> audioChunks = [];

  // Utility function: pad numbers with leading zeros
  String _padZero(int number) {
    return number < 10 ? '0$number' : number.toString();
  }

  // Add a message to the transcript and scroll to the bottom
  void appendTranscript(String s) {
    final timestamp = DateTime.now();
    setState(() {
      transcriptLines.add(s);
    });
    appendDiagnostic("[$timestamp] $s");
  }
  
  // Add a message to the diagnostic log and scroll to the bottom
  void appendDiagnostic(String s) {
    setState(() => diagnosticLogs.add(s));
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (diagnosticController.hasClients) {
        diagnosticController.jumpTo(diagnosticController.position.maxScrollExtent);
      }
    });
  }

  // Format a timestamp based on whether it's today or another day
  String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (now.year == timestamp.year && now.month == timestamp.month && now.day == timestamp.day) {
      // Same day, just show time
      return '${_padZero(timestamp.hour)}:${_padZero(timestamp.minute)}';
    } else {
      // Different day, show date and time
      return '${_padZero(timestamp.month)}/${_padZero(timestamp.day)} ${_padZero(timestamp.hour)}:${_padZero(timestamp.minute)}';
    }
  }

  // Send a message to edit a previous message
  void editMessage(String messageId, String newText) {
    if (webSocket == null) return;
    
    final editMessage = {
      'type': 'edit_message',
      'messageId': messageId,
      'newText': newText,
    };
    
    try {
      webSocket!.send(json.encode(editMessage));
    } catch (e) {
      appendDiagnostic("[error] Failed to edit message: $e");
    }
  }
  
  // Send a message to delete a previous message
  void deleteMessage(String messageId) {
    if (webSocket == null) return;
    
    final deleteMessage = {
      'type': 'delete_message',
      'messageId': messageId,
    };
    
    try {
      webSocket!.send(json.encode(deleteMessage));
    } catch (e) {
      appendDiagnostic("[error] Failed to delete message: $e");
    }
  }
  
  // Copy diagnostic logs to clipboard
  void copyDiagnosticLogs() {
    final text = diagnosticLogs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    appendDiagnostic("[system] Copied diagnostic logs to clipboard");
  }
  
  // Clear diagnostic logs
  void clearDiagnosticLogs() {
    setState(() {
      diagnosticLogs.clear();
    });
  }
  
  // Toggle diagnostic panel
  void toggleDiagnosticPanel() {
    setState(() {
      showDiagnosticPanel = !showDiagnosticPanel;
    });
    appendDiagnostic("[System] Diagnostic panel ${showDiagnosticPanel ? 'opened' : 'closed'}");
  }

  // Test audio initialization
  void testAudioInitialization() {
    appendTranscript('[testing] Testing audio initialization...');
    
    js.context.callMethod('eval', ['''
      function testAudioInit() {
        try {
          const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
          if (audioCtx) {
            if (window.dartAppendTranscript) {
              window.dartAppendTranscript("[audio] Audio context created successfully");
            }
            
            // Try to create an oscillator as a more thorough test
            const oscillator = audioCtx.createOscillator();
            oscillator.type = 'sine';
            oscillator.frequency.setValueAtTime(440, audioCtx.currentTime); // A4 note
            oscillator.connect(audioCtx.destination);
            oscillator.start();
            setTimeout(() => oscillator.stop(), 200); // Brief test tone
            
            if (window.dartAppendTranscript) {
              window.dartAppendTranscript("[audio] Audio playback test successful");
            }
            
            return true;
          }
        } catch (err) {
          if (window.dartAppendTranscript) {
            window.dartAppendTranscript("[error] Audio initialization failed: " + err.message);
          }
          return false;
        }
        return false;
      }
      testAudioInit();
    ''']);
  }
  
  // Test WebRTC connection
  void testWebRTCConnection() {
    appendTranscript('[testing] Testing WebRTC connection...');
    
    js.context.callMethod('eval', ['''
      function testWebRTC() {
        try {
          // Check for RTCPeerConnection
          if (window.RTCPeerConnection || window.webkitRTCPeerConnection || window.mozRTCPeerConnection) {
            const RTCPeerConnection = window.RTCPeerConnection || window.webkitRTCPeerConnection || window.mozRTCPeerConnection;
            
            // Create a simple loopback connection
            const pc1 = new RTCPeerConnection();
            const pc2 = new RTCPeerConnection();
            
            pc1.onicecandidate = e => e.candidate && pc2.addIceCandidate(e.candidate);
            pc2.onicecandidate = e => e.candidate && pc1.addIceCandidate(e.candidate);
            
            pc2.onconnectionstatechange = () => {
              if (window.dartAppendTranscript) {
                window.dartAppendTranscript("[webrtc] Connection state: " + pc2.connectionState);
              }
            };
            
            // Create data channel as a simple test
            const dc = pc1.createDataChannel("test");
            
            pc2.ondatachannel = e => {
              const receiveChannel = e.channel;
              receiveChannel.onmessage = msg => {
                if (window.dartAppendTranscript) {
                  window.dartAppendTranscript("[webrtc] Message received: " + msg.data);
                  window.dartAppendTranscript("[webrtc] WebRTC test completed successfully");
                }
              };
              
              // Send a test message after connection
              setTimeout(() => {
                try {
                  dc.send("WebRTC Test Message");
                } catch(err) {
                  if (window.dartAppendTranscript) {
                    window.dartAppendTranscript("[error] Failed to send message: " + err.message);
                  }
                }
              }, 1000);
            };
            
            // Start connection process
            pc1.createOffer()
              .then(offer => pc1.setLocalDescription(offer))
              .then(() => pc2.setRemoteDescription(pc1.localDescription))
              .then(() => pc2.createAnswer())
              .then(answer => pc2.setLocalDescription(answer))
              .then(() => pc1.setRemoteDescription(pc2.localDescription))
              .catch(err => {
                if (window.dartAppendTranscript) {
                  window.dartAppendTranscript("[error] WebRTC setup error: " + err.message);
                }
              });
              
            return true;
          } else {
            if (window.dartAppendTranscript) {
              window.dartAppendTranscript("[error] WebRTC not supported in this browser");
            }
            return false;
          }
        } catch (err) {
          if (window.dartAppendTranscript) {
            window.dartAppendTranscript("[error] WebRTC test error: " + err.message);
          }
          return false;
        }
      }
      testWebRTC();
    ''']);
  }
  
  // Test TTS system
  void testTTSSystem() {
    appendTranscript('[testing] Testing Text-to-Speech system...');
    
    final testText = "This is a test of the text to speech system.";
    appendTranscript('[tts] Testing with: "$testText"');
    
    // First test direct API call
    useDirectTTS(testText);
  }
  
  // Use direct TTS API call
  Future<void> useDirectTTS(String text) async {
    try {
      appendTranscript('[tts] Testing direct HTTP API...');
      
      final response = await http.post(
        Uri.parse('$SERVER_BASE/api/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'voice': selectedVoice
        })
      );
      
      if (response.statusCode == 200) {
        appendTranscript('[tts] HTTP API test successful');
        
        // Play the audio
        final blob = html.Blob([response.bodyBytes], 'audio/mpeg');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final audio = html.AudioElement()
          ..src = url
          ..autoplay = true;
        
        // Clean up URL after playing
        audio.onEnded.listen((_) {
          html.Url.revokeObjectUrl(url);
          appendTranscript('[tts] Audio playback completed');
        });
      } else {
        appendTranscript('[error] HTTP API test failed with status: ${response.statusCode}');
        appendTranscript('[error] Response: ${response.body}');
      }
    } catch (e) {
      appendTranscript('[error] HTTP API test exception: $e');
    }
  }

  // Connect to WebSocket for real-time communication
  void connectToWebSocket() {
    final wsUrl = 'ws://${SERVER_BASE.replaceFirst('http://', '')}';
    appendTranscript('[system] Connecting to WebSocket at $wsUrl');
    
    try {
      webSocket = html.WebSocket('$wsUrl/ws');
      
      webSocket!.onOpen.listen((_) {
        appendTranscript('[system] WebSocket connected');
        setState(() => connectionStatus = "Connected");
      });
      
      webSocket!.onMessage.listen((event) {
        try {
          final data = json.decode(event.data as String);
          
          // Handle different message types
          switch (data['type']) {
            case 'room_joined':
              setState(() {
                joined = true;
              });
              appendTranscript('[system] Joined room ${data['roomId']} as ${nameController.text}');
              break;
              
            case 'voice_changed':
              selectedVoice = data['voice'];
              appendTranscript('[system] Voice changed to $selectedVoice (to avoid conflicts)');
              break;
              
            case 'user_joined':
              appendTranscript('[system] ${data['name']} joined the room');
              break;
              
            case 'user_left':
              appendTranscript('[system] A user left the room');
              break;
              
            case 'new_message':
              final msg = data['message'];
              final senderName = msg['name'];
              final text = msg['text'];
              final type = msg['type'];
              appendTranscript('[$senderName] $text ${type == "speech" ? "🎤" : ""}');
              break;
              
            case 'audio_message':
              final senderName = data['name'];
              appendTranscript('[TTS] Playing audio from $senderName');
              playAudioMessage(data['audio'], data['name']);
              break;
              
            case 'interim_transcript':
              updateInterimTranscript(data['name'], data['text']);
              break;
              
            case 'message_edited':
              appendTranscript('[system] A message was edited');
              break;
              
            case 'message_deleted':
              appendTranscript('[system] A message was deleted');
              break;
              
            default:
              appendDiagnostic('[websocket] Unknown message type: ${data['type']}');
          }
        } catch (e) {
          appendDiagnostic('[error] Failed to parse WebSocket message: $e');
        }
      });
      
      webSocket!.onClose.listen((_) {
        appendTranscript('[system] WebSocket disconnected');
        setState(() {
          joined = false;
          connectionStatus = "Disconnected";
        });
        
        // Try to reconnect
        Timer(const Duration(seconds: 3), () {
          if (!joined) {
            appendTranscript('[system] Attempting to reconnect...');
            connectToWebSocket();
          }
        });
      });
      
      webSocket!.onError.listen((event) {
        appendTranscript('[error] WebSocket error');
        appendDiagnostic('[error] WebSocket error: $event');
      });
    } catch (e) {
      appendTranscript('[error] Failed to connect to WebSocket: $e');
    }
  }

  // Join a session using the current room ID and user persona
  Future<void> joinSession() async {
    if (joined) return;
    
    final roomIdToUse = roomController.text.trim();
    
    if (roomIdToUse.isEmpty) {
      appendTranscript('[error] Room ID cannot be empty');
      return;
    }
    
    if (nameController.text.trim().isEmpty) {
      appendTranscript('[error] Name cannot be empty');
      return;
    }
    
    // Store the room ID
    roomId = roomIdToUse;
    
    // Connect to WebSocket for real-time communication
    connectToWebSocket();
    
    // Wait a bit for the WebSocket to connect
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if WebSocket is connected
    if (webSocket == null) {
      appendTranscript('[error] WebSocket connection failed');
      return;
    }
    
    // Prepare join message
    final joinMsg = {
      'type': 'join_room',
      'roomId': roomIdToUse,
      'name': nameController.text.trim(),
      'voice': selectedVoice,
      'isSpeakerMode': isSpeakerMode,
      'singleDeviceAudio': singleDeviceAudio,
    };
    
    // Send join message
    try {
      webSocket!.send(json.encode(joinMsg));
      appendTranscript('[system] Join request sent, waiting for server response...');
    } catch (e) {
      appendTranscript('[error] Failed to send join request: $e');
    }
  }
  
  // Leave the current session
  void leaveSession() {
    if (!joined || webSocket == null) return;
    
    final leaveMsg = {
      'type': 'leave_room',
    };
    
    try {
      webSocket!.send(json.encode(leaveMsg));
      setState(() {
        joined = false;
        roomId = null;
      });
      appendTranscript('[system] Left the room');
    } catch (e) {
      appendTranscript('[error] Failed to leave room: $e');
    }
  }

  // Update the interim transcript in the UI
  void updateInterimTranscript(String name, String text) {
    // This would update an UI element showing real-time transcription
    appendDiagnostic("[interim] $name: $text");
  }
  
  // Play an audio message from base64 encoded data
  void playAudioMessage(String base64Audio, String senderName) {
    try {
      final bytes = base64Decode(base64Audio);
      final blob = html.Blob([bytes], 'audio/mpeg');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final audio = html.AudioElement()
        ..src = url
        ..autoplay = true;
      
      // Clean up URL after playing
      audio.onEnded.listen((_) {
        html.Url.revokeObjectUrl(url);
        appendDiagnostic("[audio] Finished playing message from $senderName");
      });
    } catch (e) {
      appendDiagnostic("[error] Failed to play audio: $e");
    }
  }
  
  // Share session link for the current room
  void shareSession() {
    if (roomId == null) {
      roomId = roomController.text.trim();
    }
    
    // Use our JavaScript helper to generate a shareable link if available
    String shareUrl;
    if (js.context.hasProperty('generateShareableLink')) {
      shareUrl = js.context.callMethod('generateShareableLink', [roomId]) as String;
    } else {
      // Fallback to manually constructing URL
      shareUrl = '$SERVER_BASE/?room=$roomId';
    }
    
    final shareText = 'Join my voice chat room: $shareUrl';
    
    appendTranscript('[system] Sharing session: $roomId');
    
    // Try to use Web Share API if available
    try {
      final navigator = js.context['navigator'];
      if (js_util.hasProperty(navigator, 'share')) {
        final shareData = js_util.jsify({
          'title': 'Join my voice chat room',
          'text': 'Join my conversation!',
          'url': shareUrl
        });
        
        js_util.promiseToFuture<bool>(
          js_util.callMethod(navigator, 'share', [shareData])
        ).then((_) {
          appendTranscript('[system] Shared successfully via Web Share API');
        }).catchError((error) {
          appendDiagnostic('[error] Share failed: $error');
          _fallbackShare(shareText);
        });
      } else {
        _fallbackShare(shareText);
      }
    } catch (e) {
      appendDiagnostic('[error] Share error: $e');
      _fallbackShare(shareText);
    }
  }
  
  // Fallback share method using clipboard
  void _fallbackShare(String shareText) {
    Clipboard.setData(ClipboardData(text: shareText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share link copied to clipboard'))
      );
    });
  }
  
  // Send a chat message
  void sendMessage() {
    if (!joined) return;
    
    // Stop recording if active
    if (isRecording) {
      stopRecording();
    }
    
    final text = inputController.text.trim();
    if (text.isEmpty) return;
    
    final messageObj = {
      'type': 'chat_message',
      'text': text,
    };
    
    try {
      webSocket!.send(json.encode(messageObj));
      inputController.clear();
    } catch (e) {
      appendTranscript('[error] Failed to send message: $e');
    }
  }
  
  // Start microphone recording for speech-to-text
  Future<void> startMic() async {
    if (!joined || isSpeakerMode) return; // Only for conversation mode
    
    appendDiagnostic("[mic] Starting microphone recording");
    
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true
      });
      
      if (stream != null) {
        // Create media recorder
        mediaRecorder = js.context.callMethod('eval', ['''
          (() => {
            const recorder = new MediaRecorder(arguments[0], {
              mimeType: 'audio/webm'
            });
            
            recorder.ondataavailable = (event) => {
              if (event.data.size > 0 && window.dartHandleAudioChunk) {
                window.dartHandleAudioChunk(event.data);
              }
            };
            
            return recorder;
          })()
        ''', stream]);
        
        // Set up chunk handler
        js.context['dartHandleAudioChunk'] = (dynamic chunk) {
          audioChunks.add(chunk);
          _processAudioChunkForInterimTranscription(chunk);
        };
        
        // Start recording
        js.context.callMethod('eval', ['''
          arguments[0].start(1000); // 1 second chunks
        ''', mediaRecorder]);
        
        setState(() { isRecording = true; });
        setState(() { micOn = true; });
      } else {
        appendTranscript('[error] Could not access microphone');
      }
    } catch (e) {
      appendTranscript('[error] Microphone error: $e');
    }
  }
  
  // Stop microphone recording
  Future<void> stopMic() async {
    if (!micOn) return;
    
    appendDiagnostic("[mic] Stopping microphone recording");
    
    setState(() { micOn = false; });
    
    try {
      if (mediaRecorder != null) {
        await stopRecording();
      }
    } catch (e) {
      appendTranscript('[error] Error stopping microphone: $e');
    }
  }
  
  // Process an audio chunk for interim transcription
  Future<void> _processAudioChunkForInterimTranscription(dynamic chunk) async {
    // For simplicity, we'll only do final transcription when recording stops
    // Real interim transcription would need WebSocket streaming
    appendDiagnostic("[audio] Received audio chunk: ${audioChunks.length}");
  }
  
  // Process the complete recording for final transcription
  Future<void> _processRecordingForFinalTranscription() async {
    if (audioChunks.isEmpty) return;
    
    appendDiagnostic("[stt] Processing ${audioChunks.length} audio chunks for transcription");
    
    try {
      setState(() { isTranscribing = true; });
      
      // Create a blob from all chunks
      final blob = js.context.callMethod('eval', ['''
        new Blob(arguments[0], { type: 'audio/webm' })
      ''', js.JsArray.from(audioChunks)]);
      
      // Create form data
      final formData = js.context.callMethod('eval', ['''
        (() => {
          const form = new FormData();
          form.append('file', arguments[0], 'recording.webm');
          form.append('language', 'en');
          return form;
        })()
      ''', blob]);
      
      // Upload to STT API
      final xhr = js.context.callMethod('eval', ['''
        (() => {
          const xhr = new XMLHttpRequest();
          xhr.open('POST', '${SERVER_BASE}/api/stt', true);
          xhr.send(arguments[0]);
          return xhr;
        })()
      ''', formData]);
      
      // Wait for response
      await js.context.callMethod('eval', ['''
        new Promise((resolve, reject) => {
          arguments[0].onload = () => {
            if (arguments[0].status === 200) {
              const response = JSON.parse(arguments[0].responseText);
              if (response.text) {
                window.dartHandleTranscription(response.text, true);
              }
              resolve(true);
            } else {
              reject('HTTP error: ' + arguments[0].status);
            }
          };
          arguments[0].onerror = () => reject('Network error');
        })
      ''', xhr]);
      
      _cleanupRecording();
      
    } catch (e) {
      appendTranscript('[error] Transcription failed: $e');
      setState(() {
        isTranscribing = false;
        isRecording = false;
      });
    }
  }
  
  // Stop recording and process for transcription
  Future<void> stopRecording() async {
    if (!isRecording) return;
    
    appendDiagnostic("[mic] Stopping recording");
    
    try {
      // Stop the media recorder
      await js.context.callMethod('eval', ['''
        new Promise((resolve) => {
          arguments[0].onstop = () => resolve(true);
          arguments[0].stop();
        })
      ''', mediaRecorder]);
      
      setState(() { isRecording = false; });
      
      // Process the recording
      await _processRecordingForFinalTranscription();
    } catch (e) {
      appendTranscript('[error] Error stopping recording: $e');
      setState(() {
        isTranscribing = false;
        isRecording = false;
      });
    }
  }
  
  // Clean up recording resources
  void _cleanupRecording() {
    audioChunks.clear();
    mediaRecorder = null;
    setState(() {
      isTranscribing = false;
      isRecording = false;
    });
  }

  // Persona dialog
  Future<void> showPersonaDialog() async {
    personaDialogOpen = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Your Persona'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Display Name'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Communication Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ListTile(
                      title: const Text('Speaker Mode (Type-to-Speak)'),
                      subtitle: const Text('For users who cannot speak aloud'),
                      leading: Radio<bool>(
                        value: true,
                        groupValue: isSpeakerMode,
                        onChanged: (value) {
                          setDialogState(() => isSpeakerMode = value!);
                          setState(() => isSpeakerMode = value!);
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Conversation Mode (Speak-to-Type)'),
                      subtitle: const Text('For users who can speak verbally'),
                      leading: Radio<bool>(
                        value: false,
                        groupValue: isSpeakerMode,
                        onChanged: (value) {
                          setDialogState(() => isSpeakerMode = value!);
                          setState(() => isSpeakerMode = value!);
                        },
                      ),
                    ),
                    if (isSpeakerMode) ...[
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Play my voice on my device'),
                        value: singleDeviceAudio,
                        onChanged: (v) {
                          setDialogState(() => singleDeviceAudio = v);
                          setState(() => singleDeviceAudio = v);
                        },
                      ),
                    ],
                    const Divider(),
                    const Text('Voice:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String>(
                      value: selectedVoice,
                      items: availableVoices.map((voice) => DropdownMenuItem(
                        value: voice,
                        child: Text(voice[0].toUpperCase() + voice.substring(1)),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedVoice = v);
                          setState(() => selectedVoice = v);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Voice'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    personaDialogOpen = false;
                    Navigator.of(context).pop();
                    // If we have a sharedRoomId, auto-join after persona setup
                    if (sharedRoomId != null && !joined) {
                      joinSession();
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          }
        );
      },
    );
    personaDialogOpen = false;
  }

  @override
  void initState() {
    super.initState();
    
    // If we have a shared room ID, show persona dialog immediately
    if (sharedRoomId != null) {
      roomController.text = sharedRoomId!;
      Future.delayed(const Duration(milliseconds: 300), () {
        showPersonaDialog();
      });
    }
    
    // Set up JavaScript functions to call back into Flutter
    js.context['dartAppendTranscript'] = (String text) {
      appendTranscript(text);
    };
    
    // Set up WebRTC connection
    js.context.callMethod('eval', ['''
      if (window.webrtcInit) {
        window.webrtcInit();
        if (window.dartAppendTranscript) {
          window.dartAppendTranscript('[system] Connection fully established and ready to use');
        }
      }
    ''']);
    
    // Set up audio context
    js.context.callMethod('eval', ['''
      try {
        if (!window.audioContext) {
          window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
          if (window.dartAppendTranscript) {
            window.dartAppendTranscript("[audio] Audio system explicitly initialized");
          }
        }
      } catch(err) {
        if (window.dartAppendTranscript) {
          window.dartAppendTranscript("[error] Failed to initialize audio: " + err.message);
        }
      }
      
      // Resume audio context if needed (for Safari)
      if (window.audioContext && window.audioContext.state === 'suspended') {
        window.audioContext.resume().then(() => {
          if (window.dartAppendTranscript) {
            window.dartAppendTranscript("[audio] Audio system resumed");
          }
        });
      }
    ''']);
    
    // Set up transcription handler
    js.context['dartHandleTranscription'] = (String text, bool isFinal) {
      appendDiagnostic("[transcript] ${isFinal ? 'Final' : 'Interim'}: $text");
      
      if (isFinal && text.trim().isNotEmpty) {
        // Send to server
        if (webSocket != null) {
          final transcriptMsg = {
            'type': 'speech_transcript',
            'text': text,
            'final': true,
          };
          
          webSocket!.send(json.encode(transcriptMsg));
        }
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Voice Chat Room'),
            const SizedBox(width: 10),
            if (connectionStatus != "Connected")
              const Icon(Icons.warning, color: Colors.red),
            if (connectionStatus == "Connected") 
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
        actions: [
          if (!joined && sharedRoomId == null)
            TextButton.icon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Join', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (!personaDialogOpen) {
                  await showPersonaDialog();
                }
                joinSession();
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Leave', style: TextStyle(color: Colors.white)),
              onPressed: leaveSession,
            ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(micOn ? Icons.mic : Icons.mic_off),
            onPressed: joined ? (micOn ? stopMic : startMic) : null,
            color: micOn ? Colors.redAccent : Colors.white,
            tooltip: 'Toggle Microphone',
          ),
          IconButton(
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: toggleDiagnosticPanel,
            tooltip: 'Diagnostics',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: shareSession,
            tooltip: 'Share Room',
          ),
        ],
      ),
      body: Column(
        children: [
          // Room ID and Persona Configuration Panel
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room ID',
                      hintText: 'Enter a room ID',
                    ),
                    enabled: !joined,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: joined ? null : () {
                    if (!personaDialogOpen) {
                      showPersonaDialog();
                    }
                  },
                  child: const Text('Persona'),
                ),
              ],
            ),
          ),
          
          // Main Content Area: Transcript + Diagnostic
          Expanded(
            child: Row(
              children: [
                // Transcript Area
                Expanded(
                  flex: showDiagnosticPanel ? 3 : 5,
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              const Text('Transcript', style: TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() {
                                    transcriptLines.clear();
                                  });
                                },
                                iconSize: 20,
                                tooltip: 'Clear Transcript',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: transcriptController,
                            itemCount: transcriptLines.length,
                            itemBuilder: (context, index) {
                              final line = transcriptLines[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                                child: Text(line),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Diagnostic Panel (conditionally visible)
                if (showDiagnosticPanel)
                  Expanded(
                    flex: 2,
                    child: Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                const Text('Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: copyDiagnosticLogs,
                                  iconSize: 20,
                                  tooltip: 'Copy Logs',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: clearDiagnosticLogs,
                                  iconSize: 20,
                                  tooltip: 'Clear Logs',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: toggleDiagnosticPanel,
                                  iconSize: 20,
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                          ),
                          
                          // Diagnostic Controls
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Wrap(
                              spacing: 8.0,
                              children: [
                                ElevatedButton(
                                  onPressed: testAudioInitialization,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  ),
                                  child: const Text('Test Audio', style: TextStyle(fontSize: 12)),
                                ),
                                ElevatedButton(
                                  onPressed: testWebRTCConnection,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  ),
                                  child: const Text('Test WebRTC', style: TextStyle(fontSize: 12)),
                                ),
                                ElevatedButton(
                                  onPressed: testTTSSystem,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 4.0),
                                  ),
                                  child: const Text('Test TTS', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          
                          // Diagnostic Log
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(8.0),
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: ListView.builder(
                                controller: diagnosticController,
                                itemCount: diagnosticLogs.length,
                                itemBuilder: (context, index) {
                                  final log = diagnosticLogs[index];
                                  Color textColor = Colors.white;
                                  
                                  // Color-code log lines
                                  if (log.contains('[error]')) {
                                    textColor = Colors.red.shade300;
                                  } else if (log.contains('[system]')) {
                                    textColor = Colors.green.shade300;
                                  } else if (log.contains('[audio]')) {
                                    textColor = Colors.blue.shade300;
                                  } else if (log.contains('[webrtc]')) {
                                    textColor = Colors.purple.shade300;
                                  } else if (log.contains('[tts]')) {
                                    textColor = Colors.orange.shade300;
                                  }
                                  
                                  return Text(
                                    log,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: textColor,
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
          
          // Input Area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      hintText: joined
                          ? (isSpeakerMode
                              ? 'Type your message to speak...'
                              : 'Type a message or use microphone...')
                          : 'Join a room to chat',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: joined ? sendMessage : null,
                      ),
                    ),
                    onSubmitted: joined ? (_) => sendMessage() : null,
                    enabled: joined,
                  ),
                ),
                if (!isSpeakerMode && joined)
                  IconButton(
                    icon: Icon(
                      isRecording ? Icons.stop_circle : Icons.mic,
                      color: isRecording ? Colors.red : null,
                    ),
                    onPressed: isRecording ? stopRecording : startMic,
                    tooltip: isRecording ? 'Stop Recording' : 'Start Recording',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
