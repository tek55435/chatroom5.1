// Global variables and connection state
let peerConnection = null;
let dataChannel = null;
let localStream = null;
let connectionEstablished = false;
let wsConnection = null;
let currentRoomId = null;

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
    console.log("Initializing WebRTC...");
    
    peerConnection = new RTCPeerConnection({
      iceServers: []
    });
    
    console.log("RTCPeerConnection created successfully");
    
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
    
    // Add ice candidate handler
    peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        console.log("ICE candidate:", event.candidate);
      } else {
        console.log("ICE gathering complete");
      }
    };
    
    // Add connection state change handler
    peerConnection.onconnectionstatechange = () => {
      console.log("Connection state:", peerConnection.connectionState);
      appendToTranscript(`Connection state: ${peerConnection.connectionState}`);
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
          appendToTranscript(`[debug] Session ${type === 'session.created' ? 'created' : 'updated'}`);
        } else if (type === 'audio') {
          console.log("Audio message received, length:", data.data ? data.data.length : 'unknown');
          if (data.data) {
            playAudioIfAvailable(data.data);
          }
        } else {
          console.log("Unknown message type:", type);
        }
      } catch (err) {
        console.error("Error handling message:", err);
        appendToTranscript("[error] Failed to parse message: " + err.message);
      }
    };
    
    return true;
  } catch (err) {
    console.error("Error initializing WebRTC:", err);
    appendToTranscript("Error: " + err.message);
    return false;
  }
}

function notifyConnectionReady(roomId) {
  connectionEstablished = true;
  if (window.dartConnectionEstablished) {
    // Pass current room ID back to Dart when connection is established
    window.dartConnectionEstablished(roomId);
  }
}

// Join WebRTC session with proper room handling
async function joinRTCSession(roomId) {
  try {
    // Initialize WebRTC if needed
    if (!peerConnection) {
      const success = await initWebRTC();
      if (!success) {
        return false;
      }
    }
    
    console.log("Starting WebRTC session");
    
    // Determine server base URL
  const serverUrl = window.SERVER_BASE || window.location.origin;
    const fullUrl = `${serverUrl}/offer`;
    console.log("Server base from window:", window.SERVER_BASE);
    console.log("Using server URL:", serverUrl);
    
    try {
      // Create an offer
      console.log("Creating WebRTC offer...");
      const offer = await peerConnection.createOffer();
      console.log("Offer created successfully");
      
      await peerConnection.setLocalDescription(offer);
      console.log("Local description set successfully");
      
      // Log the SDP data being sent
      console.log("Sending SDP:", peerConnection.localDescription.sdp.substring(0, 100) + "...");
      appendToTranscript(`Sending offer to ${fullUrl}`);
      
      const requestBody = {
        sdp: peerConnection.localDescription.sdp,
        room: window.currentRoomId || 'main'
      };
      
      console.log("Request body:", JSON.stringify(requestBody).substring(0, 200) + "...");
      
      const response = await fetch(fullUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
      });
      
      console.log("Response status:", response.status, response.statusText);
    
      if (!response.ok) {
        const errorText = await response.text();
        console.error("Server error response:", errorText);
        appendToTranscript("Error from server: " + response.status);
        appendToTranscript("Error details: " + errorText);
        return false;
      }
      
      // Get answer SDP
      const answerSdp = await response.text();
      console.log("Got answer SDP:", answerSdp.substring(0, 100) + "...");
      appendToTranscript("Got answer from server");
      
      // Set remote description
      await peerConnection.setRemoteDescription({
        type: 'answer',
        sdp: answerSdp
      });
      
      console.log("Remote description set successfully");
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
  
  // Send the message
  const message = {
    type: 'client.message.text',
    text: text
  };
  console.log("Sending TTS message:", message);
  
  try {
    dataChannel.send(JSON.stringify(message));
    appendToTranscript(`[sent] ${text}`);
    return true;
  } catch (err) {
    console.error("Error sending message:", err);
    appendToTranscript("[error] Failed to send: " + err.message);
    return false;
  }
}

// Play audio data received from server
function playAudioIfAvailable(base64AudioData) {
  try {
    // Convert base64 to array buffer
    const rawData = atob(base64AudioData);
    const audioArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; i++) {
      audioArray[i] = rawData.charCodeAt(i);
    }
    
    // Add to queue
    if (!window.audioQueue) window.audioQueue = [];
    window.audioQueue.push(audioArray);
    
    // Start playing if not already playing
    if (!window.isPlayingAudio) {
      playNextAudioChunk();
    }
  } catch (err) {
    console.error("Error processing audio:", err);
  }
}

// Play next audio chunk in queue
function playNextAudioChunk() {
  if (!window.audioQueue || window.audioQueue.length === 0) {
    window.isPlayingAudio = false;
    return;
  }
  
  window.isPlayingAudio = true;
  const audioArray = window.audioQueue.shift();
  
  try {
    // Ensure audio context exists
    if (!window.audioContext) {
      window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
    }
    
    // Reset audio context if it's in a closed state
    if (window.audioContext.state === "closed") {
      window.audioContext = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 24000});
    }
    
    // Resume audio context if suspended
    if (window.audioContext.state === "suspended") {
      window.audioContext.resume();
    }
    
    // Process PCM audio
    const audioBuffer = window.audioContext.createBuffer(1, audioArray.length / 2, 24000);
    const nowBuffering = audioBuffer.getChannelData(0);
    
    // Convert audio data (16-bit PCM) to float
    for (let i = 0; i < audioArray.length / 2; i++) {
      const index = i * 2;
      const sample = (audioArray[index] & 0xff) | ((audioArray[index + 1] & 0xff) << 8);
      // Convert from 16-bit signed integer to float
      nowBuffering[i] = (sample >= 0x8000 ? sample - 0x10000 : sample) / 32768.0;
    }
    
    // Create and play audio source
    const source = window.audioContext.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(window.audioContext.destination);
    
    // When playback ends, play next chunk
    source.onended = playNextAudioChunk;
    source.start(0);
    
  } catch (err) {
    console.error("Error playing audio:", err);
    // Try next chunk
    setTimeout(playNextAudioChunk, 100);
  }
}

// Make functions available globally
window.webrtcInit = initWebRTC;
window.webrtcJoin = joinRTCSession;
window.webrtcStartMic = startMicrophone;
window.webrtcStopMic = stopMicrophone;
window.webrtcLeave = leaveSession;
window.webrtcSendTTS = sendTTS;
