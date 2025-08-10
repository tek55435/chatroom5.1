// WebRTC TTS message handler
// This file handles the WebRTC data channel messages and audio processing

/**
 * Process TTS messages and audio chunks from WebRTC data channel
 */
(function() {
  // Flag to track if we're currently processing audio
  let isProcessingAudio = false;
  let audioChunksReceived = 0;
  let lastAudioTimestamp = 0;

  // Keep track of the last time audio was requested
  let lastTTSRequestTime = 0;

  // Initialize audio context when needed
  // Check if getAudioContext is already defined globally
  if (!window.getAudioContext) {
    window.getAudioContext = function() {
      if (!window.audioContext) {
        try {
          const AudioContext = window.AudioContext || window.webkitAudioContext;
          window.audioContext = new AudioContext({ sampleRate: 24000 });
          console.log("Audio context initialized:", window.audioContext.state);
        } catch (err) {
          console.error("Failed to create audio context:", err);
        }
      }
      
      // Resume if needed
      if (window.audioContext && window.audioContext.state !== "running") {
        window.audioContext.resume().catch(e => console.error("Failed to resume audio context:", e));
      }
      
      return window.audioContext;
    };
  }
  
  // Function for internal use - get the audio context without recursion
  function getAudioContext() {
    // Direct access to audio context to avoid recursion
    if (!window.audioContext) {
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        window.audioContext = new AudioContext({ sampleRate: 24000 });
        console.log("TTS: Audio context initialized:", window.audioContext.state);
      } catch (err) {
        console.error("TTS: Failed to create audio context:", err);
      }
    }
    
    // Resume if needed
    if (window.audioContext && window.audioContext.state !== "running") {
      window.audioContext.resume().catch(e => console.error("TTS: Failed to resume audio context:", e));
    }
    
    return window.audioContext;
  }

  /**
   * Process data channel message
   * @param {MessageEvent} event - WebRTC data channel message event
   */
  window.processDataChannelMessage = function(event) {
    try {
      if (typeof event.data === 'string') {
        const data = JSON.parse(event.data);
        const type = data.type || '';
        
        // Special handling for audio chunks
        if (type === 'audio.chunk') {
          console.log(`Audio chunk received at ${new Date().toISOString()}`);
          processAudioChunk(data);
          return;
        }
        
        // Handle other event types
        // TTS requests
        if (type === 'conversation.item.create') {
          const content = data.item?.content;
          if (content && Array.isArray(content)) {
            const textItem = content.find(item => item.type === 'input_text');
            if (textItem && textItem.text) {
              console.log(`TTS request for: "${textItem.text}"`);
              lastTTSRequestTime = Date.now();
              // Reset audio tracking variables
              audioChunksReceived = 0;
            }
          }
        }
        
        // Audio metadata
        if (type === 'audio.metadata') {
          console.log('Audio metadata received:', data);
          // Initialize audio context
          getAudioContext();
        }
      }
    } catch (e) {
      console.error("Error processing data channel message:", e);
    }
  };
  
  /**
   * Process audio chunk from data channel
   */
  function processAudioChunk(data) {
    // Update tracking variables
    lastAudioTimestamp = Date.now();
    audioChunksReceived++;
    
    console.log(`Processing audio chunk #${audioChunksReceived}`);
    
    if (!data.chunk || !data.chunk.bytes) {
      console.error("Audio chunk missing bytes");
      return;
    }
    
    try {
      // Decode base64 audio data
      const audioBytes = atob(data.chunk.bytes);
      const audioBuffer = new ArrayBuffer(audioBytes.length);
      const audioView = new Uint8Array(audioBuffer);
      
      // Convert to byte array
      for (let i = 0; i < audioBytes.length; i++) {
        audioView[i] = audioBytes.charCodeAt(i);
      }
      
      console.log(`Audio chunk contains ${audioBuffer.byteLength} bytes`);
      
      // Play using our PCM helper
      if (typeof window.playPCMBuffer === 'function') {
        console.log("Using PCM helper to play audio");
        
        // First analyze the audio
        if (typeof window.analyzeAudioBuffer === 'function') {
          const analysis = window.analyzeAudioBuffer(audioBuffer);
          console.log("Audio analysis:", analysis);
          
          if (analysis.hasAudio) {
            console.log(`Playing audio: ${analysis.estimatedDurationMs.toFixed(0)}ms`);
            window.playPCMBuffer(audioBuffer, 24000, true, true)
              .then(result => {
                console.log("Audio playback started:", result);
                // Clear any timeout that might show "no audio response" error
                clearNoAudioResponseTimeout();
              })
              .catch(err => {
                console.error("PCM playback failed:", err);
              });
          } else {
            console.warn("Audio chunk contains no audio data");
          }
        } else {
          // Fall back to direct playback if analyzer isn't available
          window.playPCMBuffer(audioBuffer)
            .then(() => console.log("Audio playback success"))
            .catch(err => console.error("Audio playback failed:", err));
        }
      } else {
        console.error("PCM helper not available");
      }
    } catch (err) {
      console.error("Error processing audio chunk:", err);
    }
  }
  
  // Handle the "no audio response" timeout
  let noAudioResponseTimeout = null;
  
  // Set up the timeout when TTS is requested
  window.setupTTSTimeout = function() {
    clearNoAudioResponseTimeout();
    
    // Set a new timeout
    noAudioResponseTimeout = setTimeout(() => {
      const now = Date.now();
      const timeSinceTTSRequest = now - lastTTSRequestTime;
      const timeSinceLastAudio = now - lastAudioTimestamp;
      
      if (audioChunksReceived === 0 && timeSinceTTSRequest > 5000) {
        console.warn("No audio response received after 5 seconds");
        // This gets picked up by the Flutter app
        window.dispatchEvent(new CustomEvent('tts-error', { 
          detail: { message: 'No audio response received' } 
        }));
      }
    }, 5000);
  };
  
  // Clear the timeout
  function clearNoAudioResponseTimeout() {
    if (noAudioResponseTimeout) {
      clearTimeout(noAudioResponseTimeout);
      noAudioResponseTimeout = null;
    }
  }
  
  // Make functions available globally
  window.setupTTSTimeout = setupTTSTimeout;
  window.clearTTSTimeout = clearNoAudioResponseTimeout;
  window.getAudioContext = getAudioContext;
  
  console.log("WebRTC TTS message handler loaded with exposed getAudioContext function");
})();
