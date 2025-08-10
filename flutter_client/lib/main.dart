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
  
  // Audio recording variables for STT
  dynamic mediaRecorder;
  List<dynamic> audioChunks = [];
  bool isRecording = false;

  bool joined = false;
  bool micOn = false;

  @override
  void initState() {
    super.initState();
    
    // Set up JavaScript functions to call back into Flutter
    js.context['dartAppendTranscript'] = (String text) {
      appendTranscript(text);
    };
    
    // Add callback for when connection is fully established
    js.context['dartConnectionEstablished'] = () {
      setState(() { 
        joined = true; 
      });
      appendTranscript('[system] Connection fully established and ready to use');
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
                    window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
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
                        const context = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
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
      async function joinRTCSession() {
        try {
          // Reset connection state
          connectionEstablished = false;
          
          // Initialize audio context early
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
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
          
          // Return true now but don't set connectionEstablished yet
          // That will happen when the data channel opens
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
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
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
              window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
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
        
          // Format the TTS request according to OpenAI Realtime API docs
          // For TTS to work properly in WebRTC sessions, we use a standard message with
          // the text we want to convert to speech, but without any TTS-specific parameters
          const ttsReq = {
            type: 'conversation.item.create',
            item: {
              type: 'message',
              role: 'user',
              content: [
                {
                  type: 'input_text',
                  text: text
                }
              ]
              // No voice parameter - let the server use default (alloy)
            }
          };
          
          // Debug the request
          console.log("Sending TTS request:", JSON.stringify(ttsReq));
          
          // Log the request for debugging
          console.log("Sending TTS request:", JSON.stringify(ttsReq));
          
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
    
    appendChat('${nameController.text}: $text');
    inputController.clear();

    if (!joined) {
      appendChat('TTS failed: Not connected');
      appendTranscript('[error] Cannot send TTS - not connected to session');
      return;
    }

    // Log attempt in the console
    print('Attempting to send TTS: $text');
    
    // Also add to transcript as the user utterance
    appendTranscript('(You) $text');
    
    try {
      // Call the JavaScript function
      final success = js.context.callMethod('webrtcSendTTS', [text]);
      print('TTS send result: $success');
      
      if (success != true) {
        appendChat('TTS failed: Error sending request');
        appendTranscript('[error] Failed to send TTS request');
      }
    } catch (e) {
      print('Error sending TTS: $e');
      appendTranscript('[error] Exception sending TTS: $e');
      appendChat('TTS failed: Technical error');
    }
  }
  
  // Function to use our new API endpoint for text-to-speech
  Future<void> useDirectTTS(String text) async {
    try {
      appendTranscript('[info] Using direct TTS API: $text');
      
      // Make HTTP request to our TTS endpoint
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/tts'),
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
  void startRecording() {
    try {
      appendTranscript('[info] Starting audio recording for STT...');
      
      final constraints = js.JsObject.jsify({
        'audio': true,
        'video': false
      });
      
      js.context['navigator']['mediaDevices'].callMethod('getUserMedia', [constraints])
        .then((stream) {
          mediaRecorder = js.context['MediaRecorder'].construct(stream);
          audioChunks = [];
          
          js.context.callMethod('eval', ['''
            (function(recorder) {
              recorder.addEventListener('dataavailable', function(event) {
                window.dartAudioChunkAvailable(event.data);
              });
              
              recorder.addEventListener('stop', function() {
                window.dartRecordingComplete();
              });
            })(arguments[0]);
          '''])(mediaRecorder);
          
          // Set up callbacks from JavaScript to Dart
          js.context['dartAudioChunkAvailable'] = (dynamic chunk) {
            audioChunks.add(chunk);
          };
          
          js.context['dartRecordingComplete'] = () {
            convertSpeechToText();
          };
          
          mediaRecorder.callMethod('start', []);
          setState(() {
            isRecording = true;
          });
          
          appendTranscript('[info] Recording started. Speak now...');
        })
        .catchError((error) {
          appendTranscript('[error] Failed to start recording: $error');
          print('Error accessing microphone: $error');
        });
    } catch (e) {
      appendTranscript('[error] Exception starting recording: $e');
      print('Error starting recording: $e');
    }
  }
  
  // Function to stop recording
  void stopRecording() {
    if (mediaRecorder != null) {
      appendTranscript('[info] Stopping recording...');
      mediaRecorder.callMethod('stop', []);
      setState(() {
        isRecording = false;
      });
    }
  }
  
  // Function to send audio to STT API
  Future<void> convertSpeechToText() async {
    try {
      appendTranscript('[info] Converting speech to text...');
      
      // Create a Blob from audio chunks
      final options = js.JsObject.jsify({'type': 'audio/webm'});
      final blob = js.context['Blob'].construct(js.JsArray.from(audioChunks), options);
      
      // Create FormData
      final formData = js.context['FormData'].construct();
      formData.callMethod('append', ['audio', blob, 'recording.webm']);
      
      // Create XMLHttpRequest to handle the upload
      final xhr = html.HttpRequest();
      xhr.open('POST', 'http://localhost:3000/api/stt');
      
      // Set up completion handler
      xhr.onLoad.listen((event) {
        if (xhr.status == 200) {
          final result = json.decode(xhr.responseText ?? '{}');
          final text = result['text'] as String?;
          
          if (text != null && text.isNotEmpty) {
            appendTranscript('[success] Speech recognized: $text');
            inputController.text = text;
          } else {
            appendTranscript('[warning] No speech recognized');
          }
        } else {
          appendTranscript('[error] STT API error: ${xhr.status}');
          print('STT API error response: ${xhr.responseText}');
        }
      });
      
      // Set up error handler
      xhr.onError.listen((event) {
        appendTranscript('[error] STT API network error');
        print('STT API network error: $event');
      });
      
      // Send the request
      xhr.send(formData);
    } catch (e) {
      appendTranscript('[error] Exception converting speech to text: $e');
      print('Error with STT API: $e');
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Text-to-Speech Input',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: inputController,
                                      decoration: const InputDecoration(
                                        labelText: 'Type message for AI to speak',
                                        border: OutlineInputBorder(),
                                        hintText: 'Enter text to be spoken by AI',
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      onSubmitted: (_) => sendTypedAsTTS(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up),
                                    onPressed: sendTypedAsTTS,
                                    tooltip: 'Send as TTS via WebRTC',
                                    color: Colors.blue[700],
                                    iconSize: 30,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.record_voice_over),
                                    onPressed: () {
                                      final text = inputController.text.trim();
                                      if (text.isNotEmpty) {
                                        useDirectTTS(text);
                                      }
                                    },
                                    tooltip: 'Direct TTS API',
                                    color: Colors.green[700],
                                    iconSize: 30,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                                    onPressed: isRecording ? stopRecording : startRecording,
                                    tooltip: isRecording ? 'Stop Recording' : 'Start Speech-to-Text',
                                    color: isRecording ? Colors.red : Colors.blue[700],
                                    iconSize: 30,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
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
        ],
      ),
    );
  }
}
