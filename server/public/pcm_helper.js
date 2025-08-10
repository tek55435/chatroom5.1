// PCM Helper functions for WebRTC TTS audio processing

/**
 * Convert PCM audio buffer to Float32Array for Web Audio API
 * @param {Uint8Array|Int16Array} pcmData - PCM audio data
 * @param {boolean} isInt16 - Whether the data is Int16 format (true) or UInt8 (false)
 * @returns {Float32Array} - Float32 audio data suitable for Web Audio API
 */
function pcmToFloat32(pcmData, isInt16 = true) {
  console.log("Converting PCM data to Float32 format");
  console.log(`PCM data type: ${isInt16 ? 'Int16' : 'UInt8'}, length: ${pcmData.length}`);
  
  // For Int16 PCM (common 16-bit format)
  if (isInt16) {
    // If data is already Int16Array, use it, otherwise create a view
    const int16Data = pcmData instanceof Int16Array ? 
      pcmData : new Int16Array(pcmData.buffer);
    
    const floatData = new Float32Array(int16Data.length);
    // Convert Int16 (-32768 to 32767) to Float32 (-1.0 to 1.0)
    for (let i = 0; i < int16Data.length; i++) {
      // Normalize to -1.0 to 1.0 range
      floatData[i] = int16Data[i] / 32768.0;
    }
    console.log(`Created Float32Array of length ${floatData.length}`);
    return floatData;
  } 
  // For UInt8 PCM (less common 8-bit format)
  else {
    const uint8Data = pcmData instanceof Uint8Array ? 
      pcmData : new Uint8Array(pcmData);
    
    const floatData = new Float32Array(uint8Data.length);
    for (let i = 0; i < uint8Data.length; i++) {
      // Convert UInt8 (0 to 255) to Float32 (-1.0 to 1.0)
      // First remap to -128 to 127 range, then normalize
      floatData[i] = (uint8Data[i] - 128) / 128.0;
    }
    return floatData;
  }
}

/**
 * Play PCM audio buffer through Web Audio API
 * @param {ArrayBuffer} pcmBuffer - Raw PCM audio buffer
 * @param {number} sampleRate - Sample rate of the audio (e.g. 24000, 48000)
 * @param {boolean} isInt16 - Whether the data is Int16 format (true) or UInt8 (false)
 * @param {boolean} debugMode - Print debug info to console
 * @returns {Promise} - Promise that resolves when audio playback begins
 */
function playPCMBuffer(pcmBuffer, sampleRate = 24000, isInt16 = true, debugMode = true) {
  return new Promise((resolve, reject) => {
    if (!pcmBuffer || pcmBuffer.byteLength === 0) {
      if (debugMode) console.error("Warning: Empty PCM buffer received");
      reject(new Error("Empty buffer"));
      return;
    }
    
    if (debugMode) {
      console.log(`Playing PCM buffer: ${pcmBuffer.byteLength} bytes, ${sampleRate}Hz, ${isInt16 ? '16-bit' : '8-bit'}`);
    }
    
    try {
      // Create audio context (or get existing one)
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      const audioCtx = window.audioContext || new AudioContext({ sampleRate });
      window.audioContext = audioCtx;
      
      // Make sure the audio context is running
      if (audioCtx.state !== "running") {
        console.log("Resuming audio context...");
        audioCtx.resume().catch(err => {
          console.error("Failed to resume audio context:", err);
        });
      }
      
      // Different handling based on buffer type
      let audioData;
      
      if (isInt16) {
        // For 16-bit PCM (common for TTS)
        const int16Data = new Int16Array(pcmBuffer);
        audioData = pcmToFloat32(int16Data, true);
      } else {
        // For 8-bit PCM 
        const uint8Data = new Uint8Array(pcmBuffer);
        audioData = pcmToFloat32(uint8Data, false);
      }
      
      // Create buffer source
      const audioBuffer = audioCtx.createBuffer(1, audioData.length, sampleRate);
      const channelData = audioBuffer.getChannelData(0);
      channelData.set(audioData);
      
      const source = audioCtx.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(audioCtx.destination);
      
      // Start playback
      source.start(0);
      if (debugMode) console.log("Audio playback started");
      
      // Signal that audio was successfully played - important for the client to know
      if (window.lastAudioChunkTime) {
        window.lastAudioChunkTime = Date.now();
      }
      
      // Resolve when playback begins
      resolve({success: true, duration: audioBuffer.duration * 1000});
    } catch (error) {
      console.error("Error playing PCM audio:", error);
      reject(error);
    }
  });
}

/**
 * Analyze an audio buffer to determine format and content
 * @param {ArrayBuffer} buffer - The audio buffer to analyze
 * @returns {Object} - Analysis results
 */
function analyzeAudioBuffer(buffer) {
  if (!buffer || buffer.byteLength === 0) {
    return { 
      valid: false, 
      error: "Empty buffer",
      hasAudio: false,
      estimatedDurationMs: 0
    };
  }
  
  console.log("Analyzing audio buffer of size:", buffer.byteLength, "bytes");
  
  const result = {
    valid: true,
    byteLength: buffer.byteLength,
    formats: {},
    hasAudio: false, // Will be set to true if audio content is detected
    estimatedDurationMs: 0 // Will be calculated based on format and sample rate
  };
  
  // Check if it looks like 16-bit PCM
  if (buffer.byteLength % 2 === 0) {
    const int16View = new Int16Array(buffer);
    const int16Stats = analyzeInt16Data(int16View);
    result.formats.int16 = int16Stats;
  }
  
  // Always analyze as 8-bit PCM as fallback
  const uint8View = new Uint8Array(buffer);
  const uint8Stats = analyzeUint8Data(uint8View);
  result.formats.uint8 = uint8Stats;
  
  // Determine most likely format
  if (result.formats.int16 && result.formats.int16.validRatio > 0.8) {
    result.likelyFormat = 'int16';
    result.sampleCount = buffer.byteLength / 2;
    result.hasAudio = result.formats.int16.nonZeroCount > 0;
    // Calculate duration in milliseconds based on sample count (assuming 24kHz sample rate)
    result.estimatedDurationMs = (result.sampleCount / 24000) * 1000;
  } else if (result.formats.uint8 && result.formats.uint8.validRatio > 0.8) {
    result.likelyFormat = 'uint8';
    result.sampleCount = buffer.byteLength;
    result.hasAudio = result.formats.uint8.nonMidCount > 0;
    // Calculate duration in milliseconds based on sample count (assuming 24kHz sample rate)
    result.estimatedDurationMs = (result.sampleCount / 24000) * 1000;
  } else {
    result.likelyFormat = 'unknown';
    result.valid = false;
    result.hasAudio = false;
    result.estimatedDurationMs = 0;
  }
  
  console.log("Audio analysis results:", result);
  return result;
}

/**
 * Analyze Int16 audio data
 * @private
 */
function analyzeInt16Data(int16View) {
  let min = Infinity, max = -Infinity;
  let zeroCount = 0;
  let nonZeroCount = 0;
  
  // Sample up to 10,000 values for speed
  const step = Math.max(1, Math.floor(int16View.length / 10000));
  
  for (let i = 0; i < int16View.length; i += step) {
    const value = int16View[i];
    min = Math.min(min, value);
    max = Math.max(max, value);
    
    if (value === 0) {
      zeroCount++;
    } else {
      nonZeroCount++;
    }
  }
  
  // Calculate statistics
  const samplesAnalyzed = Math.ceil(int16View.length / step);
  const nonZeroRatio = nonZeroCount / samplesAnalyzed;
  
  // Heuristic check for valid audio (not just zeros or random data)
  const validRatio = (max > 1000 && min < -1000 && nonZeroRatio > 0.1) ? nonZeroRatio : 0;
  
  return {
    min,
    max,
    zeroCount,
    nonZeroCount,
    samplesAnalyzed,
    validRatio
  };
}

/**
 * Analyze UInt8 audio data
 * @private
 */
function analyzeUint8Data(uint8View) {
  let min = Infinity, max = -Infinity;
  let midCount = 0; // Count values near the middle (127-128)
  let nonMidCount = 0;
  
  // Sample up to 10,000 values for speed
  const step = Math.max(1, Math.floor(uint8View.length / 10000));
  
  for (let i = 0; i < uint8View.length; i += step) {
    const value = uint8View[i];
    min = Math.min(min, value);
    max = Math.max(max, value);
    
    if (value >= 126 && value <= 129) {
      midCount++;
    } else {
      nonMidCount++;
    }
  }
  
  // Calculate statistics
  const samplesAnalyzed = Math.ceil(uint8View.length / step);
  const nonMidRatio = nonMidCount / samplesAnalyzed;
  
  // Heuristic check for valid audio (not just zeros or random data)
  const validRatio = (max > 180 && min < 80 && nonMidRatio > 0.1) ? nonMidRatio : 0;
  
  return {
    min,
    max,
    midCount,
    nonMidCount,
    samplesAnalyzed,
    validRatio
  };
}

// Export functions for use in the app
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    pcmToFloat32,
    playPCMBuffer,
    analyzeAudioBuffer
  };
} else if (typeof window !== 'undefined') {
  // Add to window object if in browser
  window.pcmToFloat32 = pcmToFloat32;
  window.playPCMBuffer = playPCMBuffer;
  window.analyzeAudioBuffer = analyzeAudioBuffer;
}
