// WebRTC peer connection helper
window.webrtcJoin = function(roomId, userName) {
  console.log(`webrtcJoin called with room: ${roomId}, user: ${userName}`);
  
  // Ensure we're using the correct room ID - the one provided in the function call
  // with fallback to the initialRoomId set by Dart, or default to 'main'
  window.currentRoomId = roomId || window.initialRoomId || 'main';
  console.log(`Using room ID: ${window.currentRoomId}`);
  window.userName = userName || 'Anonymous';
  
  // Connect to WebSocket server
  const wsUrl = `ws://${window.location.hostname}:3000/webrtc`;
  console.log(`Connecting to WebSocket at ${wsUrl}`);
  
  // Create WebSocket connection
  const ws = new WebSocket(wsUrl);
  window.wsConnection = ws;
  
  // Map to store peer connections
  window.peerConnections = new Map();
  window.dataChannels = new Map();
  
  // WebSocket event handlers
  ws.onopen = () => {
    console.log("WebSocket connected");
    
    // Join room
    ws.send(JSON.stringify({
      type: 'join',
      room: window.currentRoomId,
      user: window.userName
    }));
    
    // Notify UI that connection is established
    if (window.dartConnectionEstablished) {
      window.dartConnectionEstablished(window.currentRoomId);
    }
  };
  
  ws.onclose = () => {
    console.log("WebSocket closed");
    if (window.dartAppendTranscript) {
      window.dartAppendTranscript("[system] Connection to signaling server closed");
    }
  };
  
  ws.onerror = (error) => {
    console.error("WebSocket error:", error);
    if (window.dartAppendTranscript) {
      window.dartAppendTranscript("[error] WebSocket connection error");
    }
  };
  
  ws.onmessage = async (event) => {
    try {
      const message = JSON.parse(event.data);
      console.log("WebSocket message:", message);
      
      switch(message.type) {
        case 'user-joined':
          await createPeerConnection(message.user);
          break;
          
        case 'offer':
          await handleOffer(message);
          break;
          
        case 'answer':
          await handleAnswer(message);
          break;
          
        case 'ice-candidate':
          await handleIceCandidate(message);
          break;
          
        case 'leave':
          handleUserLeft(message.user);
          break;
          
        case 'message':
          handleChatMessage(message);
          break;
      }
    } catch (err) {
      console.error("Error handling WebSocket message:", err);
    }
  };
  
  return true;
};

// Create a new peer connection for a user
async function createPeerConnection(user) {
  console.log(`Creating peer connection for ${user}`);
  
  if (window.dartAppendTranscript) {
    window.dartAppendTranscript(`[system] Creating connection to ${user}`);
  }
  
  const pc = new RTCPeerConnection({
    iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
  });
  
  window.peerConnections.set(user, pc);
  
  // Handle ICE candidates
  pc.onicecandidate = (event) => {
    if (event.candidate && window.wsConnection) {
      window.wsConnection.send(JSON.stringify({
        type: 'ice-candidate',
        target: user,
        candidate: event.candidate
      }));
    }
  };
  
  // Create data channel
  const dc = pc.createDataChannel('chat');
  setupDataChannel(dc, user);
  window.dataChannels.set(user, dc);
  
  // Create and send offer
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  
  if (window.wsConnection) {
    window.wsConnection.send(JSON.stringify({
      type: 'offer',
      target: user,
      offer: pc.localDescription
    }));
  }
}

// Handle an incoming WebRTC offer
async function handleOffer(message) {
  const pc = new RTCPeerConnection({
    iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
  });
  
  window.peerConnections.set(message.user, pc);
  
  pc.ondatachannel = (event) => {
    const dc = event.channel;
    setupDataChannel(dc, message.user);
    window.dataChannels.set(message.user, dc);
  };
  
  pc.onicecandidate = (event) => {
    if (event.candidate && window.wsConnection) {
      window.wsConnection.send(JSON.stringify({
        type: 'ice-candidate',
        target: message.user,
        candidate: event.candidate
      }));
    }
  };
  
  await pc.setRemoteDescription(new RTCSessionDescription(message.offer));
  const answer = await pc.createAnswer();
  await pc.setLocalDescription(answer);
  
  if (window.wsConnection) {
    window.wsConnection.send(JSON.stringify({
      type: 'answer',
      target: message.user,
      answer: pc.localDescription
    }));
  }
}

// Handle an incoming WebRTC answer
async function handleAnswer(message) {
  const pc = window.peerConnections.get(message.user);
  if (pc) {
    await pc.setRemoteDescription(new RTCSessionDescription(message.answer));
  }
}

// Handle an incoming ICE candidate
async function handleIceCandidate(message) {
  const pc = window.peerConnections.get(message.user);
  if (pc) {
    try {
      await pc.addIceCandidate(new RTCIceCandidate(message.candidate));
    } catch (e) {
      console.error("Error adding ICE candidate:", e);
    }
  }
}

// Handle a user leaving
function handleUserLeft(user) {
  if (window.dartAppendTranscript) {
    window.dartAppendTranscript(`[system] User ${user} left the room`);
  }
  
  const pc = window.peerConnections.get(user);
  if (pc) {
    pc.close();
    window.peerConnections.delete(user);
  }
  window.dataChannels.delete(user);
}

// Handle chat message from another user
function handleChatMessage(message) {
  if (window.dartAppendTranscript) {
    window.dartAppendTranscript(`${message.user}: ${message.data}`);
  }
  
  if (window.dartReceiveChat) {
    window.dartReceiveChat(message.user, message.data);
  }
}

// Set up a data channel
function setupDataChannel(dc, user) {
  dc.onopen = () => {
    console.log(`Data channel with ${user} opened`);
    if (window.dartAppendTranscript) {
      window.dartAppendTranscript(`[system] Connected to ${user}`);
    }
  };
  
  dc.onclose = () => {
    console.log(`Data channel with ${user} closed`);
    if (window.dartAppendTranscript) {
      window.dartAppendTranscript(`[system] Disconnected from ${user}`);
    }
  };
  
  dc.onmessage = (event) => {
    try {
      const message = JSON.parse(event.data);
      console.log(`Message from ${user}:`, message);
      
      if (message.type === 'chat') {
        if (window.dartAppendTranscript) {
          window.dartAppendTranscript(`${message.user}: ${message.data}`);
        }
        
        if (window.dartReceiveChat) {
          window.dartReceiveChat(message.user, message.data);
        }
      }
    } catch (e) {
      console.error("Error parsing data channel message:", e);
    }
  };
}

// Send a chat message to all connected peers
window.sendChatMessage = function(message) {
  const payload = {
    type: 'chat',
    user: window.userName,
    data: message
  };
  
  let peerConnectionsAvailable = false;
  
  // Try to send through data channels first
  if (window.dataChannels && window.dataChannels.size > 0) {
    peerConnectionsAvailable = true;
    window.dataChannels.forEach(dc => {
      if (dc.readyState === 'open') {
        dc.send(JSON.stringify(payload));
      }
    });
  }
  
  // If no peer connections available, fall back to server broadcast
  // Or if we're in the process of establishing connections and might not have all peers yet
  if (!peerConnectionsAvailable || window.peerConnections.size === 0) {
    if (window.wsConnection && window.wsConnection.readyState === WebSocket.OPEN) {
      window.wsConnection.send(JSON.stringify({
        type: 'message',
        data: message
      }));
    }
  }
};

// Function to handle Text-to-Speech requests
window.webrtcSendTTS = async function(text) {
  if (!text) return false;
  
  try {
    console.log("Sending TTS request for:", text);
    
    // First send as normal chat message
    window.sendChatMessage(text);
    
    // Then use the TTS API to generate speech
    const response = await fetch(`http://${window.location.hostname}:3000/api/tts`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        text: text,
        voice: window.selectedVoice || 'alloy'
      })
    });
    
    if (!response.ok) {
      console.error("TTS API error:", response.status);
      if (window.dartAppendTranscript) {
        window.dartAppendTranscript(`[error] TTS API error: ${response.status}`);
      }
      return false;
    }
    
    // Get the audio data as array buffer
    const audioData = await response.arrayBuffer();
    
    // Play the audio using Web Audio API
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    
    audioContext.decodeAudioData(audioData, (buffer) => {
      const source = audioContext.createBufferSource();
      source.buffer = buffer;
      source.connect(audioContext.destination);
      source.start(0);
      
      if (window.dartAppendTranscript) {
        window.dartAppendTranscript("[audio] Playing TTS audio");
      }
    }, (error) => {
      console.error("Audio decoding error:", error);
      if (window.dartAppendTranscript) {
        window.dartAppendTranscript(`[error] Audio decoding error: ${error}`);
      }
    });
    
    return true;
  } catch (error) {
    console.error("TTS error:", error);
    if (window.dartAppendTranscript) {
      window.dartAppendTranscript(`[error] TTS error: ${error.message}`);
    }
    return false;
  }
};

// Leave the WebRTC session
window.webrtcLeave = function() {
  // Send leave message
  if (window.wsConnection && window.wsConnection.readyState === WebSocket.OPEN) {
    window.wsConnection.send(JSON.stringify({
      type: 'leave',
      room: window.currentRoomId,
      user: window.userName
    }));
    
    window.wsConnection.close();
  }
  
  // Close all peer connections
  if (window.peerConnections) {
    window.peerConnections.forEach(pc => pc.close());
    window.peerConnections.clear();
  }
  
  if (window.dataChannels) {
    window.dataChannels.clear();
  }
  
  if (window.dartAppendTranscript) {
    window.dartAppendTranscript('[system] Left session');
  }
  
  return true;
};
