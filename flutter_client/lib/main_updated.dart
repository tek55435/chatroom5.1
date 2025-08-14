// flutter_client/lib/main_updated.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF0F8FF),
        fontFamily: 'Segoe UI, Tahoma, Geneva, Verdana, sans-serif',
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
  // WebRTC connection objects
  dynamic pc;
  dynamic dataChannel;
  
  // Controllers
  final ScrollController messageController = ScrollController();
  final TextEditingController messageInputController = TextEditingController();
  final TextEditingController roomController = TextEditingController(text: 'main');
  final TextEditingController nameController = TextEditingController(text: 'Guest');
  
  // State variables
  final List<ChatMessage> messages = [];
  bool isRecording = false;
  bool showInstructions = true;
  bool showSettings = false;
  bool joined = false;
  bool micOn = false;
  
  // Audio recording variables for STT
  dynamic mediaRecorder;
  dynamic simpleRecorder;
  bool useSimpleRecorder = false;
  dynamic fallbackBlob;
  List<dynamic> audioChunks = [];
  bool isTranscribing = false;
  bool showShareOptions = false;
  bool showBugReport = false;
  bool showEmojiPicker = false;
  bool isDarkMode = false;
  String userName = 'Frank';
  String selectedVoice = 'Jasper';
  
  // Audio recording variables for STT
  dynamic mediaRecorder;
  dynamic simpleRecorder;
  bool useSimpleRecorder = false;
  dynamic fallbackBlob;

  // Diagnostic panel
  final List<String> diagnosticLogs = [];
  final ScrollController diagnosticController = ScrollController(); 
  bool showDiagnosticPanel = false;
  
  @override
  void initState() {
    super.initState();
    
    // Show welcome instructions on first launch
    Future.delayed(Duration.zero, () {
      setState(() {
        showInstructions = true;
      });
    });
    
    // Register Flutter -> JS callbacks
    js.context['dartAppendMessage'] = (String text) {
      appendMessage(text, isUser: false);
    };
    
    js.context['dartAppendDiagnostic'] = (String text) {
      appendDiagnostic(text);
    };
    
    // Add callback for connection established
    js.context['dartConnectionEstablished'] = () {
      setState(() { 
        joined = true; 
      });
      appendMessage("Connection established", isUser: false);
      appendDiagnostic("[system] Connection fully established and ready to use");
      
      // Initialize audio context
      js.context.callMethod('eval', ['''
        if (!window.audioContext) {
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
            window.audioQueue = [];
            window.isPlayingAudio = false;
            console.log("Audio context explicitly initialized after connection");
            dartAppendDiagnostic("[audio] Audio system explicitly initialized");
          } catch (err) {
            console.error("Failed to initialize audio context:", err);
            dartAppendDiagnostic("[error] Failed to initialize audio: " + err.message);
          }
        } else if (window.audioContext.state !== "running") {
          window.audioContext.resume().then(() => {
            console.log("Audio context explicitly resumed after connection");
            dartAppendDiagnostic("[audio] Audio system resumed");
          });
        }
      ''']);
    };
    
    // Make server base URL available to JS
    js.context['SERVER_BASE'] = SERVER_BASE;
    
    // Add PCM helper script
    final pcmHelperScript = html.ScriptElement()
      ..type = 'text/javascript'
      ..src = 'pcm_helper.js';
    html.document.head?.append(pcmHelperScript);
    
    // Add WebRTC initialization script
    _injectWebRTCScript();
    
    // Inject the simple recorder if needed
    _ensureSimpleRecorderInjected();
  }
  
  void _injectWebRTCScript() {
    final scriptEl = html.ScriptElement();
    scriptEl.text = r'''
      // Global WebRTC objects
      let peerConnection = null;
      let dataChannel = null;
      let localStream = null;
      
      // Append to transcript helper
      function appendToTranscript(text) {
        if (window.dartAppendMessage) {
          window.dartAppendMessage(text);
        } else {
          console.log("Message: " + text);
        }
      }
      
      // Initialize WebRTC
      async function initWebRTC() {
        try {
          peerConnection = new RTCPeerConnection({
            iceServers: []
          });
          
          // Handle remote tracks
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
            console.log("Data channel opened");
            appendToTranscript("Data channel opened");
            if (window.dartConnectionEstablished) {
              window.dartConnectionEstablished();
            }
          };
          
          dataChannel.onclose = () => {
            console.log("Data channel closed");
            appendToTranscript("Data channel closed");
          };
          
          dataChannel.onmessage = (event) => {
            console.log("Data channel message:", event.data);
            try {
              const msg = JSON.parse(event.data);
              if (msg.type === 'transcription') {
                appendToTranscript("Remote: " + msg.text);
              } else if (msg.type === 'audio') {
                // Queue audio for playback
                if (!window.audioQueue) window.audioQueue = [];
                window.audioQueue.push(msg.data);
                playNextAudio();
              }
            } catch (e) {
              console.error("Error handling message:", e);
            }
          };
          
          // Set up ICE handling
          peerConnection.onicecandidate = (event) => {
            if (event.candidate) {
              console.log("New ICE candidate:", event.candidate);
            }
          };
          
          peerConnection.oniceconnectionstatechange = () => {
            console.log("ICE connection state:", peerConnection.iceConnectionState);
            appendToTranscript("ICE state: " + peerConnection.iceConnectionState);
          };
          
          // Create and send offer
          const offer = await peerConnection.createOffer();
          await peerConnection.setLocalDescription(offer);
          
          // Send offer to signaling server
          const response = await fetch(window.SERVER_BASE + '/webrtc/offer', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
              sdp: offer.sdp,
              type: offer.type
            })
          });
          
          const answerData = await response.json();
          const remoteDesc = new RTCSessionDescription(answerData);
          await peerConnection.setRemoteDescription(remoteDesc);
          
          console.log("WebRTC connection initialized");
          appendToTranscript("WebRTC initialized");
          
        } catch (err) {
          console.error("WebRTC initialization error:", err);
          appendToTranscript("Error: " + err.message);
        }
      }
      
      // Audio playback function
      async function playNextAudio() {
        if (!window.audioContext) {
          try {
            window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
          } catch (err) {
            console.error("Failed to create audio context:", err);
            return;
          }
        }
        
        if (window.isPlayingAudio || !window.audioQueue || window.audioQueue.length === 0) {
          return;
        }
        
        window.isPlayingAudio = true;
        const audioData = window.audioQueue.shift();
        
        try {
          const audioBuffer = await window.audioContext.decodeAudioData(audioData.buffer);
          const source = window.audioContext.createBufferSource();
          source.buffer = audioBuffer;
          source.connect(window.audioContext.destination);
          source.onended = () => {
            window.isPlayingAudio = false;
            playNextAudio();
          };
          source.start(0);
        } catch (err) {
          console.error("Audio playback error:", err);
          window.isPlayingAudio = false;
          playNextAudio();
        }
      }
    ''';
    html.document.head?.append(scriptEl);
  }

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
    this.bufferR = [];
    this.length = 0;
    this.blob = null;
  }
  SimpleRecorder.prototype.start = async function(){
    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    this.mediaStream = await navigator.mediaDevices.getUserMedia({audio:true});
    const source = this.audioContext.createMediaStreamSource(this.mediaStream);
    const bufferSize = 4096;
    const channels = 1; // mono for clearer STT
    this.processor = this.audioContext.createScriptProcessor(bufferSize, channels, channels);
    this.bufferL = [];
    this.bufferR = [];
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

  void sendMessage() {
    final text = messageInputController.text.trim();
    if (text.isEmpty) return;
    
    appendMessage(text, isUser: true);
    messageInputController.clear();
    
    // Send message through WebRTC data channel
    if (dataChannel != null) {
      final msg = {
        'type': 'chat',
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      };
      js_util.callMethod(dataChannel, 'send', [js.context.callMethod('JSON.stringify', [msg])]);
    }
    
    appendDiagnostic("[system] Message sent: $text");
  }
  
  void startVoiceRecording() async {
    if (isRecording) return;
    
    appendDiagnostic('[info] Starting audio recording for STT...');
    try {
      // Environment diagnostics
      final isSecure = js_util.getProperty(html.window, 'isSecureContext') == true;
      appendDiagnostic('[diag] isSecureContext=$isSecure');
      appendDiagnostic('[diag] navigator present=true');

      // Try to get MediaStream using dart:html
      html.MediaStream? htmlStream;
      try {
        htmlStream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      } catch (e) {
        appendDiagnostic('[warn] getUserMedia via dart:html failed: $e; attempting JS fallback');
      }

      dynamic stream = htmlStream;
      
      // JS fallback if dart:html attempt failed
      if (stream == null) {
        final nav = js_util.getProperty(html.window, 'navigator');
        final mediaDevices = js_util.getProperty(nav, 'mediaDevices');
        final jsStream = await js_util.promiseToFuture(
            js_util.callMethod(mediaDevices, 'getUserMedia', [
          js_util.jsify({'audio': true})
        ]));
        stream = jsStream;
      }

      if (stream == null) {
        throw Exception('Could not get audio stream');
      }

      // Create MediaRecorder
      final recorder = js_util.getProperty(html.window, 'MediaRecorder');
      final options = js_util.jsify({'mimeType': 'audio/webm'});
      mediaRecorder = js_util.callConstructor(recorder, [stream, options]);

      // Set up event handlers
      audioChunks = [];
      
      js_util.setProperty(mediaRecorder, 'ondataavailable',
          js.allowInterop((dynamic e) {
        audioChunks.add(e.data);
      }));

      js_util.setProperty(mediaRecorder, 'onstop', js.allowInterop((_) {
        // Convert audio to text when recording stops
        convertSpeechToText();
      }));

      // Start recording
      js_util.callMethod(mediaRecorder, 'start', const []);
      setState(() { isRecording = true; });
      appendDiagnostic('[info] Recording started. Speak now...');
    } catch (e) {
      appendDiagnostic('[error] Exception starting recording: $e');
      print('Error starting recording: $e');
      
      // Try fallback recorder
      if (!useSimpleRecorder) {
        useSimpleRecorder = true;
        appendDiagnostic('[info] Switching to fallback recorder...');
        _ensureSimpleRecorderInjected();
        startVoiceRecording();
        return;
      }
      
      try {
        simpleRecorder = js_util.callConstructor(
            js_util.getProperty(html.window, 'SimpleRecorder'), []);
        final startPromise = js_util.callMethod(simpleRecorder, 'start', const []);
        if (startPromise != null && js_util.hasProperty(startPromise, 'then')) {
          js_util.callMethod(startPromise, 'then',
              [js.allowInterop((_) => appendDiagnostic('[info] Fallback recording started'))]);
        }
        setState(() { isRecording = true; });
      } catch (e2) {
        appendDiagnostic('[error] Fallback recorder also failed: $e2');
      }
    }
  }
  
  void stopVoiceRecording() {
    if (!isRecording) return;
    
    setState(() { isRecording = false; });
    
    if (useSimpleRecorder && simpleRecorder != null) {
      appendDiagnostic('[info] Stopping fallback recorder...');
      try {
        final stopPromise = js_util.callMethod(simpleRecorder, 'stop', const []);
        if (stopPromise != null && js_util.hasProperty(stopPromise, 'then')) {
          js_util.callMethod(
              stopPromise,
              'then',
              [
                js.allowInterop((dynamic blob) {
                  fallbackBlob = blob;
                  convertSpeechToText();
                })
              ]);
        }
      } catch (e) {
        appendDiagnostic('[error] Error stopping fallback recorder: $e');
      }
    } else if (mediaRecorder != null) {
      appendDiagnostic('[info] Stopping MediaRecorder...');
      try {
        js_util.callMethod(mediaRecorder, 'stop', const []);
      } catch (e) {
        appendDiagnostic('[error] Error stopping MediaRecorder: $e');
      }
    }
  }
  
  void convertSpeechToText() async {
    if (isTranscribing) {
      appendDiagnostic('[warn] Already transcribing, please wait...');
      return;
    }
    
    setState(() { isTranscribing = true; });
    appendDiagnostic('[info] Converting speech to text...');
    
    try {
      final formData = js_util.callConstructor(
          js_util.getProperty(html.window, 'FormData'), []);
          
      if (useSimpleRecorder && fallbackBlob != null) {
        js_util.callMethod(formData, 'append', ['audio', fallbackBlob]);
      } else {
        final blobCtor = js_util.getProperty(html.window, 'Blob');
        final blobOptions = js_util.jsify({'type': 'audio/webm'});
        final blob = js_util.callConstructor(blobCtor, [js_util.jsify(audioChunks), blobOptions]);
        js_util.callMethod(formData, 'append', ['audio', blob]);
      }

      // Send to server
      final resp = await html.HttpRequest.request(
        '$SERVER_BASE/stt',
        method: 'POST',
        sendData: formData,
      );
      
      final result = js.context.callMethod('JSON.parse', [resp.responseText]);
      final text = js_util.getProperty(result, 'text') as String;
      
      if (text.trim().isNotEmpty) {
        // Send text through data channel
        if (dataChannel != null) {
          final msg = {
            'type': 'chat',
            'text': text,
            'timestamp': DateTime.now().toIso8601String(),
          };
          js_util.callMethod(dataChannel, 'send', [js.context.callMethod('JSON.stringify', [msg])]);
        }
        
        appendMessage(text, isUser: true);
        appendDiagnostic('[info] Speech converted to text: $text');
      } else {
        appendDiagnostic('[warn] No speech detected');
      }
    } catch (e) {
      appendDiagnostic('[error] Speech-to-text error: $e');
    } finally {
      setState(() { isTranscribing = false; });
      audioChunks.clear();
      fallbackBlob = null;
    }
  }

  void testAudioInitialization() {
    appendDiagnostic("[Test] Testing audio initialization...");
    js.context.callMethod('eval', ['''
      try {
        if (!window.audioContext) {
          window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
          window.audioQueue = [];
          window.isPlayingAudio = false;
          dartAppendDiagnostic("[Test] Created new AudioContext: " + window.audioContext.state);
        } else {
          dartAppendDiagnostic("[Test] AudioContext already exists: " + window.audioContext.state);
          if (window.audioContext.state !== "running") {
            window.audioContext.resume().then(() => {
              dartAppendDiagnostic("[Test] AudioContext resumed: " + window.audioContext.state);
            }).catch(err => {
              dartAppendDiagnostic("[Test] Failed to resume AudioContext: " + err.message);
            });
          }
        }
        
        // Test creating an audio node
        const testNode = window.audioContext.createGain();
        dartAppendDiagnostic("[Test] Successfully created audio node");
        
        // Additional state info
        dartAppendDiagnostic("[Test] Audio queue length: " + (window.audioQueue ? window.audioQueue.length : "undefined"));
        dartAppendDiagnostic("[Test] isPlayingAudio: " + (window.isPlayingAudio ? "true" : "false"));
      } catch (err) {
        dartAppendDiagnostic("[Test] Audio initialization error: " + err.message);
        console.error("Audio test error:", err);
      }
    ''']);
  }
  
  void testWebRTCConnection() {
    appendDiagnostic("[Test] Testing WebRTC connection...");
    js.context.callMethod('eval', ['''
      try {
        if (!window.peerConnection) {
          dartAppendDiagnostic("[Test] No WebRTC connection exists");
          return;
        }
        
        dartAppendDiagnostic("[Test] WebRTC connection state: " + window.peerConnection.connectionState);
        dartAppendDiagnostic("[Test] ICE connection state: " + window.peerConnection.iceConnectionState);
        dartAppendDiagnostic("[Test] Signaling state: " + window.peerConnection.signalingState);
        
        if (window.dataChannel) {
          dartAppendDiagnostic("[Test] Data channel state: " + window.dataChannel.readyState);
          
          // Test sending a message through data channel
          if (window.dataChannel.readyState === "open") {
            try {
              const testMsg = {type: "test_message", timestamp: new Date().toISOString()};
              window.dataChannel.send(JSON.stringify(testMsg));
              dartAppendDiagnostic("[Test] Test message sent through data channel");
            } catch (err) {
              dartAppendDiagnostic("[Test] Failed to send test message: " + err.message);
            }
          } else {
            dartAppendDiagnostic("[Test] Data channel not open, state: " + window.dataChannel.readyState);
          }
        } else {
          dartAppendDiagnostic("[Test] No data channel exists");
        }
        
        // Test media capabilities
        if (navigator.mediaDevices) {
          dartAppendDiagnostic("[Test] MediaDevices API available");
          navigator.mediaDevices.enumerateDevices().then(devices => {
            const audioInputs = devices.filter(d => d.kind === 'audioinput');
            dartAppendDiagnostic("[Test] Found " + audioInputs.length + " audio input devices");
          }).catch(err => {
            dartAppendDiagnostic("[Test] Failed to enumerate devices: " + err.message);
          });
        } else {
          dartAppendDiagnostic("[Test] MediaDevices API not available");
        }
      } catch (err) {
        dartAppendDiagnostic("[Test] WebRTC test error: " + err.message);
        console.error("WebRTC test error:", err);
      }
    ''']);
  }
  
  void testTTSSystem() {
    appendDiagnostic("[Test] Testing TTS system...");
    final testText = "This is a test of the text-to-speech system.";
    
    try {
      if (dataChannel != null) {
        final msg = {
          'type': 'tts_test',
          'text': testText,
          'timestamp': DateTime.now().toIso8601String(),
        };
        js_util.callMethod(dataChannel, 'send', [js.context.callMethod('JSON.stringify', [msg])]);
        appendDiagnostic("[Test] TTS test message sent");
      } else {
        appendDiagnostic("[Test] Cannot test TTS: No data channel available");
      }
    } catch (e) {
      appendDiagnostic("[Test] TTS test error: $e");
    }
  }
  
  void toggleInstructions() {
    setState(() {
      showInstructions = !showInstructions;
    });
  }
  
  void toggleSettings() {
    setState(() {
      showSettings = !showSettings;
      showShareOptions = false;
      showBugReport = false;
    });
  }
  
  void toggleShareOptions() {
    setState(() {
      showShareOptions = !showShareOptions;
      showSettings = false;
      showBugReport = false;
    });
  }
  
  void toggleBugReport() {
    setState(() {
      showBugReport = !showBugReport;
      showSettings = false;
      showShareOptions = false;
    });
  }
  
  void toggleDiagnosticPanel() {
    setState(() {
      showDiagnosticPanel = !showDiagnosticPanel;
    });
  }
  
  void toggleDarkMode() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }
  
  void selectVoice(String voice) {
    setState(() {
      selectedVoice = voice;
    });
  }
  
  void appendMessage(String text, {required bool isUser}) {
    setState(() {
      messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
    
    // Scroll to bottom after a brief delay to allow rendering
    Future.delayed(const Duration(milliseconds: 50), () {
      if (messageController.hasClients) {
        messageController.animateTo(
          messageController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void appendDiagnostic(String text) {
    setState(() {
      diagnosticLogs.add(text);
    });
    
    // Scroll diagnostic logs
    Future.delayed(const Duration(milliseconds: 50), () {
      if (diagnosticController.hasClients) {
        diagnosticController.animateTo(
          diagnosticController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void clearDiagnosticLogs() {
    setState(() {
      diagnosticLogs.clear();
    });
    appendDiagnostic("[system] Logs cleared");
  }
  
  void copyDiagnosticLogs() {
    final text = diagnosticLogs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    appendDiagnostic("[system] Logs copied to clipboard");
  }

  @override
  void dispose() {
    messageController.dispose();
    messageInputController.dispose();
    diagnosticController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF0F8FF),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Main chat area
            Expanded(
              child: _buildChatArea(),
            ),
            
            // Footer - message input
            _buildFooter(),
            
            // Diagnostic panel (if enabled)
            if (showDiagnosticPanel)
              _buildDiagnosticPanel(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Icon(
                Icons.cloud,
                color: Colors.lightBlue,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                'HearAll',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Welcome message
          Text(
            'Welcome, $userName',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(width: 16),
          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: toggleInstructions,
            tooltip: 'Help',
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: toggleShareOptions,
            tooltip: 'Share',
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: toggleSettings,
            tooltip: 'Settings',
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatArea() {
    return Stack(
      children: [
        // Messages
        ListView.builder(
          controller: messageController,
          padding: const EdgeInsets.all(16.0),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageBubble(message);
          },
        ),
        
        // Modal overlays
        if (showInstructions) _buildInstructionsModal(),
        if (showSettings) _buildSettingsModal(),
        if (showShareOptions) _buildShareModal(),
        if (showBugReport) _buildBugReportModal(),
        if (showEmojiPicker) _buildEmojiPicker(),
      ],
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: message.isUser 
              ? Colors.blue 
              : isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(18.0).copyWith(
            bottomRight: message.isUser ? const Radius.circular(4.0) : null,
            bottomLeft: !message.isUser ? const Radius.circular(4.0) : null,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
          border: !message.isUser && !isDarkMode
              ? Border.all(color: Colors.grey.shade200)
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser 
                ? Colors.white 
                : isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
  
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: isRecording ? _buildRecordingControls() : _buildMessageInput(),
    );
  }
  
  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: messageInputController,
            decoration: InputDecoration(
              hintText: 'Type a message or press and hold to talk...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey : Colors.grey.shade600,
              ),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onSubmitted: (_) => sendMessage(),
          ),
        ),
        const SizedBox(width: 8.0),
        // Microphone button
        Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.mic),
            onPressed: startVoiceRecording,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8.0),
        // Send button
        Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.send),
            onPressed: sendMessage,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecordingControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.blue.withOpacity(0.2) 
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Recording...',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16.0),
                // Audio visualization
                Row(
                  children: List.generate(
                    5,
                    (index) => Container(
                      width: 4.0,
                      height: 16.0 + (index * 2.0),
                      margin: const EdgeInsets.symmetric(horizontal: 2.0),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        // Stop recording button
        Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.stop),
            onPressed: stopVoiceRecording,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInstructionsModal() {
    return _buildModalOverlay(
      child: Container(
        width: 400.0,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome to HearAll!',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: toggleInstructions,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              "Here's a quick guide to get you started.",
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Type to Speak Mode
            _buildInstructionSection(
              title: 'Type to Speak Mode',
              content: 'Choose this if you prefer to type. Your messages will be read aloud but by default, you won\'t hear incoming audio.',
            ),
            const SizedBox(height: 12.0),
            
            // Speak to Type Mode
            _buildInstructionSection(
              title: 'Speak to Type Mode',
              content: 'Choose this if you prefer to talk. Your voice will be turned into text. You\'ll automatically hear messages from "Type to Speak" users.',
            ),
            const SizedBox(height: 12.0),
            
            // Pro Tip for Better Audio
            _buildInstructionSection(
              title: 'Pro Tip for Better Audio',
              icon: Icons.headset,
              content: 'For the best voice-to-text results, we recommend using a headset. If you\'re using your phone\'s built-in mic, make sure your phone is in speakerphone mode to help it pick up your voice clearly.',
            ),
            const SizedBox(height: 12.0),
            
            // Inviting Friends
            _buildInstructionSection(
              title: 'Inviting Friends',
              icon: Icons.people,
              content: 'To invite others to your current chat, click the Share icon in the header. You can share the link via text, email, or by letting them scan the QR code.',
            ),
            const SizedBox(height: 20.0),
            
            // Beta notice
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    'App in Beta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Please help us improve by submitting bug reports or feedback.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: Checkbox(
                        value: false,
                        onChanged: (value) {},
                        activeColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      "Don't show this again",
                      style: TextStyle(
                        fontSize: 12.0,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: toggleBugReport,
                      child: Text(
                        'Report a Bug',
                        style: TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: toggleInstructions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Got it!'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInstructionSection({
    required String title,
    required String content,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16.0,
                color: Colors.blue,
              ),
              const SizedBox(width: 8.0),
            ],
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          content,
          style: TextStyle(
            fontSize: 13.0,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsModal() {
    return _buildModalOverlay(
      child: Container(
        width: 350.0,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings & Persona',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: toggleSettings,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Your Persona section
            _buildSettingsSection(
              title: 'Your Persona',
              icon: Icons.person,
              child: Column(
                children: [
                  // Avatar and name
                  Column(
                    children: [
                      Container(
                        width: 60.0,
                        height: 60.0,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 36.0,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Create or Update Persona',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        'Editing persona: $userName',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  
                  // Name field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      TextField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                        ),
                        controller: TextEditingController(text: userName),
                        onChanged: (value) {
                          setState(() {
                            userName = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  
                  // Voice selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Selection',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8.0,
                        crossAxisSpacing: 8.0,
                        childAspectRatio: 3.0,
                        children: [
                          _buildVoiceOption('Orion'),
                          _buildVoiceOption('Aurora'),
                          _buildVoiceOption('Jasper'),
                          _buildVoiceOption('Willow'),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {},
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Show More'),
                              Icon(Icons.keyboard_arrow_down, size: 16.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 16.0),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            
            // App Settings section
            _buildSettingsSection(
              title: 'App Settings',
              icon: Icons.settings,
              child: _buildToggleOption(
                title: 'Dark Mode',
                value: isDarkMode,
                onChanged: (value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Interaction Mode section
            _buildSettingsSection(
              title: 'Interaction Mode',
              icon: Icons.volume_up,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInteractionModeOption('Speaker', isSelected: true),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildInteractionModeOption('Conversation'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  _buildToggleOption(
                    title: 'Enable Single-Device Audio',
                    value: false,
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 8.0),
                  _buildToggleOption(
                    title: 'Play Incoming Audio',
                    value: true,
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Invite Friends section
            _buildSettingsSection(
              title: 'Invite Friends',
              icon: Icons.people,
              child: ElevatedButton.icon(
                onPressed: () {
                  toggleSettings();
                  toggleShareOptions();
                },
                icon: const Icon(Icons.share),
                label: const Text('Share Invitation Link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVoiceOption(String voice) {
    final isSelected = selectedVoice == voice;
    
    return InkWell(
      onTap: () => selectVoice(voice),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : null,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          voice,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }
  
  Widget _buildInteractionModeOption(String mode, {bool isSelected = false}) {
    return InkWell(
      onTap: () {},
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : null,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          mode,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }
  
  Widget _buildToggleOption({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
      ],
    );
  }
  
  Widget _buildShareModal() {
    return _buildModalOverlay(
      child: Container(
        width: 350.0,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share this conversation',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: toggleShareOptions,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Share options
            _buildShareOption(
              icon: Icons.sms,
              title: 'Text Message',
              onTap: () {},
            ),
            _buildShareOption(
              icon: Icons.email,
              title: 'Email',
              onTap: () {},
            ),
            _buildShareOption(
              icon: Icons.copy,
              title: 'Copy Link',
              onTap: () {},
            ),
            const SizedBox(height: 16.0),
            
            // QR Code
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Or scan QR code',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                Center(
                  child: Container(
                    width: 150.0,
                    height: 150.0,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'QR Code',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Link
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4.0),
                        bottomLeft: Radius.circular(4.0),
                      ),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'https://hearall.app/chat/ab12cd34',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4.0),
                      bottomRight: Radius.circular(4.0),
                    ),
                  ),
                  child: const Text(
                    'Copy',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Row(
          children: [
            Container(
              width: 32.0,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16.0),
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBugReportModal() {
    return _buildModalOverlay(
      child: Container(
        width: 400.0,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report a Bug',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: toggleBugReport,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              'Help us improve HearAll by reporting any issues you encounter.',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Bug Category
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bug Category',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4.0),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                  ),
                  value: 'Audio Issues',
                  items: [
                    'Audio Issues',
                    'Voice Recognition',
                    'Text-to-Speech',
                    'User Interface',
                    'Connection Problems',
                    'Other',
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? value) {},
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Description
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4.0),
                TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Please describe the issue in detail. What were you doing when it occurred? Can you reproduce it?',
                    hintStyle: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Screenshot
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attach Screenshot (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 20.0,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'Choose file',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Include System Info
            _buildToggleOption(
              title: 'Include System Information',
              value: true,
              onChanged: (value) {},
            ),
            const SizedBox(height: 4.0),
            Text(
              'This will include your browser type, OS version, and device information to help us troubleshoot the issue.',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Submit Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: toggleBugReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmojiPicker() {
    return Positioned(
      bottom: 80.0,
      right: 20.0,
      child: Container(
        width: 250.0,
        height: 200.0,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Search
            TextField(
              decoration: InputDecoration(
                hintText: 'Search emojis',
                hintStyle: TextStyle(fontSize: 12.0),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(fontSize: 12.0),
            ),
            const SizedBox(height: 8.0),
            // Emoji grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 6,
                mainAxisSpacing: 4.0,
                crossAxisSpacing: 4.0,
                children: [
                  '😊', '😂', '❤️', '👍', '🎉', '🤔',
                  '😍', '😎', '🙌', '🤣', '😢', '👏',
                  '🔥', '💯', '🤩', '😊', '🎈', '🎁',
                ].map((emoji) => _buildEmojiItem(emoji)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmojiItem(String emoji) {
    return InkWell(
      onTap: () {
        // Insert emoji into the message input
        final currentText = messageInputController.text;
        final textSelection = messageInputController.selection;
        final newText = currentText.replaceRange(
          textSelection.start,
          textSelection.end,
          emoji,
        );
        messageInputController.text = newText;
        messageInputController.selection = TextSelection.fromPosition(
          TextPosition(offset: textSelection.start + emoji.length),
        );
        
        // Close emoji picker
        setState(() {
          showEmojiPicker = false;
        });
      },
      child: Container(
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 24.0),
        ),
      ),
    );
  }
  
  Widget _buildModalOverlay({required Widget child}) {
    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // Close all modals
              setState(() {
                showInstructions = false;
                showSettings = false;
                showShareOptions = false;
                showBugReport = false;
                showEmojiPicker = false;
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Modal
        Center(child: child),
      ],
    );
  }
  
  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16.0,
              color: Colors.blue,
            ),
            const SizedBox(width: 8.0),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        child,
      ],
    );
  }
  
  Widget _buildDiagnosticPanel() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Diagnostic Test Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: clearDiagnosticLogs,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: copyDiagnosticLogs,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                controller: diagnosticController,
                itemCount: diagnosticLogs.length,
                itemBuilder: (context, index) {
                  final log = diagnosticLogs[index];
                  Color textColor = Colors.white;
                  if (log.contains("[Test]")) {
                    textColor = Colors.yellow;
                  } else if (log.contains("[error]")) {
                    textColor = Colors.red;
                  } else if (log.contains("[audio]")) {
                    textColor = Colors.cyan;
                  } else if (log.contains("[system]") || log.contains("[System]")) {
                    textColor = Colors.green;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
