// flutter_client/lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
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
  
  final transcriptController = ScrollController();
  final List<String> transcriptLines = [];
  final List<String> chatLines = [];

  final roomController = TextEditingController(text: 'main');
  final nameController = TextEditingController(text: 'Guest');
  final inputController = TextEditingController();

  bool joined = false;
  bool micOn = false;

  @override
  void initState() {
    super.initState();
    
    // Set up JavaScript functions to call back into Flutter
    js.context['dartAppendTranscript'] = (String text) {
      appendTranscript(text);
    };
    
    // Make the server base URL available to JavaScript
    js.context['SERVER_BASE'] = SERVER_BASE;
    
    // Add a script to the page that will hold our WebRTC code
    final scriptEl = html.ScriptElement();
    scriptEl.text = r'''
      // Global WebRTC objects
      let peerConnection = null;
      let dataChannel = null;
      let localStream = null;
      
      // Function to append to transcript (will be called from JS)
      function appendToTranscript(text) {
        if (window.dartAppendTranscript) {
          window.dartAppendTranscript(text);
        } else {
          console.log("Transcript: " + text);
        }
      }
      
      // Initialize WebRTC
      async function initWebRTC() {
        try {
          peerConnection = new RTCPeerConnection({
            iceServers: []
          });
          
          // Set up ontrack handler
          peerConnection.ontrack = (event) => {
            console.log("Got remote track", event);
            if (event.streams && event.streams.length > 0) {
              const audioEl = document.createElement('audio');
              audioEl.autoplay = true;
              audioEl.controls = false;
              audioEl.srcObject = event.streams[0];
              document.body.appendChild(audioEl);
              appendToTranscript("Remote audio connected");
            }
          };
          
          // Create data channel
          dataChannel = peerConnection.createDataChannel('oai-events');
          dataChannel.onopen = () => {
            appendToTranscript("Data channel open");
            
            // Send session config - using the proper format for max_response_output_tokens
            const sessionConfig = {
              type: 'session.update',
              session: {
                voice: 'alloy',
                temperature: 0.8,
                input_audio_format: 'pcm16',
                output_audio_format: 'pcm16',
                max_response_output_tokens: 'inf',  // Use string 'inf' as required by API
                speed: 1.0
              }
            };
            dataChannel.send(JSON.stringify(sessionConfig));
            appendToTranscript("Session config sent");
          };
          
          dataChannel.onmessage = (event) => {
            try {
              const data = JSON.parse(event.data);
              const type = data.type || '';
              if (type.startsWith('transcript')) {
                const text = data.text || data.delta || data.content || '';
                appendToTranscript("[AI] " + text);
              } else if (type === 'session.created' || type === 'session.updated') {
                // Just log these system events without showing full JSON
                appendToTranscript("[system] Session " + (type === 'session.created' ? 'created' : 'updated'));
              } else if (type === 'error') {
                // Show errors prominently
                appendToTranscript("[error] " + (data.message || JSON.stringify(data)));
              } else {
                // Other events
                appendToTranscript("[event] " + JSON.stringify(data));
              }
            } catch (e) {
              appendToTranscript("[raw] " + event.data);
            }
          };
          
          appendToTranscript("WebRTC initialized");
          return true;
        } catch (err) {
          appendToTranscript("Error initializing WebRTC: " + err.message);
          console.error("WebRTC init error:", err);
          return false;
        }
      }
      
      // Join session
      async function joinRTCSession() {
        try {
          if (!peerConnection) {
            const initialized = await initWebRTC();
            if (!initialized) return false;
          }
          
          // Create offer
          const offer = await peerConnection.createOffer({
            offerToReceiveAudio: true
          });
          await peerConnection.setLocalDescription(offer);
          
          // Wait for ICE gathering
          appendToTranscript("Creating offer...");
          
          // Send offer to server - use the SERVER_BASE from Dart
          // Make sure we're using the absolute URL to the server
          const serverUrl = 'http://localhost:3000'; // Hard-code for now to debug
          const fullUrl = `${serverUrl}/offer`;
          appendToTranscript(`Sending offer to: ${fullUrl}`);
          console.log("Server base from window:", window.SERVER_BASE);
          console.log("Using server URL:", serverUrl);
          
          try {
            // Log the SDP data being sent
            console.log("Sending SDP:", peerConnection.localDescription.sdp.substring(0, 100) + "...");
            
            const response = await fetch(fullUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                sdp: peerConnection.localDescription.sdp
              })
            });
          
          if (!response.ok) {
            appendToTranscript("Error from server: " + response.status);
            const errorText = await response.text();
            appendToTranscript(errorText);
            return false;
          }
          
          // Get answer SDP
          const answerSdp = await response.text();
          appendToTranscript("Got answer from server");
          
          // Set remote description
          await peerConnection.setRemoteDescription({
            type: 'answer',
            sdp: answerSdp
          });
          
          appendToTranscript("WebRTC connection established");
          return true;
          } catch (err) {
            appendToTranscript(`Fetch error: ${err.message}`);
            console.error("Fetch error:", err);
            return false;
          }
        } catch (err) {
          appendToTranscript("Error joining session: " + err.message);
          console.error("Join session error:", err);
          return false;
        }
      }
      
      // Start microphone
      async function startMicrophone() {
        try {
          if (!peerConnection) {
            appendToTranscript("Join session first");
            return false;
          }
          
          // Get user media
          localStream = await navigator.mediaDevices.getUserMedia({
            audio: true
          });
          
          // Add tracks to peer connection
          localStream.getAudioTracks().forEach(track => {
            peerConnection.addTrack(track, localStream);
            appendToTranscript("Added local audio track");
          });
          
          return true;
        } catch (err) {
          appendToTranscript("Error starting microphone: " + err.message);
          console.error("Mic error:", err);
          return false;
        }
      }
      
      // Stop microphone
      function stopMicrophone() {
        if (localStream) {
          localStream.getTracks().forEach(track => track.stop());
          appendToTranscript("Microphone stopped");
          localStream = null;
        }
      }
      
      // Leave session
      function leaveSession() {
        stopMicrophone();
        
        if (dataChannel) {
          dataChannel.close();
          dataChannel = null;
        }
        
        if (peerConnection) {
          peerConnection.close();
          peerConnection = null;
        }
        
        appendToTranscript("Session closed");
      }
      
      // Send TTS request
      function sendTTS(text) {
        if (!dataChannel || dataChannel.readyState !== 'open') {
          appendToTranscript("Data channel not open");
          return false;
        }
        
        try {
          // Format the TTS request according to OpenAI Realtime API specs
          const ttsReq = {
            type: 'text',
            text: text
          };
          dataChannel.send(JSON.stringify(ttsReq));
          appendToTranscript("TTS request sent");
          return true;
        } catch (err) {
          appendToTranscript("Error sending TTS: " + err.message);
          console.error("TTS error:", err);
          return false;
        }
      }
      
      // Make these functions available globally
      window.webrtcJoin = joinRTCSession;
      window.webrtcLeave = leaveSession;
      window.webrtcStartMic = startMicrophone;
      window.webrtcStopMic = stopMicrophone;
      window.webrtcSendTTS = sendTTS;
    ''';
    
    html.document.body!.append(scriptEl);
  }

  void appendTranscript(String s) {
    setState(() => transcriptLines.add(s));
    // scroll after a tiny delay to allow list to update
    Future.delayed(const Duration(milliseconds: 50), () {
      if (transcriptController.hasClients) {
        transcriptController.jumpTo(transcriptController.position.maxScrollExtent);
      }
    });
  }

  void appendChat(String s) {
    setState(() => chatLines.add(s));
  }

  Future<void> joinSession() async {
    if (joined) return;
    
    // Test server connection first
    try {
      appendTranscript('Testing server connection...');
      final response = await http.get(Uri.parse('$SERVER_BASE/'));
      if (response.statusCode != 200) {
        appendTranscript('Server connection test failed: ${response.statusCode}');
      } else {
        appendTranscript('Server connection successful');
      }
    } catch (e) {
      appendTranscript('Server connection error: $e');
    }
    
    // Call the JavaScript function
    final success = js.context.callMethod('webrtcJoin');
    
    if (success == true) {
      setState(() { joined = true; });
      appendTranscript('Session joining...');
    } else {
      appendTranscript('Failed to join session');
    }
  }

  void leaveSession() {
    if (!joined) return;
    
    // Call the JavaScript function
    js.context.callMethod('webrtcLeave');
    
    setState(() {
      joined = false;
      micOn = false;
    });
    appendTranscript('Left session');
  }

  void startMic() async {
    if (!joined) {
      appendTranscript('Start the session (Join) first.');
      return;
    }
    
    // Call the JavaScript function
    final success = await js.context.callMethod('webrtcStartMic');
    
    if (success == true) {
      setState(() { micOn = true; });
      appendTranscript('Microphone started');
    } else {
      appendTranscript('Failed to start microphone');
    }
  }

  void stopMic() {
    if (!micOn) return;
    
    // Call the JavaScript function
    js.context.callMethod('webrtcStopMic');
    
    setState(() { micOn = false; });
    appendTranscript('Microphone stopping...');
  }

  void sendTypedAsTTS() {
    final text = inputController.text.trim();
    if (text.isEmpty) return;
    
    appendChat('${nameController.text}: $text');
    inputController.clear();

    if (!joined) {
      appendChat('TTS failed: Not connected');
      return;
    }

    // Also add to transcript as the user utterance
    appendTranscript('(You) $text');
    
    // Call the JavaScript function
    final success = js.context.callMethod('webrtcSendTTS', [text]);
    
    if (success != true) {
      appendChat('TTS failed: Error sending request');
    }
  }

  @override
  void dispose() {
    transcriptController.dispose();
    inputController.dispose();
    roomController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatroom with WebRTC'),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (!joined)
                  ElevatedButton(
                    onPressed: joinSession,
                    child: const Text('Join'),
                  )
                else
                  ElevatedButton(
                    onPressed: leaveSession,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Leave'),
                  ),
                const SizedBox(width: 16),
                if (joined)
                  IconButton(
                    icon: Icon(micOn ? Icons.mic : Icons.mic_off),
                    onPressed: micOn ? stopMic : startMic,
                    color: micOn ? Colors.red : Colors.grey,
                    tooltip: micOn ? 'Stop Microphone' : 'Start Microphone',
                    iconSize: 28,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Transcript area
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Transcript',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            controller: transcriptController,
                            itemCount: transcriptLines.length,
                            itemBuilder: (context, index) {
                              final line = transcriptLines[index];
                              final isAI = line.startsWith('[AI]');
                              final isEvent = line.startsWith('[event]');
                              final isRaw = line.startsWith('[raw]');
                              final isSystem = !isAI && !line.startsWith('(You)');
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontWeight: isAI ? FontWeight.bold : FontWeight.normal,
                                    color: isAI 
                                      ? Colors.blue[800] 
                                      : isEvent 
                                        ? Colors.purple 
                                        : isRaw 
                                          ? Colors.orange[800]
                                          : isSystem 
                                            ? Colors.grey[600]
                                            : Colors.black,
                                    fontSize: isAI ? 16 : 14,
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
                // Chat area
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[300],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Text Chat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: chatLines.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(chatLines[index]),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: inputController,
                                decoration: const InputDecoration(
                                  labelText: 'Type to speak',
                                  border: OutlineInputBorder(),
                                  hintText: 'Send text for TTS',
                                ),
                                onSubmitted: (_) => sendTypedAsTTS(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: sendTypedAsTTS,
                              tooltip: 'Send as TTS',
                              color: Colors.blue[700],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
