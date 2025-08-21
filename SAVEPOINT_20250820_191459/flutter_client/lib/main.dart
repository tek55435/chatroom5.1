// flutter_client/lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'providers/persona_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/chat_session_provider.dart';
// Removed Ephemeral Chat imports per requirement
// (unused here) import 'screens/persona_list_screen.dart';
import 'screens/persona_creation_dialog.dart';
// (unused here) import 'screens/settings_dialog.dart';
import 'screens/settings_dialog.dart';
import 'screens/help_dialog.dart';
import 'screens/persona_actions_dialog.dart';
import 'widgets/app_menu_drawer.dart';
import 'widgets/share_dialog.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PersonaProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ChatSessionProvider()),
        // EphemeralChatProvider removed per requirement
      ],
      child: const MyApp(),
    ),
  );
}

const String SERVER_BASE = String.fromEnvironment('SERVER_BASE', defaultValue: 'https://hear-all-v11-1.uc.r.appspot.com');

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Access the settings provider to check if dark mode is enabled
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    return MaterialApp(
      title: 'Realtime TTS+STT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: settingsProvider.darkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/': (context) => const HomePage(),
      },
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
  final inputController = TextEditingController();
  
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
  

  // Auto-connect handled by ChatSessionProvider


  // Injects a minimal JS recorder into the page if not present yet.
  void _ensureSimpleRecorderInjected() {
    final has = js_util.hasProperty(html.window, 'SimpleRecorder');
    if (has) return;
    final script = html.ScriptElement()
      ..type = 'text/javascript'
      ..text = r'''
(function(){
  if (window.SimpleRecorder) return;
  function SimpleRecorder(){
    this.audioContext = null;
    this.mediaStream = null;
    this.processor = null;
    this.bufferL = [];
    this.length = 0;
    this.blob = null;
  }
  SimpleRecorder.prototype.start = async function(){
    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    this.mediaStream = await navigator.mediaDevices.getUserMedia({audio:true});
    const source = this.audioContext.createMediaStreamSource(this.mediaStream);
    const bufferSize = 4096;
    const channels = 1;
    this.processor = this.audioContext.createScriptProcessor(bufferSize, channels, channels);
    this.bufferL = [];
    this.length = 0;
    this.processor.onaudioprocess = (e)=>{
      const inL = e.inputBuffer.getChannelData(0);
      this.bufferL.push(new Float32Array(inL));
      this.length += inL.length;
    };
    source.connect(this.processor);
    this.processor.connect(this.audioContext.destination);
  };
  SimpleRecorder.prototype.stop = async function(){
    if (this.processor){ this.processor.disconnect(); }
    if (this.mediaStream){ this.mediaStream.getTracks().forEach(t=>t.stop()); }
    const left = mergeBuffers(this.bufferL, this.length);
    const wav = encodeWAVMono(left, this.audioContext.sampleRate);
    this.blob = new Blob([wav], {type:'audio/wav'});
    return this.blob;
  };

  function mergeBuffers(buffers, len){
    const result = new Float32Array(len);
    let offset = 0;
    for (let i=0;i<buffers.length;i++){
      result.set(buffers[i], offset);
      offset += buffers[i].length;
    }
    return result;
  }
  function floatTo16BitPCM(output, offset, input){
    for (let i = 0; i < input.length; i++, offset += 2) {
      let s = Math.max(-1, Math.min(1, input[i]));
      s = s < 0 ? s * 0x8000 : s * 0x7FFF;
      output.setInt16(offset, s, true);
    }
  }
  function writeString(view, offset, string){
    for (let i = 0; i < string.length; i++) {
      view.setUint8(offset + i, string.charCodeAt(i));
    }
  }
  function encodeWAVMono(samples, sampleRate){
    const buffer = new ArrayBuffer(44 + samples.length * 2);
    const view = new DataView(buffer);
    writeString(view, 0, 'RIFF');
    view.setUint32(4, 36 + samples.length * 2, true);
    writeString(view, 8, 'WAVE');
    writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true);
    view.setUint16(22, 1, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    writeString(view, 36, 'data');
    view.setUint32(40, samples.length * 2, true);
    floatTo16BitPCM(view, 44, samples);
    return view;
  }
  window.SimpleRecorder = SimpleRecorder;
})();
''';
    html.document.head!.append(script);
  }
  
  List<dynamic> audioChunks = [];
  bool isRecording = false;
  bool isTranscribing = false;

  bool joined = false;
  bool micOn = false;
  bool _personaPrompted = false;
  int _lastHandledChatIndex = -1;
  
  // Function to test audio output
  void playTestSound() {
    js.context.callMethod('eval', ['''
      function playTestBeep() {
        if (!window.audioContext) {
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            window.audioQueue = [];
            window.isPlayingAudio = false;
            console.log("Audio context created for test sound");
            dartAppendTranscript("[audio] Audio system initialized for test");
          } catch (err) {
            console.error("Failed to create audio context:", err);
            dartAppendTranscript("[error] Failed to initialize audio: " + err.message);
            return;
          }
        }
        
        if (window.audioContext.state !== "running") {
          window.audioContext.resume().then(() => {
            console.log("Audio context resumed for test sound");
            createAndPlayTestTone();
          }).catch(err => {
            console.error("Failed to resume audio context:", err);
            dartAppendTranscript("[error] Failed to resume audio: " + err.message);
          });
        } else {
          createAndPlayTestTone();
        }
        
        function createAndPlayTestTone() {
          // Create a simple beep sound
          const oscillator = window.audioContext.createOscillator();
          const gainNode = window.audioContext.createGain();
          
          oscillator.type = 'sine';
          oscillator.frequency.value = 440; // 440 Hz - A note
          oscillator.connect(gainNode);
          gainNode.connect(window.audioContext.destination);
          
          // Start the tone
          gainNode.gain.value = 0.5; // Set volume to 50%
          oscillator.start();
          
          // Stop after 0.5 seconds
          setTimeout(() => {
            oscillator.stop();
            dartAppendTranscript("[audio] Test sound played");
          }, 500);
        }
      }
      
      playTestBeep();
    ''']);
  }

  @override
  void initState() {
    super.initState();
    // Auto-connect handled by ChatSessionProvider
    
    // Set up JavaScript functions to call back into Flutter
    js.context['dartAppendTranscript'] = (String text) {
      appendTranscript(text);
    };
    
    // Listen for changes in settings and update accordingly
    Future.delayed(Duration.zero, () {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      settingsProvider.addListener(_updateAudioSettings);

      // Listen for new chat messages to optionally auto-play on this client
      final chat = Provider.of<ChatSessionProvider>(context, listen: false);
      chat.addListener(_onChatUpdated);
      // Avoid replaying full history on first attach
      _lastHandledChatIndex = chat.messages.length - 1;

      // Keep chat username synced with selected Persona
      final personaProvider = Provider.of<PersonaProvider>(context, listen: false);
      personaProvider.addListener(_onPersonaChanged);
    });
    
    // Add callback for when connection is fully established
    js.context['dartConnectionEstablished'] = () {
      setState(() { 
        joined = true; 
      });
      appendTranscript('[system] Connection fully established and ready to use');

      // Update audio settings based on user preferences
      _updateAudioSettings();
      
      // Explicitly initialize audio context when connection is established
      js.context.callMethod('eval', ['''
        if (!window.audioContext) {
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            window.audioQueue = [];
            window.isPlayingAudio = false;
            console.log("Audio context explicitly initialized after connection");
            dartAppendTranscript("[audio] Audio system explicitly initialized");
          } catch (err) {
            console.error("Failed to initialize audio context:", err);
            dartAppendTranscript("[error] Failed to initialize audio: " + err.message);
          }
        } else if (window.audioContext.state !== "running") {
          window.audioContext.resume().then(() => {
            console.log("Audio context explicitly resumed after connection");
            dartAppendTranscript("[audio] Audio system resumed");
          });
        }
      ''']);
    };
    
    // Make the server base URL available to JavaScript
    js.context['SERVER_BASE'] = SERVER_BASE;
    
    // Add our PCM helper script first
    final pcmHelperScript = html.ScriptElement();
    pcmHelperScript.type = 'text/javascript';
    pcmHelperScript.src = 'pcm_helper.js';
    html.document.head?.append(pcmHelperScript);
    
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
          console.log("Data channel created:", dataChannel);
          
          dataChannel.onopen = () => {
            console.log("Data channel is now open");
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
            console.log("Sending session config:", sessionConfig);
            dataChannel.send(JSON.stringify(sessionConfig));
            appendToTranscript("Session config sent");
            
            // Now the connection is truly established and ready to use
            notifyConnectionReady();
          };
          
          dataChannel.onerror = (error) => {
            console.error("Data channel error:", error);
            // More detailed error logging - error might be an Event object or Error
            if (error && error.message) {
              appendToTranscript("[error] Data channel error: " + error.message);
            } else {
              appendToTranscript("[error] Data channel error: " + JSON.stringify(error));
            }
          };
          
          dataChannel.onclose = () => {
            console.log("Data channel closed");
            appendToTranscript("Data channel closed");
            connectionEstablished = false;
            // Try to reconnect if not explicitly closed by the user
            setTimeout(() => {
              if (!connectionEstablished && peerConnection === null) {
                appendToTranscript("Attempting to reconnect...");
                initWebRTC().then(success => {
                  if (success) {
                    joinRTCSession();
                  }
                });
              }
            }, 3000);
          };
          
          dataChannel.onmessage = (event) => {
            try {
              // Log the raw message for debugging with more details
              const dataPreview = typeof event.data === 'string' ? 
                (event.data.length > 100 ? `${event.data.substring(0, 100)}... (${event.data.length} bytes)` : event.data) : 
                "non-string data";
              console.log("Raw message received:", dataPreview);
              appendToTranscript(`[debug] Message received: ${new Date().toLocaleTimeString()}`);
              
              const data = JSON.parse(event.data);
              const type = data.type || '';
              
              // More detailed logging
              console.log(`Event type: ${type}, timestamp: ${new Date().toISOString()}`);
              console.log("Parsed message:", JSON.stringify(data).substring(0, 200) + "...");
              
              // Handle different types of events
              if (type.startsWith('transcript')) {
                const text = data.text || data.delta || data.content || '';
                appendToTranscript("[AI] " + text);
              } else if (type === 'session.created' || type === 'session.updated') {
                // Just log these system events without showing full JSON
                appendToTranscript("[system] Session " + (type === 'session.created' ? 'created' : 'updated'));
                console.log("Session event details:", JSON.stringify(data));
              } else if (type === 'error') {
                // Show errors prominently
                const errorMsg = data.error?.message || data.message || JSON.stringify(data);
                appendToTranscript("[error] " + errorMsg);
                console.error("Error event received:", data);
              } else if (type === 'audio.metadata') {
                // Handle audio metadata events
                console.log("Audio metadata:", JSON.stringify(data));
                appendToTranscript("[audio] Audio metadata received");
                
                // Initialize audio context and buffers if needed for upcoming audio chunks
                if (!window.audioContext) {
                  try {
                    window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    window.audioQueue = [];
                    window.isPlayingAudio = false;
                    appendToTranscript("[audio] Audio context initialized");
                  } catch (err) {
                    console.error("Failed to create audio context:", err);
                    appendToTranscript("[error] Failed to create audio context: " + err.message);
                  }
                } else {
                  // Ensure the audio context is running
                  if (window.audioContext.state !== "running") {
                    window.audioContext.resume().then(() => {
                      console.log("Audio context resumed during metadata");
                      appendToTranscript("[audio] Audio resumed");
                    }).catch(err => {
                      console.error("Failed to resume audio context:", err);
                    });
                  }
                  
                  // Reset audio queue in case there were issues with previous playback
                  if (window.audioQueue === undefined) {
                    window.audioQueue = [];
                  }
                  console.log("Audio context ready for playback");
                }
              } else if (type === 'audio.chunk') {
                // Handle audio chunk events
                console.log("Audio chunk received at", new Date().toISOString());
                appendToTranscript("[audio] Audio chunk received");
                
                // Extra debug info to see what's in the data
                const chunkInfo = {
                  hasBytes: data.chunk && !!data.chunk.bytes,
                  format: data.chunk ? (data.chunk.format || "unknown") : "no format",
                  byteLength: data.chunk && data.chunk.bytes ? atob(data.chunk.bytes).length : 0,
                  timestamp: new Date().toISOString()
                };
                console.log("Audio chunk details:", chunkInfo);
                
                // Log the full data structure without the bytes for brevity
                const logData = {...data};
                if (logData.chunk && logData.chunk.bytes) {
                  logData.chunk.bytes = `[${chunkInfo.byteLength} bytes]`;
                }
                console.log("Audio chunk data:", JSON.stringify(logData));
                
                // Process and play the audio chunk
                if (window.audioContext && data.chunk && data.chunk.bytes) {
                  try {
                    // Track that we received an audio chunk
                    window.lastAudioChunkTime = Date.now();
                    console.log("Audio chunk received with format:", data.chunk.format || "PCM");
                    
                    // Decode the base64 audio data
                    const audioBytes = atob(data.chunk.bytes);
                    const audioBuffer = new ArrayBuffer(audioBytes.length);
                    const audioView = new Uint8Array(audioBuffer);
                    for (let i = 0; i < audioBytes.length; i++) {
                      audioView[i] = audioBytes.charCodeAt(i);
                    }
                    
                    // Log audio chunk details
                    console.log(`Received audio chunk: ${audioBytes.length} bytes`);
                    
                    // Queue the audio for playback
                    window.audioQueue.push(audioBuffer);
                    console.log(`Audio queue length: ${window.audioQueue.length}`);
                    
                    // Debug help
                    document.title = `Audio Chunks: ${window.audioQueue.length}`;
                    
                    // Try playing directly with our PCM helper
                    try {
                      if (window.playPCMBuffer) {
                        console.log("Using PCM helper for direct playback");
                        // First analyze the audio to make sure it has sound
                        if (window.analyzeAudioBuffer) {
                          const analysis = window.analyzeAudioBuffer(audioBuffer);
                          console.log("Audio analysis:", analysis);
                          appendToTranscript(`[audio] Sample size: ${analysis.sampleCount} samples, duration: ${analysis.estimatedDurationMs.toFixed(0)}ms`);
                          
                          if (!analysis.hasAudio) {
                            console.warn("Audio chunk appears to be silent");
                          }
                        }
                        
                        // Try to play it directly
                        window.playPCMBuffer(audioBuffer)
                          .then(() => {
                            console.log("PCM helper direct playback succeeded");
                            appendToTranscript("[audio] Audio played successfully");
                          })
                          .catch(err => {
                            console.error("PCM helper playback failed:", err);
                            appendToTranscript("[error] Direct audio playback failed");
                          });
                      } else {
                        // Fall back to standard approach if helper not loaded
                        console.log("PCM helper not available, using standard approach");
                        const context = new (window.AudioContext || window.webkitAudioContext)();
                        context.decodeAudioData(audioBuffer, 
                          (decoded) => {
                            const source = context.createBufferSource();
                            source.buffer = decoded;
                            source.connect(context.destination);
                            source.start(0);
                            console.log("Immediate audio playback started");
                          },
                          (err) => {
                            console.error("Direct playback decoding failed:", err);
                          }
                        );
                      }
                    } catch (directErr) {
                      console.log("Direct playback attempt failed:", directErr);
                      // Continue with queued playback
                    }
                    
                    // Make sure audio context is running
                    if (window.audioContext.state !== "running") {
                      console.log("Audio context not running, attempting to resume");
                      // Try to resume with user interaction
                      document.body.addEventListener('click', function resumeAudioContext() {
                        window.audioContext.resume().then(() => {
                          console.log("Audio context resumed via click");
                          document.body.removeEventListener('click', resumeAudioContext);
                        });
                      }, { once: true });
                      
                      window.audioContext.resume().then(() => {
                        console.log("Audio context resumed successfully");
                        // Start playback if not already playing
                        if (!window.isPlayingAudio) {
                          console.log("Starting audio playback chain");
                          playNextAudioChunk();
                        }
                      }).catch(err => {
                        console.error("Failed to resume audio context:", err);
                      });
                    } else {
                      // Start playback if not already playing
                      if (!window.isPlayingAudio) {
                        console.log("Starting audio playback chain");
                        playNextAudioChunk();
                      }
                    }
                  } catch (err) {
                    console.error("Error processing audio chunk:", err);
                    appendToTranscript("[error] Audio playback error: " + err.message);
                  }
                } else {
                  console.error("Missing required audio data", {
                    hasAudioContext: !!window.audioContext,
                    hasChunk: !!data.chunk,
                    hasBytes: data.chunk ? !!data.chunk.bytes : false
                  });
                }
              } else if (type === 'content_block.delta') {
                // Handle content blocks
                if (data.delta && data.delta.text) {
                  appendToTranscript("[AI] " + data.delta.text);
                }
              } else if (type === 'response.created' || type === 'response.complete') {
                // Handle response events
                appendToTranscript("[system] Response " + (type === 'response.created' ? 'started' : 'completed'));
                console.log("Response event:", JSON.stringify(data));
              } else if (type === 'response.delta') {
                // Handle streaming response
                if (data.delta && data.delta.completion && data.delta.completion.text) {
                  appendToTranscript("[AI] " + data.delta.completion.text);
                }
              } else {
                // Other events - log to console but don't show in transcript
                console.log("Event received:", type, data);
                // Only show type in transcript, not full JSON
                appendToTranscript("[event] Event type: " + type);
              }
            } catch (e) {
              console.error("Error parsing message:", e, event.data);
              // Only show first 50 chars of raw data to avoid cluttering the UI
              const preview = event.data.length > 50 ? event.data.substring(0, 50) + "..." : event.data;
              appendToTranscript("[raw] Invalid message format: " + preview);
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
      
      // Variable to track connection state
      let connectionEstablished = false;
      
      // Function to notify Dart that connection is ready
      function notifyConnectionReady() {
        connectionEstablished = true;
        if (window.dartConnectionEstablished) {
          window.dartConnectionEstablished();
        }
      }
      
      // Join session
      async function joinRTCSession(attempt = 0) {
        try {
          // Reset connection state
          connectionEstablished = false;
          
          // Initialize audio context early
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            window.audioQueue = [];
            window.isPlayingAudio = false;
            console.log("Audio context initialized during join");
            appendToTranscript("[audio] Audio system initialized");
            
            // Resume the audio context if it's not in running state
            if (window.audioContext.state !== "running") {
              await window.audioContext.resume();
              console.log("Audio context resumed");
            }
          } catch (audioErr) {
            console.error("Failed to initialize audio context:", audioErr);
            appendToTranscript("[error] Failed to initialize audio system: " + audioErr.message);
          }
          
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
          // Prefer window.SERVER_BASE injected from Dart, fallback to deployed server
          const serverUrl = (window.SERVER_BASE && typeof window.SERVER_BASE === 'string') 
            ? window.SERVER_BASE 
            : 'https://hear-all-v11-1.uc.r.appspot.com';
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
            // Retry with backoff when server responds with error
            const delay = Math.min(30000, 2000 * Math.max(1, attempt + 1));
            appendToTranscript(`[retry] Join failed (HTTP ${response.status}). Retrying in ${Math.round(delay/1000)}s...`);
            setTimeout(() => joinRTCSession(attempt + 1), delay);
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
          
          // Return true now but don't set connectionEstablished yet
          // That will happen when the data channel opens
          return true;
          } catch (err) {
            appendToTranscript(`Fetch error: ${err.message}`);
            console.error("Fetch error:", err);
            // Retry with backoff if network error (server down/not yet started)
            const delay = Math.min(30000, 2000 * Math.max(1, attempt + 1));
            appendToTranscript(`[retry] Network error joining session. Retrying in ${Math.round(delay/1000)}s... (attempt ${attempt+1})`);
            setTimeout(() => joinRTCSession(attempt + 1), delay);
            return false;
          }
        } catch (err) {
          appendToTranscript("Error joining session: " + err.message);
          console.error("Join session error:", err);
          // Retry unexpected errors a couple of times
          if (attempt < 3) {
            const delay = 2000 * (attempt + 1);
            setTimeout(() => joinRTCSession(attempt + 1), delay);
          }
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
        console.log("sendTTS called with text:", text);
        
        // Check all connection conditions
        if (!peerConnection) {
          console.error("WebRTC connection not initialized");
          appendToTranscript("TTS failed: Not connected");
          return false;
        }
        
        if (!connectionEstablished) {
          console.error("Connection not fully established");
          appendToTranscript("TTS failed: Not connected");
          return false;
        }
        
        if (!dataChannel) {
          console.error("Data channel is null");
          appendToTranscript("TTS failed: Not connected");
          return false;
        }
        
        if (dataChannel.readyState !== 'open') {
          console.error("Data channel not open, current state:", dataChannel.readyState);
          appendToTranscript("TTS failed: Not connected");
          return false;
        }
        
        // Initialize audio context if it doesn't exist
        if (!window.audioContext) {
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            window.audioQueue = [];
            window.isPlayingAudio = false;
            console.log("Created audio context during TTS request");
            appendToTranscript("[audio] Audio system initialized");
          } catch (err) {
            console.error("Failed to create audio context:", err);
            appendToTranscript("[error] Failed to initialize audio: " + err.message);
            // Continue anyway, as the audio context might be created during chunk reception
          }
        } else if (window.audioContext.state !== "running") {
          // Try to resume the audio context
          window.audioContext.resume().then(() => {
            console.log("Audio context resumed during TTS request");
          }).catch(err => {
            console.error("Failed to resume audio context:", err);
          });
        }
        
        try {
          // Setup audio first
          if (!window.audioContext) {
            try {
              window.audioContext = new (window.AudioContext || window.webkitAudioContext)();
              window.audioQueue = [];
              window.isPlayingAudio = false;
              console.log("Audio context created before TTS request");
              appendToTranscript("[audio] Audio system initialized");
            } catch (audioErr) {
              console.error("Failed to create audio context:", audioErr);
            }
          }
          
          // Try to resume the audio context (important for autoplay policy)
          if (window.audioContext && window.audioContext.state !== "running") {
            window.audioContext.resume().then(() => {
              console.log("Audio context resumed before TTS request");
            }).catch(err => {
              console.warn("Could not resume audio context:", err);
            });
          }
        
          // Try DIRECT API call to server's TTS endpoint instead of using WebRTC data channel
          // This bypasses the WebRTC data channel but still uses our server for TTS
          try {
            appendToTranscript("[debug] Trying direct TTS API call");
            
            // Call our server-side TTS API directly
            fetch(`${window.SERVER_BASE}/api/tts`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ text: text, voice: 'alloy' })
            })
            .then(response => {
              if (!response.ok) {
                throw new Error(`HTTP error ${response.status}`);
              }
              return response.arrayBuffer();
            })
            .then(audioData => {
              appendToTranscript("[debug] Direct TTS API returned audio data");
              
              // Play the audio directly
              const audioContext = new (window.AudioContext || window.webkitAudioContext)();
              audioContext.decodeAudioData(audioData, 
                buffer => {
                  const source = audioContext.createBufferSource();
                  source.buffer = buffer;
                  source.connect(audioContext.destination);
                  source.start(0);
                  appendToTranscript("[audio] Playing TTS audio via direct API");
                },
                error => {
                  console.error("Error decoding audio data:", error);
                  appendToTranscript("[error] Failed to decode TTS audio");
                }
              );
            })
            .catch(error => {
              console.error("TTS API error:", error);
              appendToTranscript("[error] TTS API error: " + error.message);
            });
            
            return true; // We're handling this asynchronously
          } catch (apiError) {
            console.error("Error calling TTS API:", apiError);
            appendToTranscript("[error] Failed to call TTS API: " + apiError.message);
          }
          
          // Debug the request with more visibility
          console.log("SENDING TTS REQUEST (EXPLICIT DEBUG):", JSON.stringify(ttsReq));
          appendToTranscript("[debug] Sending TTS request: " + JSON.stringify(ttsReq));
          
          // Add a timestamp to track when we sent it (helpful for debugging)
          window.lastTTSRequestTime = Date.now();
          
          // Send the request
          dataChannel.send(JSON.stringify(ttsReq));
          
          // Update UI
          appendToTranscript("TTS request sent");
          
          // Set a timeout to check if we don't get audio back
          setTimeout(() => {
            const elapsedTime = Date.now() - (window.lastTTSRequestTime || 0);
            // If more than 5 seconds passed and we haven't gotten any audio chunks
            if (elapsedTime > 5000 && (!window.lastAudioChunkTime || window.lastAudioChunkTime < window.lastTTSRequestTime)) {
              console.warn("No audio response received after 5 seconds");
              appendToTranscript("[warning] No audio response received");
            }
          }, 5000);
          
          return true;
        } catch (err) {
          appendToTranscript("TTS failed: " + err.message);
          console.error("TTS error:", err);
          return false;
        }
      }
      
      // Play the next audio chunk in the queue
      function playNextAudioChunk() {
        if (!window.audioContext) {
          console.error("Audio context not initialized");
          appendToTranscript("[error] Audio context not initialized");
          window.isPlayingAudio = false;
          return;
        }
        
        if (window.audioQueue.length === 0) {
          console.log("Audio queue is empty, playback complete");
          window.isPlayingAudio = false;
          return;
        }
        
        window.isPlayingAudio = true;
        const audioBuffer = window.audioQueue.shift();
        console.log(`Playing chunk, ${window.audioQueue.length} chunks remaining in queue`);
        
        // Make sure the audio context is in running state
        if (window.audioContext.state !== "running") {
          console.log(`Audio context state is ${window.audioContext.state}, attempting to resume`);
          window.audioContext.resume().then(() => {
            console.log("Audio context resumed successfully");
            processAudioChunk(audioBuffer);
          }).catch(err => {
            console.error("Failed to resume audio context:", err);
            appendToTranscript("[error] Failed to resume audio playback");
            // Try to continue anyway
            processAudioChunk(audioBuffer);
          });
        } else {
          processAudioChunk(audioBuffer);
        }
        
        function processAudioChunk(buffer) {
          try {
            // Log buffer details for debugging
            console.log(`Processing audio buffer: ${buffer.byteLength} bytes`);
            appendToTranscript(`[audio] Processing ${buffer.byteLength} bytes`);
            
            // OpenAI sends PCM audio data which needs to be decoded properly
            // We need to make sure we're handling the format correctly
            
            // Try multiple methods for handling the audio, in order of preference
            
            // Method 1: Try with DataView for precise control (best for PCM)
            try {
              console.log("Trying PCM decoding with DataView");
              const view = new DataView(buffer);
              const audioLength = Math.floor(buffer.byteLength / 2); // 16-bit = 2 bytes per sample
              const audioBuffer = window.audioContext.createBuffer(1, audioLength, 24000);
              const channelData = audioBuffer.getChannelData(0);
              
              // Convert Int16 to Float32 (required by Web Audio API)
              for (let i = 0; i < audioLength; i++) {
                // Read 16-bit PCM sample (little-endian)
                const sample = view.getInt16(i * 2, true); 
                // Scale to Float32 range (-1.0 to 1.0)
                channelData[i] = sample / 32768.0;
              }
              
              console.log("PCM decoding successful with DataView");
              playDecodedBuffer(audioBuffer);
              return; // Successfully decoded
            } catch (dataViewErr) {
              console.warn("DataView decoding failed:", dataViewErr);
            }
            
            // Method 2: Try with Int16Array (simpler but less control)
            try {
              console.log("Trying PCM decoding with Int16Array");
              // Assume 24kHz 16-bit mono PCM (based on OpenAI docs)
              const view = new Int16Array(buffer);
              const audioBuffer = window.audioContext.createBuffer(1, view.length, 24000);
              const nowBuffering = audioBuffer.getChannelData(0);
              
              // Convert Int16 to Float32 (required by Web Audio API)
              for (let i = 0; i < view.length; i++) {
                // Scale Int16 values to Float32 range (-1.0 to 1.0)
                nowBuffering[i] = view[i] / 32768.0;
              }
              
              console.log("PCM decoding successful with Int16Array");
              playDecodedBuffer(audioBuffer);
              return; // Successfully decoded
            } catch (int16Err) {
              console.warn("Int16Array decoding failed:", int16Err);
            }
            
            // Method 3: Try decodeAudioData as a last resort
            try {
              console.log("Trying standard decodeAudioData method");
              window.audioContext.decodeAudioData(buffer, 
                (decodedBuffer) => {
                  console.log("Standard decodeAudioData succeeded");
                  playDecodedBuffer(decodedBuffer);
                },
                (decodeErr) => {
                  console.error("All decoding methods failed:", decodeErr);
                  appendToTranscript("[error] Audio decoding failed");
                  // Try the next chunk
                  playNextAudioChunk();
                }
              );
            } catch (decodeAttemptErr) {
              console.error("Could not attempt decoding:", decodeAttemptErr);
              appendToTranscript("[error] Audio decode attempt failed");
              playNextAudioChunk();
            }
            
            function playDecodedBuffer(decodedBuffer) {
              try {
                // Create audio source node
                const source = window.audioContext.createBufferSource();
                source.buffer = decodedBuffer;
                source.connect(window.audioContext.destination);
                
                // When this chunk finishes, play the next one
                source.onended = () => {
                  playNextAudioChunk();
                };
                
                // Play this chunk
                source.start(0);
                console.log("Audio playback started successfully");
                appendToTranscript("[audio] Playing audio");
              } catch (playError) {
                console.error("Error playing audio:", playError);
                appendToTranscript("[error] Audio playback error");
                // Try to continue with the next chunk
                playNextAudioChunk();
              }
            }
          } catch (err) {
            console.error("Error processing audio chunk:", err);
            appendToTranscript("[error] Audio processing error");
            // Try the next chunk
            playNextAudioChunk();
          }
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

    // After first frame: ensure persona, then connect and join RTC
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final personaProvider = Provider.of<PersonaProvider>(context, listen: false);
      if (personaProvider.personas.isEmpty && !_personaPrompted) {
        _personaPrompted = true;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PersonaCreationDialog(),
        );
      }

      // Connect chat backend (ensures timing after persona)
      try {
        final chat = Provider.of<ChatSessionProvider>(context, listen: false);
        if (!chat.isConnected && !chat.isConnecting) {
          await chat.connectToChatRoom(null);
          final personaName = Provider.of<PersonaProvider>(context, listen: false).selectedPersona?.name;
          if (personaName != null && personaName.isNotEmpty) {
            chat.setUserName(personaName);
          }
        }
      } catch (_) {}

      // Join WebRTC session once bridge is ready
      js.context.callMethod('eval', ['''
        try {
          setTimeout(() => { if (window.webrtcJoin) window.webrtcJoin(0); }, 0);
        } catch (err) { console.error('Failed to join WebRTC:', err); }
      ''']);
    });
  }

  void appendTranscript(String s) {
    setState(() => transcriptLines.add(s));
    
    // Also add to diagnostic logs with timestamp
    final timestamp = DateTime.now().toIso8601String();
    appendDiagnostic("[$timestamp] $s");
    
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
  
  void appendDiagnostic(String s) {
    setState(() => diagnosticLogs.add(s));
    // scroll after a tiny delay to allow list to update
    Future.delayed(const Duration(milliseconds: 50), () {
      if (diagnosticController.hasClients) {
        diagnosticController.jumpTo(diagnosticController.position.maxScrollExtent);
      }
    });
  }
  
  void copyDiagnosticLogs() {
    final text = diagnosticLogs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    appendDiagnostic("[System] Logs copied to clipboard");
  }
  
  void clearDiagnosticLogs() {
    setState(() {
      diagnosticLogs.clear();
    });
    appendDiagnostic("[System] Logs cleared");
  }
  
  void toggleDiagnosticPanel() {
    setState(() {
      showDiagnosticPanel = !showDiagnosticPanel;
    });
    appendDiagnostic("[System] Diagnostic panel ${showDiagnosticPanel ? 'opened' : 'closed'}");
  }
  
  void testAudioInitialization() {
    appendDiagnostic("[Test] Testing audio initialization...");
    js.context.callMethod('eval', ['''
      try {
        if (!window.audioContext) {
          window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
          window.audioQueue = [];
          window.isPlayingAudio = false;
          dartAppendTranscript("[Test] Created new AudioContext: " + window.audioContext.state);
        } else {
          dartAppendTranscript("[Test] AudioContext already exists: " + window.audioContext.state);
          if (window.audioContext.state !== "running") {
            window.audioContext.resume().then(() => {
              dartAppendTranscript("[Test] AudioContext resumed: " + window.audioContext.state);
            }).catch(err => {
              dartAppendTranscript("[Test] Failed to resume AudioContext: " + err.message);
            });
          }
        }
        
        // Test creating an audio node
        const testNode = window.audioContext.createGain();
        dartAppendTranscript("[Test] Successfully created audio node");
        
        // Additional state info
        dartAppendTranscript("[Test] Audio queue length: " + (window.audioQueue ? window.audioQueue.length : "undefined"));
        dartAppendTranscript("[Test] isPlayingAudio: " + (window.isPlayingAudio ? "true" : "false"));
      } catch (err) {
        dartAppendTranscript("[Test] Audio initialization error: " + err.message);
        console.error("Audio test error:", err);
      }
    ''']);
  }
  
  void testWebRTCConnection() {
    appendDiagnostic("[Test] Testing WebRTC connection...");
    js.context.callMethod('eval', ['''
      try {
        if (!window.peerConnection) {
          dartAppendTranscript("[Test] No WebRTC connection exists");
          return;
        }
        
        dartAppendTranscript("[Test] WebRTC connection state: " + window.peerConnection.connectionState);
        dartAppendTranscript("[Test] ICE connection state: " + window.peerConnection.iceConnectionState);
        dartAppendTranscript("[Test] Signaling state: " + window.peerConnection.signalingState);
        
        if (window.dataChannel) {
          dartAppendTranscript("[Test] Data channel state: " + window.dataChannel.readyState);
          
          // Test sending a message through data channel
          if (window.dataChannel.readyState === "open") {
            try {
              const testMsg = {type: "test_message", timestamp: new Date().toISOString()};
              window.dataChannel.send(JSON.stringify(testMsg));
              dartAppendTranscript("[Test] Test message sent through data channel");
            } catch (sendErr) {
              dartAppendTranscript("[Test] Failed to send test message: " + sendErr.message);
            }
          } else {
            dartAppendTranscript("[Test] Data channel not open, can't send test message");
          }
        } else {
          dartAppendTranscript("[Test] No data channel exists");
        }
      } catch (err) {
        dartAppendTranscript("[Test] WebRTC test error: " + err.message);
        console.error("WebRTC test error:", err);
      }
    ''']);
  }
  
  void testTTSSystem() {
    appendDiagnostic("[Test] Testing TTS functionality...");
    final testText = "This is a test of the text to speech system";
    
    // First try WebRTC TTS
    appendDiagnostic("[Test] Testing WebRTC TTS channel...");
    js.context.callMethod('eval', ['''
      try {
        if (window.sendTTS && typeof window.sendTTS === "function") {
          const result = window.sendTTS("${testText} via WebRTC");
          dartAppendTranscript("[Test] WebRTC TTS send result: " + (result ? "success" : "failed"));
        } else {
          dartAppendTranscript("[Test] WebRTC TTS function not available");
        }
      } catch (err) {
        dartAppendTranscript("[Test] WebRTC TTS test error: " + err.message);
        console.error("WebRTC TTS test error:", err);
      }
    ''']);
    
    // Then try direct TTS
    Future.delayed(const Duration(seconds: 2), () {
      appendDiagnostic("[Test] Testing direct HTTP TTS...");
      useDirectTTS("$testText via HTTP");
    });
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
      // We don't set joined=true here anymore
      // Instead, we'll wait for dartConnectionEstablished to be called
      appendTranscript('Session joining... please wait');
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
    if (text.isEmpty) {
      appendTranscript('[info] Cannot send empty message');
      return;
    }
    // Post to shared chat (so others hear it); do not play locally by default
    try {
      final chat = Provider.of<ChatSessionProvider>(context, listen: false);
      if (!chat.isConnected && !chat.isConnecting) {
        chat.connectToChatRoom(null);
      }
      chat.sendMessage(text);
      appendTranscript('(You) $text');
      // If user wants local playback of their own outgoing audio, play it now
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.playOutgoingAudio) {
        try {
          if (joined) {
            js.context.callMethod('webrtcSendTTS', [text]);
          } else {
            // Fallback to direct API if WebRTC not ready
            // ignore: unawaited_futures
            useDirectTTS(text);
          }
        } catch (_) {}
      }
    } catch (e) {
      appendTranscript('[error] Failed to send message to room: $e');
    } finally {
      inputController.clear();
    }
  }
  
  // Function to use our new API endpoint for text-to-speech
  Future<void> useDirectTTS(String text) async {
    try {
      appendTranscript('[info] Using direct TTS API: $text');
      
      // Make HTTP request to our TTS endpoint
      final response = await http.post(
        Uri.parse('$SERVER_BASE/api/tts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      );
      
      if (response.statusCode == 200) {
        appendTranscript('[info] TTS API response received, playing audio...');
        
        // Play the audio using Web Audio API
        final audioBlob = html.Blob([response.bodyBytes], 'audio/mpeg');
        final audioUrl = html.Url.createObjectUrlFromBlob(audioBlob);
        final audioElement = html.AudioElement()..src = audioUrl;
        audioElement.play();
        
        appendTranscript('[success] Direct TTS audio playing');
      } else {
        appendTranscript('[error] Failed to get TTS: ${response.statusCode}');
        print('TTS API error: ${response.body}');
      }
    } catch (e) {
      appendTranscript('[error] Exception using TTS API: $e');
      print('Error with TTS API: $e');
    }
  }
  
  // Function to start recording audio for STT
  void startRecording() async {
    appendTranscript('[info] Starting audio recording for STT...');
    try {
      // Environment diagnostics
      final isSecure = js_util.getProperty(html.window, 'isSecureContext') == true;
      appendTranscript('[diag] isSecureContext=$isSecure');
      appendTranscript('[diag] navigator present=true');

      // Prefer using dart:html typed API to obtain a MediaStream (avoids JS Promise interop pitfalls)
      html.MediaStream? htmlStream;
      try {
        htmlStream = await html.window.navigator.mediaDevices
            ?.getUserMedia({'audio': true});
      } catch (e) {
        appendTranscript('[warn] getUserMedia via dart:html failed: $e; attempting JS fallback');
      }

      dynamic stream = htmlStream;
      if (stream == null) {
        // JS fallback
        final constraints = js_util.jsify({'audio': true, 'video': false});
        final navigatorObj = js_util.getProperty(js.context, 'navigator');
        if (navigatorObj == null) {
          appendTranscript('[error] Navigator is not available in this context');
          return;
        }
        final mediaDevices = js_util.getProperty(navigatorObj, 'mediaDevices');
        if (mediaDevices == null) {
          appendTranscript('[error] mediaDevices not available (insecure context?)');
          return;
        }
        final jsGetUM = js_util.getProperty(mediaDevices, 'getUserMedia');
        final isFunc = js_util.instanceof(jsGetUM, js.context['Function']);
        if (!isFunc) {
          appendTranscript('[error] mediaDevices.getUserMedia is not a function');
          return;
        }
        final promise = js_util.callMethod(mediaDevices, 'getUserMedia', [constraints]);
        // Some environments may return non-Promise; guard by checking for a 'then' property
        if (promise != null && js_util.hasProperty(promise, 'then')) {
          stream = await js_util.promiseToFuture<dynamic>(promise);
        } else {
          appendTranscript('[error] getUserMedia did not return a Promise; cannot proceed');
          return;
        }
      }

      // Check MediaRecorder support via window object (more reliable)
      final mediaRecorderCtor = js_util.getProperty(html.window, 'MediaRecorder');
      appendTranscript('[diag] typeof MediaRecorder=' + (mediaRecorderCtor == null ? 'null' : 'function'));
      if (mediaRecorderCtor == null) {
        // Inject and use a JS fallback recorder (ScriptProcessor → WAV)
        _ensureSimpleRecorderInjected();
        final ctor = js_util.getProperty(html.window, 'SimpleRecorder');
        if (ctor == null) {
          appendTranscript('[error] Fallback recorder injection failed');
          return;
        }
        simpleRecorder = js_util.callConstructor(ctor, const []);
        try {
          final startPromise = js_util.callMethod(simpleRecorder, 'start', const []);
          if (startPromise != null && js_util.hasProperty(startPromise, 'then')) {
            await js_util.promiseToFuture(startPromise);
          }
          useSimpleRecorder = true;
          fallbackBlob = null;
          setState(() { isRecording = true; });
          appendTranscript('[info] Fallback recording started. Speak now...');
          return; // Skip MediaRecorder path
        } catch (e) {
          appendTranscript('[error] Failed to start fallback recorder: $e');
          return;
        }
      }

      // Choose a supported mimeType if available
      String? chosenType;
      try {
        final isTypeSupported = js_util.getProperty(mediaRecorderCtor, 'isTypeSupported');
        if (isTypeSupported != null) {
          bool supports(String t) => js_util.callMethod<bool>(mediaRecorderCtor, 'isTypeSupported', [t]) == true;
          if (supports('audio/webm;codecs=opus')) {
            chosenType = 'audio/webm;codecs=opus';
          } else if (supports('audio/webm')) {
            chosenType = 'audio/webm';
          } else if (supports('audio/mp4')) {
            chosenType = 'audio/mp4'; // Safari/iOS
          } else if (supports('audio/aac')) {
            chosenType = 'audio/aac'; // Safari/iOS
          }
        }
      } catch (_) {}

      appendTranscript('[diag] chosen mimeType=' + (chosenType ?? 'default'));

      // Create MediaRecorder(stream)
      try {
        if (chosenType != null) {
          final options = js_util.jsify({'mimeType': chosenType});
          mediaRecorder = js_util.callConstructor(mediaRecorderCtor, [stream, options]);
        } else {
          mediaRecorder = js_util.callConstructor(mediaRecorderCtor, [stream]);
        }
      } catch (e) {
        appendTranscript('[error] Failed to construct MediaRecorder: $e');
        // As a last resort, use the WAV fallback
        _ensureSimpleRecorderInjected();
        final ctor = js_util.getProperty(html.window, 'SimpleRecorder');
        if (ctor != null) {
          try {
            simpleRecorder = js_util.callConstructor(ctor, const []);
            final startPromise = js_util.callMethod(simpleRecorder, 'start', const []);
            if (startPromise != null && js_util.hasProperty(startPromise, 'then')) {
              await js_util.promiseToFuture(startPromise);
            }
            useSimpleRecorder = true;
            fallbackBlob = null;
            setState(() { isRecording = true; });
            appendTranscript('[info] Fallback recording started. Speak now...');
            return;
          } catch (e2) {
            appendTranscript('[error] Fallback recorder failed: $e2');
            return;
          }
        }
        return;
      }
      audioChunks = [];

      // Wire up events using allowInterop
      js_util.callMethod(mediaRecorder, 'addEventListener', [
        'dataavailable',
        js.allowInterop((event) {
          final data = js_util.getProperty(event, 'data');
          if (data != null) audioChunks.add(data);
        })
      ]);

      js_util.callMethod(mediaRecorder, 'addEventListener', [
        'stop',
        js.allowInterop((_) {
          convertSpeechToText();
        })
      ]);

      // Start recording
      js_util.callMethod(mediaRecorder, 'start', const []);
      setState(() { isRecording = true; });
      appendTranscript('[info] Recording started. Speak now...');
    } catch (e) {
      appendTranscript('[error] Exception starting recording: $e');
      print('Error starting recording: $e');
    }
  }
  
  // Function to stop recording
  void stopRecording() {
    if (useSimpleRecorder && simpleRecorder != null) {
      appendTranscript('[info] Stopping fallback recorder...');
      try {
        final stopPromise = js_util.callMethod(simpleRecorder, 'stop', const []);
        if (stopPromise != null && js_util.hasProperty(stopPromise, 'then')) {
          js_util.promiseToFuture(stopPromise).then((value) {
            fallbackBlob = value;
            setState(() { isRecording = false; });
            convertSpeechToText();
          });
        } else {
          // If no promise, attempt to read a blob property
          fallbackBlob = js_util.getProperty(simpleRecorder, 'blob');
          setState(() { isRecording = false; });
          convertSpeechToText();
        }
      } catch (e) {
        appendTranscript('[error] Failed to stop fallback recorder: $e');
        setState(() { isRecording = false; });
      }
      return;
    }
    if (mediaRecorder != null) {
      appendTranscript('[info] Stopping recording...');
      try {
        js_util.callMethod(mediaRecorder, 'stop', const []);
      } catch (_) {
        // Fallback to direct callMethod if needed
        mediaRecorder.callMethod('stop', []);
      }
      setState(() { isRecording = false; });
    }
  }
  
  // Function to send audio to STT API
  Future<void> convertSpeechToText() async {
    try {
      appendTranscript('[info] Converting speech to text...');
      setState(() { isTranscribing = true; });
      if (!useSimpleRecorder && audioChunks.isEmpty) {
        appendTranscript('[error] No audio captured. Please record again.');
        setState(() { isTranscribing = false; });
        return;
      }
      
      // Choose a Blob to upload: prefer fallback blob, else first recorded chunk
      dynamic blob = fallbackBlob;
      if (blob == null && audioChunks.isNotEmpty) {
        blob = audioChunks.first; // MediaRecorder provides Blob in event.data
      }
      if (blob == null) {
        appendTranscript('[error] No audio blob available to upload');
        setState(() { isTranscribing = false; });
        return;
      }
      
      // Create FormData
      // Build FormData using dart:html and append via JS interop (works for JS Blob types)
      final formData = html.FormData();
      // Pick filename extension to hint server-side decoder
      String fileName;
      if (useSimpleRecorder) {
        fileName = 'recording.wav';
      } else {
        // Try to infer if this is Safari/iOS (no webm), prefer m4a
        final ua = html.window.navigator.userAgent.toLowerCase();
        final isIOS = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
        final isSafari = ua.contains('safari') && !ua.contains('chrome');
        if (isIOS || isSafari) {
          fileName = 'recording.m4a';
        } else {
          fileName = 'recording.webm';
        }
      }
      js_util.callMethod(formData, 'append', ['file', blob, fileName]);
      
      // Create XMLHttpRequest to handle the upload
      final xhr = html.HttpRequest();
      xhr.open('POST', '$SERVER_BASE/api/stt');
      
      // Set up completion handler
      xhr.onLoad.listen((event) {
        if (xhr.status == 200) {
          final result = json.decode(xhr.responseText ?? '{}');
          final text = result['text'] as String?;
          
          if (text != null && text.isNotEmpty) {
            appendTranscript('[success] Speech recognized: $text');
            // Do NOT populate the TTS input field; auto-post only
            // Auto-post recognized text to the shared chat; no local playback by default
            try {
              final chat = Provider.of<ChatSessionProvider>(context, listen: false);
              if (!chat.isConnected && !chat.isConnecting) {
                chat.connectToChatRoom(null);
              }
              chat.sendMessage(text);
              // Optionally play outgoing audio locally if enabled
              final settings = Provider.of<SettingsProvider>(context, listen: false);
              if (settings.playOutgoingAudio) {
                try {
                  if (joined) {
                    js.context.callMethod('webrtcSendTTS', [text]);
                  } else {
                    // ignore: unawaited_futures
                    useDirectTTS(text);
                  }
                } catch (_) {}
              }
            } catch (e) {
              appendTranscript('[error] Failed to post STT text to room: $e');
            }
          } else {
            appendTranscript('[warning] No speech recognized');
          }
        } else {
          appendTranscript('[error] STT API error: ${xhr.status}');
          print('STT API error response: ${xhr.responseText}');
        }
        setState(() { isTranscribing = false; });
      });
      
      // Set up error handler
      xhr.onError.listen((event) {
        appendTranscript('[error] STT API network error');
        print('STT API network error: $event');
        setState(() { isTranscribing = false; });
      });
      
      // Send the request
      xhr.send(formData);
    } catch (e) {
      appendTranscript('[error] Exception converting speech to text: $e');
      print('Error with STT API: $e');
      setState(() { isTranscribing = false; });
    }
  }

  // React to new chat messages: play incoming messages on Speak-to-Type clients
  void _onChatUpdated() async {
    try {
      final chat = Provider.of<ChatSessionProvider>(context, listen: false);
      if (chat.messages.isEmpty) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      // Process only new messages since last check
      int start = _lastHandledChatIndex + 1;
      if (start < 0) start = 0;
      for (int i = start; i < chat.messages.length; i++) {
        final m = chat.messages[i];
        if (m.type != 'chat') {
          continue;
        }
        // Play only messages that arrived after this client connected
        if (chat.connectedAtMs > 0 && m.timestamp.millisecondsSinceEpoch < chat.connectedAtMs) {
          continue;
        }
        final isFromSelf = (m.clientId != null && m.clientId == chat.clientId);
        if (isFromSelf) {
          // Do not auto-play locally by default
          continue;
        }
        if (settings.playIncomingAudio) {
          // Prefer WebRTC path if joined; else fall back to direct API playback
          try {
            if (joined) {
              js.context.callMethod('webrtcSendTTS', [m.message]);
            } else {
              await useDirectTTS(m.message);
            }
            appendTranscript('[audio] Auto-playing incoming: ${m.sender ?? 'Guest'}');
          } catch (e) {
            appendTranscript('[error] Failed to auto-play incoming message: $e');
          }
        }
      }
      _lastHandledChatIndex = chat.messages.length - 1;
    } catch (_) {
      // ignore handler errors
    }
  }

  // (removed) _showPersonaCreationDialog — persona prompting handled in postFrame callback above
  
  // Settings dialog is now accessed via named route in the Drawer
  
  // Update audio settings based on user preferences
  void _updateAudioSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final playAudio = settingsProvider.playIncomingAudio;
    
    // Update JavaScript audio settings
    js.context.callMethod('eval', ['''
      window.playIncomingAudio = $playAudio;
      console.log("Audio playback settings updated: " + window.playIncomingAudio);
      if (window.dartAppendTranscript) {
        window.dartAppendTranscript("[settings] Play incoming audio set to: " + window.playIncomingAudio);
      }
    ''']);
  }

  @override
  void dispose() {
    // Remove listeners
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    settingsProvider.removeListener(_updateAudioSettings);
    try {
      final personaProvider = Provider.of<PersonaProvider>(context, listen: false);
      personaProvider.removeListener(_onPersonaChanged);
    } catch (_) {}
    // Remove chat listener
    try {
      final chat = Provider.of<ChatSessionProvider>(context, listen: false);
      chat.removeListener(_onChatUpdated);
    } catch (_) {}
    
    // Dispose controllers
    transcriptController.dispose();
    inputController.dispose();
    roomController.dispose();
    super.dispose();
  }

  void _onPersonaChanged() {
    try {
      final personaProvider = Provider.of<PersonaProvider>(context, listen: false);
      final chat = Provider.of<ChatSessionProvider>(context, listen: false);
      final name = personaProvider.selectedPersona?.name;
      if (name != null && name.isNotEmpty && chat.isConnected) {
        chat.setUserName(name);
      }
    } catch (_) {}
  }

  // --- Drawer actions ---
  Future<void> _openInviteDialog() async {
    try {
      final chat = Provider.of<ChatSessionProvider>(context, listen: false);
      // Ensure we have a server-backed sessionId
      if ((chat.sessionId == null || chat.sessionId!.isEmpty) && !chat.isConnecting) {
        await chat.connectToChatRoom(null);
      }

      // If still missing (server might be down), fall back to current URL param
      String? sessionId = chat.sessionId ?? _extractSessionId(html.window.location.href);
      if (sessionId == null || sessionId.isEmpty) {
        // Make one last attempt to connect/create
        await chat.connectToChatRoom(null);
        sessionId = chat.sessionId;
      }

      if (sessionId == null || sessionId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No session available to share yet. Try again in a moment.')),
        );
        return;
      }

      // Build canonical share URL and update address bar to match
      final base = html.window.location.href.split('?').first;
      final shareUrl = '$base?sessionId=$sessionId';
      if (_extractSessionId(html.window.location.href) != sessionId) {
        html.window.history.pushState(null, 'Chat Room $sessionId', shareUrl);
      }

      showDialog(
        context: context,
        builder: (_) => ShareDialog(sessionId: sessionId!, shareUrl: shareUrl),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Invite open failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open invite: $e')),
      );
    }
  }

  void _openPersonaDialog() {
    showDialog(
      context: context,
      builder: (_) => const PersonaActionsDialog(),
    );
  }

  void _openHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => const HelpDialog(),
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  void _toggleDiagnosticsTray() {
    setState(() {
      showDiagnosticPanel = !showDiagnosticPanel;
    });
  }

  // (removed) _buildShareUrl — share link is computed in _openInviteDialog

  // (removed) _ensureSessionIdInUrl — avoid generating client-only IDs; use server-issued sessionId

  String? _extractSessionId(String url) {
    try {
      final uri = Uri.parse(url);
      final id = uri.queryParameters['sessionId'];
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  // --- UI Helpers ---
  Widget _buildTranscriptView() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black87,
      child: ListView.builder(
        controller: transcriptController,
        itemCount: transcriptLines.length,
        itemBuilder: (context, index) {
          final line = transcriptLines[index];
          Color color = Colors.white;
          if (line.contains('[system]')) color = Colors.cyan;
          else if (line.contains('[error]')) color = Colors.redAccent;
          else if (line.contains('(You)')) color = Colors.lightGreenAccent;
          else if (line.contains('[AI]')) color = Colors.lightBlueAccent;
          else if (line.contains('[info]')) color = Colors.grey;
          else if (line.contains('[debug]')) color = Colors.yellow;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(line, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12)),
          );
        },
      ),
    );
  }

  Widget _buildDiagnosticLogView() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black87,
      child: ListView.builder(
        controller: diagnosticController,
        itemCount: diagnosticLogs.length,
        itemBuilder: (context, index) {
          final log = diagnosticLogs[index];
          Color textColor = Colors.grey[400]!;
          if (log.contains("[Test]")) textColor = Colors.yellow;
          else if (log.contains("[error]")) textColor = Colors.redAccent;
          else if (log.contains("[audio]")) textColor = Colors.cyanAccent;
          else if (log.contains("[system]") || log.contains("[System]")) textColor = Colors.greenAccent;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(log, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: textColor)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My App'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: AppMenuDrawer(
        onInvite: _openInviteDialog,
        onPersona: _openPersonaDialog,
        onHelp: _openHelpDialog,
        onSettings: _openSettingsDialog,
        onDiagnostics: _toggleDiagnosticsTray,
      ),
      body: Column(
        children: [
          // Room info/status bar
          Consumer<ChatSessionProvider>(
            builder: (context, chat, _) {
              final sid = chat.sessionId ?? _extractSessionId(html.window.location.href) ?? '—';
              final cnt = chat.activeParticipants;
              return Container(
                width: double.infinity,
                color: Colors.blueGrey.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('Room: $sid', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.group, size: 14, color: Colors.blueGrey[600]),
                    const SizedBox(width: 4),
                    Text('${cnt} online', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conversation', style: Theme.of(context).textTheme.headlineSmall),
                        const Divider(height: 20),
                        // Debug room message input removed
                        // Show WS room messages (shared across invitees)
                        Expanded(
                          child: Consumer<ChatSessionProvider>(
                            builder: (context, chat, _) => ListView.builder(
                              itemCount: chat.messages.length,
                              itemBuilder: (context, index) {
                                final m = chat.messages[index];
                                final isSystem = m.type == 'system';
                                final text = isSystem ? '[system] ${m.message}' : '${m.sender ?? 'Guest'}: ${m.message}';
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3)],
                                  ),
                                  child: Text(text, style: const TextStyle(fontSize: 16)),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: inputController,
                                  decoration: const InputDecoration.collapsed(hintText: 'Type a message to send as TTS...'),
                                  onSubmitted: (_) => sendTypedAsTTS(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send, color: Colors.blue),
                                onPressed: sendTypedAsTTS,
                                tooltip: 'Share to room',
                              ),
                              IconButton(
                                icon: Icon(isRecording ? Icons.stop_circle : Icons.mic),
                                onPressed: isRecording ? stopRecording : startRecording,
                                tooltip: isRecording ? 'Stop Recording' : 'Start STT Recording',
                                color: isRecording ? Colors.red : Colors.blue,
                                iconSize: 28,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDiagnosticPanel)
            Container(
              height: 350,
              color: Colors.blueGrey[800],
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      color: Colors.blueGrey[900],
                      child: Row(
                        children: [
                          const Expanded(
                            child: TabBar(
                              tabs: [
                                Tab(icon: Icon(Icons.bug_report), text: "Logs"),
                                Tab(icon: Icon(Icons.article), text: "Transcript"),
                              ],
                              indicatorColor: Colors.lightBlueAccent,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: copyDiagnosticLogs,
                                  tooltip: 'Copy Logs',
                                  color: Colors.white,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep, size: 20),
                                  onPressed: clearDiagnosticLogs,
                                  tooltip: 'Clear Logs & Transcript',
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildDiagnosticLogView(),
                          _buildTranscriptView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
