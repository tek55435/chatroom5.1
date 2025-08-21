const express = require('express');
const path = require('path');

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

// Serve the test page
app.get('/tts-test', (req, res) => {
  console.log('GET request to /tts-test');
  res.sendFile(path.join(__dirname, 'public/tts-test.html'));
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
  const base64 = Buffer.from(binary).toString('base64');
  
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
