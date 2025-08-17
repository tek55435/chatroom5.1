// HearAll Chat Server - Main entry point
// This server provides WebRTC signaling, STT/TTS APIs, and serves the Flutter web client

require('dotenv').config();
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { promisify } = require('util');

// Configuration
const PORT = process.env.PORT || 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const LOG_DIR = path.join(__dirname, 'logs');

// Create log directory if it doesn't exist
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR);
}

// Set up Express app
const app = express();
app.use(cors());
app.use(express.json());

// Set up upload handling for audio files
const storage = multer.memoryStorage();
const upload = multer({ storage });

// Create HTTP server
const server = http.createServer(app);

// Initialize WebSocket server
const wss = new WebSocket.Server({ 
  server,
  path: '/ws'
});

// Track rooms and participants
const rooms = new Map();

// WebSocket connection handler
wss.on('connection', (ws) => {
  let roomId = null;
  let username = null;

  console.log('New WebSocket connection');

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      switch (data.type) {
        case 'join':
          handleJoin(ws, data);
          roomId = data.roomId;
          username = data.username;
          break;
        case 'leave':
          handleLeave(ws, data);
          break;
        case 'offer':
        case 'answer':
        case 'candidate':
          handleSignaling(ws, data);
          break;
        case 'chat':
          handleChat(ws, data);
          break;
        case 'tts':
          handleTTS(ws, data);
          break;
        default:
          console.log('Unknown message type:', data.type);
      }
    } catch (error) {
      console.error('Error handling WebSocket message:', error);
    }
  });

  ws.on('close', () => {
    // Clean up when a client disconnects
    if (roomId && username) {
      handleLeave(ws, { roomId, username });
    }
  });
});

// Handle client joining a room
function handleJoin(ws, data) {
  const { roomId, username } = data;
  
  // Create room if it doesn't exist
  if (!rooms.has(roomId)) {
    rooms.set(roomId, new Map());
  }
  
  // Add user to room
  const room = rooms.get(roomId);
  room.set(ws, username);
  
  console.log(`User ${username} joined room ${roomId}`);
  
  // Send joined confirmation
  ws.send(JSON.stringify({
    type: 'joined',
    roomId,
    username,
    timestamp: Date.now()
  }));
  
  // Update all clients with new participant list
  updateParticipants(roomId);
}

// Handle client leaving a room
function handleLeave(ws, data) {
  const { roomId, username } = data;
  
  if (!rooms.has(roomId)) {
    return;
  }
  
  // Remove user from room
  const room = rooms.get(roomId);
  room.delete(ws);
  
  console.log(`User ${username} left room ${roomId}`);
  
  // Remove room if empty
  if (room.size === 0) {
    rooms.delete(roomId);
    console.log(`Room ${roomId} deleted (no participants)`);
  } else {
    // Update all clients with new participant list
    updateParticipants(roomId);
    
    // Notify others that user left
    broadcastToRoom(roomId, {
      type: 'leave',
      roomId,
      username,
      timestamp: Date.now()
    }, ws); // Exclude the leaving client
  }
}

// Handle WebRTC signaling messages
function handleSignaling(ws, data) {
  const { roomId } = data;
  
  if (!rooms.has(roomId)) {
    return;
  }
  
  // Forward the signaling message to all other clients in the room
  broadcastToRoom(roomId, data, ws); // Exclude sender
}

// Handle chat messages
function handleChat(ws, data) {
  const { roomId, username, text } = data;
  
  if (!rooms.has(roomId)) {
    return;
  }
  
  console.log(`Chat message in ${roomId} from ${username}: ${text}`);
  
  // Forward the chat message to all clients in the room
  broadcastToRoom(roomId, {
    type: 'chat',
    roomId,
    sender: username,
    text,
    timestamp: Date.now()
  });
}

// Handle TTS requests
function handleTTS(ws, data) {
  const { roomId, username, text } = data;
  
  if (!rooms.has(roomId)) {
    return;
  }
  
  console.log(`TTS message in ${roomId} from ${username}: ${text}`);
  
  // Forward the TTS message to all clients in the room
  broadcastToRoom(roomId, {
    type: 'tts',
    roomId,
    sender: username,
    text,
    timestamp: Date.now()
  });
}

// Update all clients in a room with the current participant list
function updateParticipants(roomId) {
  if (!rooms.has(roomId)) {
    return;
  }
  
  const room = rooms.get(roomId);
  const participants = Array.from(room.values());
  
  // Send updated participant list to all clients in the room
  broadcastToRoom(roomId, {
    type: 'participants',
    roomId,
    participants,
    timestamp: Date.now()
  });
}

// Broadcast a message to all clients in a room
function broadcastToRoom(roomId, message, excludeWs = null) {
  if (!rooms.has(roomId)) {
    return;
  }
  
  const room = rooms.get(roomId);
  const messageStr = JSON.stringify(message);
  
  room.forEach((username, ws) => {
    if (ws !== excludeWs && ws.readyState === WebSocket.OPEN) {
      ws.send(messageStr);
    }
  });
}

// API route for Text-to-Speech
app.post('/api/tts', async (req, res) => {
  try {
    const { text } = req.body;
    
    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }
    
    // In a real implementation, this would call an external TTS API
    // For now, we're using a simple audio file as a placeholder
    console.log(`TTS request: "${text}"`);
    
    // Send placeholder audio (silence)
    const silenceBuffer = generateSilence(1, 44100);
    res.set('Content-Type', 'audio/wav');
    res.send(silenceBuffer);
  } catch (error) {
    console.error('Error handling TTS request:', error);
    res.status(500).json({ error: 'Failed to process TTS request' });
  }
});

// API route for Speech-to-Text
app.post('/api/stt', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Audio file is required' });
    }
    
    // In a real implementation, this would call an external STT API
    // For now, we're just returning dummy text
    console.log('STT request received, audio size:', req.file.size);
    
    // Send placeholder text
    res.json({ text: 'This is a placeholder transcription.' });
  } catch (error) {
    console.error('Error handling STT request:', error);
    res.status(500).json({ error: 'Failed to process STT request' });
  }
});

// Generate silence audio buffer (WAV format)
function generateSilence(durationSec, sampleRate = 44100) {
  const numChannels = 1;
  const bytesPerSample = 2; // 16-bit
  const blockAlign = numChannels * bytesPerSample;
  const numSamples = Math.floor(durationSec * sampleRate);
  const dataSize = numSamples * blockAlign;
  
  const buffer = Buffer.alloc(44 + dataSize);
  
  // WAV header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // format chunk size
  buffer.writeUInt16LE(1, 20); // PCM format
  buffer.writeUInt16LE(numChannels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * blockAlign, 28); // byte rate
  buffer.writeUInt16LE(blockAlign, 32);
  buffer.writeUInt16LE(8 * bytesPerSample, 34); // bits per sample
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);
  
  // Silent audio data (all zeros)
  // Buffer is initialized with zeros, so no need to write anything
  
  return buffer;
}

// Serve static files from the public directory
app.use(express.static(path.join(__dirname, 'public')));

// Serve Flutter web app (for production)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Handle the root route with support for room sharing parameters
app.get("/", (req, res) => {
  const roomId = req.query.room;
  if (roomId) {
    console.log(`User joining via shared link to room: ${roomId}`);
    
    // Check if room exists in active rooms
    const roomExists = rooms.has(roomId);
    if (roomExists) {
      console.log(`Room ${roomId} exists with ${rooms.get(roomId).participants.size} participants`);
    } else {
      console.log(`Room ${roomId} does not exist yet, will be created when user joins`);
    }
  }
  
  // In all cases, serve the index.html file
  // The query parameters will be passed to the client
  res.sendFile(path.join(__dirname, "public/index.html"));
});

// Start the server
server.listen(PORT, () => {
  console.log(`HearAll server is running on http://localhost:${PORT}`);
});
