const express = require('express');
const path = require('path');
const __dirname = __dirname || process.cwd();

const app = express();
const PORT = 3000;

// Global request logger
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Enable JSON parsing middleware
app.use(express.json());

// Serve static files with detailed logging
app.use(express.static(path.join(__dirname, 'public'), { 
  setHeaders: (res, path) => {
    console.log(`Serving static file: ${path}`);
  }
}));

// Root route
app.get('/', (req, res) => {
  console.log('GET request to /');
  res.sendFile(path.join(__dirname, 'public/index.html'));
});

// Serve a test page for TTS handler
app.get('/tts-test', (req, res) => {
  console.log('GET request to /tts-test');
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>TTS Handler Test</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        button { padding: 10px 15px; margin: 5px; cursor: pointer; }
        textarea { width: 100%; height: 100px; margin: 10px 0; }
        pre { background: #f4f4f4; padding: 10px; overflow: auto; }
        .controls { display: flex; gap: 10px; margin-bottom: 20px; }
        .log-section { margin-top: 20px; }
      </style>
    </head>
    <body>
      <h1>TTS Handler Test</h1>
      
      <div class="controls">
        <button id="init-audio">Initialize Audio Context</button>
        <button id="test-audio">Test Audio Output</button>
      </div>
      
      <div>
        <h3>Send TTS Request</h3>
        <textarea id="tts-text">Hello, this is a test of the text-to-speech functionality.</textarea>
        <button id="send-tts">Send TTS Request</button>
      </div>
      
      <div class="log-section">
        <h3>Log</h3>
        <button id="clear-log">Clear Log</button>
        <pre id="log"></pre>
      </div>
      
      <!-- Load the helper scripts -->
      <script src="/pcm_helper.js"></script>
      <script src="/tts_handler.js"></script>
      
      <script>
        // Test logger
        function log(message) {
          const logElement = document.getElementById('log');
          const timestamp = new Date().toISOString();
          logElement.textContent += `[${timestamp}] ${message}\n`;
          logElement.scrollTop = logElement.scrollHeight;
          console.log(message);
        }
        
        // Initialize audio context
        document.getElementById('init-audio').addEventListener('click', () => {
          try {
            const audioCtx = getAudioContext();
            log(`Audio context initialized: ${audioCtx.state}`);
            
            if (audioCtx.state !== 'running') {
              log('Resuming audio context...');
              audioCtx.resume()
                .then(() => log(`Audio context state: ${audioCtx.state}`))
                .catch(err => log(`Error resuming context: ${err.message}`));
            }
          } catch (err) {
            log(`Error initializing audio context: ${err.message}`);
          }
        });
        
        // Test audio output
        document.getElementById('test-audio').addEventListener('click', () => {
          log('Creating test audio buffer...');
          
          try {
            // Create a simple sine wave
            const audioCtx = getAudioContext();
            const sampleRate = 24000;
            const duration = 1; // 1 second
            const numSamples = sampleRate * duration;
            
            // Create Int16 buffer (for 16-bit PCM)
            const int16Buffer = new Int16Array(numSamples);
            const frequency = 440; // A4 note
            
            // Generate a sine wave
            for (let i = 0; i < numSamples; i++) {
              int16Buffer[i] = Math.sin(2 * Math.PI * frequency * i / sampleRate) * 32767;
            }
            
            log(`Created test audio: ${duration}s, ${frequency}Hz tone`);
            
            // Play using PCM helper
            window.playPCMBuffer(int16Buffer.buffer, sampleRate, true, true)
              .then(result => log(`Audio playback started: ${JSON.stringify(result)}`))
              .catch(err => log(`PCM playback failed: ${err.message}`));
          } catch (err) {
            log(`Error creating test audio: ${err.message}`);
          }
        });
        
        // Send TTS request
        document.getElementById('send-tts').addEventListener('click', () => {
          const text = document.getElementById('tts-text').value;
          if (!text.trim()) {
            log('Please enter some text for TTS');
            return;
          }
          
          log(`Sending TTS request for: "${text}"`);
          
          // Simulate a TTS request
          fetch('/api/tts', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ text })
          })
          .then(response => response.json())
          .then(data => {
            log(`TTS response received: ${JSON.stringify(data)}`);
            
            // Set up timeout for audio response
            window.setupTTSTimeout();
            
            // Simulate receiving audio data after a short delay
            if (data.status === 'processing') {
              setTimeout(() => {
                log('Simulating audio chunk received...');
                fetchAudioChunk(data.id);
              }, 500);
            }
          })
          .catch(err => log(`TTS request failed: ${err.message}`));
        });
        
        // Fetch audio chunk
        function fetchAudioChunk(id) {
          fetch(`/api/tts/${id}/audio`)
            .then(response => response.json())
            .then(data => {
              log(`Audio chunk received: ${data.chunkId}`);
              
              // Process the audio chunk
              if (data.audio) {
                const audioBytes = atob(data.audio);
                const audioBuffer = new ArrayBuffer(audioBytes.length);
                const audioView = new Uint8Array(audioBuffer);
                
                for (let i = 0; i < audioBytes.length; i++) {
                  audioView[i] = audioBytes.charCodeAt(i);
                }
                
                // Simulate processing audio chunk
                window.processDataChannelMessage({
                  data: JSON.stringify({
                    type: 'audio.chunk',
                    chunk: {
                      bytes: data.audio
                    }
                  })
                });
              }
            })
            .catch(err => log(`Audio chunk fetch failed: ${err.message}`));
        }
        
        // Clear log
        document.getElementById('clear-log').addEventListener('click', () => {
          document.getElementById('log').textContent = '';
        });
        
        // Initialize
        window.addEventListener('DOMContentLoaded', () => {
          log('TTS Handler Test page loaded');
        });
        
        // Define getAudioContext function if not already defined by the loaded scripts
        if (typeof window.getAudioContext !== 'function') {
          window.getAudioContext = function() {
            if (!window.audioContext) {
              try {
                const AudioContext = window.AudioContext || window.webkitAudioContext;
                window.audioContext = new AudioContext({ sampleRate: 24000 });
              } catch (err) {
                console.error("Failed to create audio context:", err);
              }
            }
            
            return window.audioContext;
          };
        }
      </script>
    </body>
    </html>
  `);
});

// API endpoint to handle TTS requests
app.post('/api/tts', (req, res) => {
  const { text } = req.body;
  console.log(`Received TTS request for: "${text}"`);
  
  // Generate a random ID for this TTS request
  const id = Math.random().toString(36).substring(2, 15);
  
  // Respond with success and the request ID
  res.json({
    status: 'processing',
    id,
    text
  });
});

// API endpoint to provide audio chunks
app.get('/api/tts/:id/audio', (req, res) => {
  const { id } = req.params;
  console.log(`Sending audio chunk for TTS request ${id}`);
  
  // Generate a simple test audio (sine wave)
  const sampleRate = 24000;
  const duration = 2; // 2 seconds
  const numSamples = sampleRate * duration;
  
  // Create Int16 buffer (for 16-bit PCM)
  const int16Buffer = new Int16Array(numSamples);
  const frequency = 440; // A4 note
  
  // Generate a sine wave
  for (let i = 0; i < numSamples; i++) {
    int16Buffer[i] = Math.sin(2 * Math.PI * frequency * i / sampleRate) * 32767;
  }
  
  // Convert to base64 for transmission
  const uint8Array = new Uint8Array(int16Buffer.buffer);
  let binary = '';
  for (let i = 0; i < uint8Array.length; i++) {
    binary += String.fromCharCode(uint8Array[i]);
  }
  const base64 = btoa(binary);
  
  // Return the audio data
  res.json({
    status: 'success',
    chunkId: '1',
    audio: base64
  });
});

// Test route to check if server is running
app.get('/test', (req, res) => {
  console.log('GET request to /test');
  res.send('TTS Test Server is Working!');
});

// Start the server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`TTS test server running on http://localhost:${PORT}`);
  console.log(`Server address: ${JSON.stringify(server.address())}`);
  console.log(`TTS test page: http://localhost:${PORT}/tts-test`);
}).on('error', (err) => {
  console.error('Server failed to start:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Please close the application using this port or change the PORT value.`);
  }
});
