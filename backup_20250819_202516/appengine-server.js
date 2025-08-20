// Combined server for App Engine deployment
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

// Initialize Express app
const express = require('express');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');

// Import main server
const mainApp = express();
const mainServer = http.createServer(mainApp);

// Add node-fetch if not available natively
let fetch;
try {
  fetch = global.fetch;
} catch (e) {
  // If global.fetch is not available, use node-fetch v2 (CommonJS compatible)
  try {
    // First try CommonJS-compatible node-fetch (v2)
    const nodeFetch = require('node-fetch');
    fetch = nodeFetch;
  } catch (fetchErr) {
    console.warn('Error importing node-fetch via require:', fetchErr.message);
    console.warn('Will use dynamic import for node-fetch when needed');
    // Set up dynamic import function to use when fetch is called
    fetch = async (...args) => {
      const { default: nodeFetch } = await import('node-fetch');
      return nodeFetch(...args);
    };
  }
}

// Main server configuration (copied from index.cjs)
const PORT = process.env.PORT || 8080; // App Engine uses 8080
const CHAT_PORT = process.env.CHAT_PORT || 3001;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const DEFAULT_MODEL = process.env.MODEL || 'gpt-4o-realtime-preview-2024-12-17';
const LOG_DIR = path.join(__dirname, 'logs');

// Set up CORS for main app
mainApp.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

mainApp.use(express.json({ limit: '5mb' }));

// Create log directory if it doesn't exist
const fs = require('fs');
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR);
}

// Set up upload handling for audio files
const multer = require('multer');
const storage = multer.memoryStorage();
const upload = multer({ storage });
const sttUpload = multer({ storage }).fields([{ name: 'file' }, { name: 'audio' }]);
const https = require('https');

// Serve static files from public directory
mainApp.use(express.static(path.join(__dirname, 'public')));

// Initialize WebSocket server for main app
const wss = new WebSocket.Server({ 
  server: mainServer,
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

// Create chat server WebSocket
const chatWss = new WebSocket.Server({ 
  server: mainServer,
  path: '/chat'
});

// Chat server state
const sessions = {};
const userRooms = {};

// Chat server WebSocket handler
chatWss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  const sessionId = url.searchParams.get('sessionId');
  
  if (!sessionId) {
    console.log('Connection rejected - missing sessionId');
    ws.close(4000, 'Missing sessionId parameter');
    return;
  }
  
  console.log(`New chat connection for session: ${sessionId}`);
  
  // Initialize session if it doesn't exist
  if (!sessions[sessionId]) {
    sessions[sessionId] = {
      users: new Map(),
      rooms: new Set(),
    };
  }
  
  const clientId = Math.random().toString(36).substring(2, 10);
  
  // Add to session
  sessions[sessionId].users.set(clientId, {
    ws,
    room: null,
    name: null,
  });
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      switch (data.type) {
        case 'join':
          handleChatJoin(sessionId, clientId, data, ws);
          break;
        case 'leave':
          handleChatLeave(sessionId, clientId, data);
          break;
        case 'message':
          handleChatMessage(sessionId, clientId, data);
          break;
        case 'typing':
          handleTypingStatus(sessionId, clientId, data);
          break;
        default:
          console.log(`Unknown chat message type: ${data.type}`);
      }
    } catch (error) {
      console.error('Error handling chat message:', error);
    }
  });
  
  ws.on('close', () => {
    handleClientDisconnect(sessionId, clientId);
  });
  
  // Send confirmation
  ws.send(JSON.stringify({
    type: 'connected',
    clientId,
    timestamp: new Date().toISOString(),
  }));
});

// Main server handlers (implement these based on your existing code)
function handleJoin(ws, data) {
  // Implementation from your index.cjs
  console.log(`User ${data.username} joined room ${data.roomId}`);
  // Add implementation here
}

function handleLeave(ws, data) {
  // Implementation from your index.cjs
  console.log(`User ${data.username} left room ${data.roomId}`);
  // Add implementation here
}

function handleSignaling(ws, data) {
  // Implementation from your index.cjs
  // Add implementation here
}

function handleChat(ws, data) {
  // Implementation from your index.cjs
  // Add implementation here
}

function handleTTS(ws, data) {
  // Implementation from your index.cjs
  // Add implementation here
}

// Chat server handlers (implement these based on your ephemeral-chat-server.js)
function handleChatJoin(sessionId, clientId, data, ws) {
  // Implementation from your ephemeral-chat-server.js
  console.log(`Client ${clientId} joining room ${data.room} as ${data.name}`);
  // Add implementation here
}

function handleChatLeave(sessionId, clientId, data) {
  // Implementation from your ephemeral-chat-server.js
  // Add implementation here
}

function handleChatMessage(sessionId, clientId, data) {
  // Implementation from your ephemeral-chat-server.js
  // Add implementation here
}

function handleTypingStatus(sessionId, clientId, data) {
  // Implementation from your ephemeral-chat-server.js
  // Add implementation here
}

function handleClientDisconnect(sessionId, clientId) {
  // Implementation from your ephemeral-chat-server.js
  console.log(`Client ${clientId} disconnected from session ${sessionId}`);
  // Add implementation here
}

function broadcastToRoom(sessionId, message) {
  // Implementation from your ephemeral-chat-server.js
  // Add implementation here
}

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

// API Routes

// Health check endpoint
mainApp.get('/api/health', (req, res) => {
  const healthData = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
    api: {
      version: '1.0.0',
    },
  };
  res.json(healthData);
});

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

// WebRTC Realtime offer endpoint - FIXED VERSION
mainApp.post('/offer', express.json({ limit: '5mb' }), async (req, res) => {
  try {
    console.log('[webrtc] Processing offer request');
    const offerSdp = req.body && req.body.sdp;
    const model = (req.body && req.body.model) || DEFAULT_MODEL;

    // Validate API key
    if (!OPENAI_API_KEY) {
      console.error('[webrtc] Missing OPENAI_API_KEY');
      return res.status(500).json({ error: 'server_not_configured', detail: 'Missing OPENAI_API_KEY' });
    }

    // Validate SDP
    if (!offerSdp || typeof offerSdp !== 'string') {
      console.error('[webrtc] Missing or invalid SDP in request');
      return res.status(400).json({ error: 'missing_or_invalid_sdp', detail: 'SDP must be a string' });
    }

    if (!offerSdp.trim().startsWith('v=')) {
      console.error('[webrtc] Invalid SDP format - does not start with v=');
      console.log('[webrtc] SDP content (first 50 chars):', offerSdp.substring(0, 50));
      return res.status(400).json({ error: 'invalid_sdp_format', detail: 'SDP must start with v=' });
    }

    console.log('[webrtc] Valid SDP received, calling OpenAI Realtime API...');

    // Call OpenAI Realtime API with correct endpoint and headers
    let apiResponse;
    try {
      apiResponse = await fetch('https://api.openai.com/v1/realtime/sessions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
          'Content-Type': 'application/json',
          'OpenAI-Beta': 'realtime=v1'
        },
        body: JSON.stringify({
          model: model,
          voice: 'alloy',
          instructions: 'You are a helpful AI assistant.',
          input_audio_transcription: {
            model: 'whisper-1'
          },
          sdp: offerSdp
        })
      });
    } catch (fetchError) {
      console.error('[webrtc] Fetch error calling OpenAI API:', fetchError.message);
      return res.status(502).json({ 
        error: 'api_connection_failed', 
        detail: `Failed to connect to OpenAI API: ${fetchError.message}` 
      });
    }

    if (!apiResponse.ok) {
      const errorData = await apiResponse.text();
      console.error('[webrtc] OpenAI API error:', apiResponse.status, errorData);
      return res.status(apiResponse.status).json({ 
        error: 'openai_api_error', 
        detail: errorData 
      });
    }

    const responseData = await apiResponse.json();
    console.log('[webrtc] Got response from OpenAI Realtime API');

    // Extract the answer SDP from the response
    const answerSdp = responseData.sdp || responseData.session_sdp || responseData.answer;
    
    if (!answerSdp) {
      console.error('[webrtc] No SDP in OpenAI response:', responseData);
      return res.status(500).json({ 
        error: 'no_sdp_in_response', 
        detail: 'OpenAI API did not return SDP data' 
      });
    }

    // CRITICAL FIX: Return raw SDP text with correct Content-Type
    console.log('[webrtc] Returning SDP answer (length:', answerSdp.length, ')');
    res.setHeader('Content-Type', 'text/plain');
    res.send(answerSdp);

  } catch (error) {
    console.error('[webrtc] Server error:', error);
    return res.status(500).json({ 
      error: 'internal_server_error', 
      detail: error.message 
    });
  }
});

// Provide a friendly response for accidental GETs to /offer
mainApp.get('/offer', (req, res) => {
  res.status(405).json({ error: 'method_not_allowed', detail: 'Use POST /offer with JSON body { sdp, model? }' });
});

// Text-to-speech endpoint
mainApp.post('/api/tts', express.json(), async (req, res) => {
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

// Speech-to-text endpoint
mainApp.post('/api/stt', sttUpload, async (req, res) => {
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

// Catch-all handler to serve the Flutter app
mainApp.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start the combined server
mainServer.listen(PORT, () => {
  console.log(`Combined HearAll server is running on http://localhost:${PORT}`);
  console.log(`Routes: POST /offer (SDP handshake), POST /api/tts, POST /api/stt`);
  console.log(`Chat WebSocket: ws://localhost:${PORT}/chat?sessionId=YOUR_SESSION_ID`);
  console.log(`Health: GET http://localhost:${PORT}/api/health`);
});
