// HearAll Chat Server - Main entry point
// This server provides WebRTC signaling, STT/TTS APIs, and serves the Flutter web client

// Force-load environment from server/.env regardless of CWD
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const fs = require('fs');
const https = require('https');
const multer = require('multer');
const { promisify } = require('util');

// Configuration
const PORT = process.env.PORT || 3000;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const DEFAULT_MODEL = process.env.MODEL || 'gpt-4o-realtime-preview-2024-12-17';
const LOG_DIR = path.join(__dirname, 'logs');

// Create log directory if it doesn't exist
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR);
}

// Set up Express app
const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));
// Increase JSON body limit to allow large SDP blobs
app.use(express.json({ limit: '5mb' }));

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

// Helper: Call OpenAI TTS to synthesize speech (MP3)
function makeTTSRequest(text, voice = 'alloy') {
  return new Promise((resolve, reject) => {
    if (!OPENAI_API_KEY) {
      reject(new Error('OpenAI API key not set. Please set OPENAI_API_KEY in server/.env'));
      return;
    }

    const payload = JSON.stringify({
      model: 'tts-1',
      input: text,
      voice,
      response_format: 'mp3'
    });

    const options = {
      hostname: 'api.openai.com',
      port: 443,
      path: '/v1/audio/speech',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const req = https.request(options, (resp) => {
      const status = resp.statusCode || 500;
      if (status !== 200) {
        let errData = '';
        resp.on('data', (chunk) => { errData += chunk; });
        resp.on('end', () => reject(new Error(`OpenAI TTS ${status}: ${errData}`)));
        return;
      }
      const chunks = [];
      resp.on('data', (chunk) => chunks.push(chunk));
      resp.on('end', () => resolve(Buffer.concat(chunks)));
    });

    req.on('error', (e) => reject(e));
    req.write(payload);
    req.end();
  });
}

// API route for Text-to-Speech (real TTS via OpenAI)
app.post('/api/tts', async (req, res) => {
  try {
    const { text, voice } = req.body || {};
    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({ error: 'Text is required' });
    }
    const useVoice = typeof voice === 'string' && voice.trim() ? voice.trim() : 'alloy';
    console.log(`TTS request => length=${text.length}, voice=${useVoice}`);

    const audioBuffer = await makeTTSRequest(text, useVoice);
    console.log(`TTS ok => ${audioBuffer.length} bytes`);
    res.writeHead(200, {
      'Content-Type': 'audio/mpeg',
      'Content-Length': audioBuffer.length,
      'Cache-Control': 'no-cache'
    });
    res.end(audioBuffer);
  } catch (error) {
    console.error('Error handling TTS request:', error);
    res.status(502).json({ error: 'Failed to synthesize speech', detail: String(error && error.message ? error.message : error) });
  }
});

// WebRTC Realtime offer endpoint (restores /offer route)
// Accepts JSON { sdp: "<offer.sdp>", model?: "<model>" }
// Creates ephemeral session, posts offer to OpenAI Realtime using ephemeral token,
// returns raw answer SDP as text (Content-Type: application/sdp).
app.post('/offer', async (req, res) => {
  try {
    console.log('Received POST to /offer');
    const offerSdp = req.body && req.body.sdp;
    const model = (req.body && req.body.model) || DEFAULT_MODEL;

    if (!offerSdp || typeof offerSdp !== 'string') {
      return res.status(400).json({ error: 'missing offer.sdp in body' });
    }

    if (!OPENAI_API_KEY) {
      console.error('OPENAI_API_KEY is not set');
      return res.status(500).json({ error: 'server_not_configured', detail: 'Missing OPENAI_API_KEY' });
    }

    // 1) Create ephemeral session
    const sessResp = await fetch('https://api.openai.com/v1/realtime/sessions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ model })
    });

    const sessText = await sessResp.text();
    if (!sessResp.ok) {
      console.error('Failed to create ephemeral session:', sessResp.status, sessText);
      return res.status(502).json({ error: 'Failed to create ephemeral session', detail: sessText });
    }

    let sessJson;
    try {
      sessJson = JSON.parse(sessText);
    } catch (e) {
      console.error('Session returned non-json:', sessText);
      return res.status(502).json({ error: 'Session returned non-json', detail: sessText });
    }

    const ephemeral = sessJson && sessJson.client_secret && sessJson.client_secret.value;
    if (!ephemeral) {
      console.error('No ephemeral token in session response:', sessJson);
      return res.status(502).json({ error: 'No ephemeral token returned', detail: sessJson });
    }

    // 2) Post offer SDP to OpenAI Realtime with ephemeral token
    const realtimeUrl = `https://api.openai.com/v1/realtime?model=${encodeURIComponent(model)}`;
    const realtimeResp = await fetch(realtimeUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ephemeral}`,
        'Content-Type': 'application/sdp'
      },
      body: offerSdp
    });

    const realtimeText = await realtimeResp.text();
    if (!realtimeResp.ok) {
      console.error('OpenAI Realtime handshake failed:', realtimeResp.status, realtimeText);
      return res.status(502).send(realtimeText);
    }

    res.setHeader('Content-Type', 'application/sdp');
    return res.status(200).send(realtimeText);
  } catch (err) {
    console.error('/offer error', err);
    return res.status(500).json({ error: 'internal', detail: String(err && err.message ? err.message : err) });
  }
});

// Provide a friendly response for accidental GETs to /offer to avoid 404 confusion
app.get('/offer', (req, res) => {
  res.status(405).json({ error: 'method_not_allowed', detail: 'Use POST /offer with JSON body { sdp, model? }' });
});

// API route for Speech-to-Text (robust upload handling)
// Accepts multipart/form-data with field name 'file' or 'audio'
const sttUpload = multer({ storage }).fields([{ name: 'file' }, { name: 'audio' }]);
app.post('/api/stt', sttUpload, async (req, res) => {
  try {
    const ct = req.headers['content-type'];
    const cl = req.headers['content-length'];
    console.log('STT request headers => content-type:', ct, 'content-length:', cl);
    
    const file = (req.files && (req.files.file?.[0] || req.files.audio?.[0])) || null;
    if (!file) {
      console.warn('STT request missing file payload (expected field "file" or "audio")');
      return res.status(400).json({ error: 'Audio file is required (field "file" or "audio")' });
    }

    console.log('STT request received, audio size:', file.size, 'mimetype:', file.mimetype, 'originalname:', file.originalname);
    
    // Call OpenAI Whisper API for speech to text
    try {
      const language = (req.body && req.body.language) || 'en';
      const temperature = (req.body && req.body.temperature) || 0;
      const prompt = (req.body && req.body.prompt) || undefined;
      
      console.log('Processing STT with OpenAI => language:', language, 'temperature:', temperature, 'prompt:', prompt ? '[provided]' : 'none');
      
      const transcriptionResult = await makeSTTRequest(file.buffer, file.mimetype, file.originalname, { 
        language, 
        temperature, 
        prompt 
      });
      
      console.log('STT success, transcription:', transcriptionResult.text);
      res.json(transcriptionResult);
    } catch (sttError) {
      console.error('Error with STT API:', sttError);
      res.status(500).json({ error: sttError.message });
    }
  } catch (error) {
    console.error('Error handling STT request:', error);
    res.status(500).json({ error: 'Failed to process STT request' });
  }
});

// Function to make STT request to OpenAI Whisper API
async function makeSTTRequest(audioBuffer, mimetype = 'audio/webm', filename = 'recording.webm', { language = 'en', temperature = 0, prompt } = {}) {
  return new Promise((resolve, reject) => {
    if (!OPENAI_API_KEY) {
      reject(new Error('OpenAI API key not set. Please set the OPENAI_API_KEY environment variable.'));
      return;
    }
    
    // Boundary for multipart form data
    const boundary = `boundary_${Date.now().toString(16)}`;
    
    // Prepare form data parts
    const formParts = [
      `--${boundary}\r\n`,
      `Content-Disposition: form-data; name="file"; filename="${filename}"\r\n`,
      `Content-Type: ${mimetype}\r\n\r\n`
    ];
    
    // Add file data and closing boundary
    const parts = [];
    parts.push(Buffer.from(formParts.join('')));
    parts.push(audioBuffer);
    // model
    parts.push(Buffer.from(`\r\n--${boundary}\r\n`));
    parts.push(Buffer.from('Content-Disposition: form-data; name="model"\r\n\r\n'));
    parts.push(Buffer.from('whisper-1\r\n'));
    // language
    if (language) {
      parts.push(Buffer.from(`--${boundary}\r\n`));
      parts.push(Buffer.from('Content-Disposition: form-data; name="language"\r\n\r\n'));
      parts.push(Buffer.from(String(language) + '\r\n'));
    }
    // temperature
    parts.push(Buffer.from(`--${boundary}\r\n`));
    parts.push(Buffer.from('Content-Disposition: form-data; name="temperature"\r\n\r\n'));
    parts.push(Buffer.from(String(temperature) + '\r\n'));
    // prompt (optional)
    if (prompt) {
      parts.push(Buffer.from(`--${boundary}\r\n`));
      parts.push(Buffer.from('Content-Disposition: form-data; name="prompt"\r\n\r\n'));
      parts.push(Buffer.from(String(prompt) + '\r\n'));
    }
    // closing
    parts.push(Buffer.from(`--${boundary}--\r\n`));
    const requestBody = Buffer.concat(parts);
    
    const options = {
      hostname: 'api.openai.com',
      port: 443,
      path: '/v1/audio/transcriptions',
      method: 'POST',
      headers: {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Length': requestBody.length
      }
    };
    
    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        let errorData = '';
        res.on('data', (chunk) => {
          errorData += chunk;
        });
        res.on('end', () => {
          reject(new Error(`OpenAI API returned ${res.statusCode}: ${errorData}`));
        });
        return;
      }
      
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          const jsonResponse = JSON.parse(responseData);
          resolve(jsonResponse);
        } catch (error) {
          reject(new Error(`Failed to parse API response: ${error.message}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.write(requestBody);
    req.end();
  });
}

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

// Health check endpoint to verify env and basic config
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    openaiKeyPresent: Boolean(process.env.OPENAI_API_KEY),
    model: DEFAULT_MODEL,
    port: Number(PORT),
    timestamp: Date.now(),
  });
});

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
  console.log('Routes: POST /offer (SDP handshake), GET /offer (405 helper), POST /api/tts, POST /api/stt');
  console.log(`Health: GET http://localhost:${PORT}/api/health`);
});
