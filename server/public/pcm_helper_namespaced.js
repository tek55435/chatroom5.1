/**
 * Helper functions for PCM audio processing in the chatroom application
 * Namespaced version to avoid conflicts
 */

// Create a namespace for our PCM Helper
window.ChatroomPCMHelper = {
  // Convert PCM buffer to Float32Array for Web Audio API
  pcmToFloat32: function(buffer) {
    // Create DataView to read 16-bit samples properly
    const dataView = new DataView(buffer);
    const floatArray = new Float32Array(buffer.byteLength / 2);
    
    for (let i = 0; i < floatArray.length; i++) {
      // Get 16-bit sample (little-endian)
      const int16Sample = dataView.getInt16(i * 2, true);
      // Convert to float in range -1.0 to 1.0
      floatArray[i] = int16Sample / 32768.0;
    }
    
    return floatArray;
  },

  // Play a PCM buffer directly
  playPCMBuffer: function(buffer, sampleRate = 24000) {
    return new Promise((resolve, reject) => {
      try {
        // Create audio context if needed
        const ctx = new (window.AudioContext || window.webkitAudioContext)({sampleRate});
        
        // Convert PCM to float
        const floatData = this.pcmToFloat32(buffer);
        
        // Create audio buffer
        const audioBuffer = ctx.createBuffer(1, floatData.length, sampleRate);
        audioBuffer.getChannelData(0).set(floatData);
        
        // Create and connect source
        const source = ctx.createBufferSource();
        source.buffer = audioBuffer;
        source.connect(ctx.destination);
        
        // Handle completion
        source.onended = () => {
          resolve();
        };
        
        // Start playback
        source.start(0);
        console.log(`Playing PCM audio: ${floatData.length} samples at ${sampleRate}Hz`);
      } catch (err) {
        console.error("PCM playback error:", err);
        reject(err);
      }
    });
  },

  // Debug function to analyze audio buffer
  analyzeAudioBuffer: function(buffer) {
    try {
      const view = new DataView(buffer);
      const byteLength = buffer.byteLength;
      const sampleCount = Math.floor(byteLength / 2); // 16-bit = 2 bytes per sample
      
      // Get min/max values to check amplitude
      let min = 0, max = 0;
      let sum = 0;
      
      for (let i = 0; i < sampleCount; i++) {
        const sample = view.getInt16(i * 2, true); // true = little endian
        min = Math.min(min, sample);
        max = Math.max(max, sample);
        sum += Math.abs(sample);
      }
      
      const avgMagnitude = sum / sampleCount;
      
      return {
        byteLength,
        sampleCount,
        minSample: min,
        maxSample: max,
        avgMagnitude,
        hasAudio: avgMagnitude > 10, // Arbitrary threshold to detect silence
        estimatedDurationMs: (sampleCount / 24000) * 1000 // Assuming 24kHz
      };
    } catch (err) {
      return {
        error: err.message,
        byteLength: buffer.byteLength
      };
    }
  }
};

// Backwards compatibility (optional)
window.pcmToFloat32 = function(buffer) {
  console.warn("Using deprecated global pcmToFloat32. Please use ChatroomPCMHelper.pcmToFloat32 instead");
  return window.ChatroomPCMHelper.pcmToFloat32(buffer);
};

window.playPCMBuffer = function(buffer, sampleRate) {
  console.warn("Using deprecated global playPCMBuffer. Please use ChatroomPCMHelper.playPCMBuffer instead");
  return window.ChatroomPCMHelper.playPCMBuffer(buffer, sampleRate);
};

window.analyzeAudioBuffer = function(buffer) {
  console.warn("Using deprecated global analyzeAudioBuffer. Please use ChatroomPCMHelper.analyzeAudioBuffer instead");
  return window.ChatroomPCMHelper.analyzeAudioBuffer(buffer);
};

console.log("ChatroomPCMHelper initialized");
