// server.js
import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import https from "https";
import multer from "multer";
import { WebSocketServer } from 'ws';
import { createServer } from 'http';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configure dotenv
dotenv.config({ path: path.join(__dirname, ".env") });

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const PORT = process.env.PORT || 3000;
const DEFAULT_MODEL = process.env.MODEL || "gpt-4o-realtime-preview-2024-12-17";

if (!OPENAI_API_KEY) {
  console.error("Missing OPENAI_API_KEY in server/.env — create server/.env from .env.example");
  process.exit(1);
}

const app = express();
const server = createServer(app);

// Set up multer for handling multipart form data (for STT)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max file size
  }
});

// CORS configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

app.use(express.json({ limit: "5mb" }));
app.use(express.static(path.join(__dirname, "public"), {
  setHeaders: (res, path) => {
    if (path.endsWith('.js')) {
      res.set('Content-Type', 'application/javascript');
    }
  }
}));

// Create WebSocket server
const wss = new WebSocketServer({ 
  server,
  path: '/webrtc'
});

// Keep track of rooms and connections
const rooms = new Map();

wss.on('connection', (ws) => {
  let userRoom = null;
  let userName = null;

  console.log('New WebSocket connection');

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Received:', data);
      
      switch (data.type) {
        case 'join':
          userRoom = data.room;
          userName = data.user;
          
          // Create room if it doesn't exist
          if (!rooms.has(userRoom)) {
            rooms.set(userRoom, new Map());
          }
          
          // Add user to room
          rooms.get(userRoom).set(userName, ws);
          
          console.log(`User ${userName} joined room ${userRoom}`);
          
          // Notify others in room
          rooms.get(userRoom).forEach((client, user) => {
            if (user !== userName) {
              client.send(JSON.stringify({
                type: 'user-joined',
                user: userName
              }));
            }
          });
          break;
          
        case 'leave':
          if (userRoom && userName) {
            const room = rooms.get(userRoom);
            if (room) {
              room.delete(userName);
              if (room.size === 0) {
                rooms.delete(userRoom);
              } else {
                // Notify others
                room.forEach((client) => {
                  client.send(JSON.stringify({
                    type: 'leave',
                    user: userName
                  }));
                });
              }
            }
          }
          break;
          
        case 'offer':
        case 'answer':
        case 'ice-candidate':
          if (userRoom && data.target) {
            const room = rooms.get(userRoom);
            const targetWs = room?.get(data.target);
            if (targetWs) {
              targetWs.send(JSON.stringify({
                ...data,
                user: userName
              }));
            }
          }
          break;
          
        case 'message':
          if (userRoom) {
            const room = rooms.get(userRoom);
            room?.forEach((client, user) => {
              if (user !== userName) {
                client.send(JSON.stringify({
                  type: 'message',
                  user: userName,
                  data: data.data
                }));
              }
            });
          }
          break;
      }
    } catch (error) {
      console.error('WebSocket message error:', error);
      ws.send(JSON.stringify({
        type: 'error',
        data: 'Invalid message format'
      }));
    }
  });

  ws.on('close', () => {
    console.log('Client disconnected');
    if (userRoom && userName) {
      const room = rooms.get(userRoom);
      if (room) {
        room.delete(userName);
        if (room.size === 0) {
          rooms.delete(userRoom);
        } else {
          // Notify others
          room.forEach((client) => {
            client.send(JSON.stringify({
              type: 'leave',
              user: userName
            }));
          });
        }
      }
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Function to make TTS request to OpenAI API
async function makeTTSRequest(text, voice = 'alloy') {
  return new Promise((resolve, reject) => {
    if (!OPENAI_API_KEY) {
      reject(new Error('OpenAI API key not set. Please set the OPENAI_API_KEY environment variable.'));
      return;
    }
    
    const requestData = JSON.stringify({
      model: 'tts-1',
      input: text,
      voice: voice, // Can be 'alloy', 'echo', 'fable', 'onyx', 'nova', or 'shimmer'
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
        'Content-Length': requestData.length
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
      
      const chunks = [];
      res.on('data', (chunk) => {
        chunks.push(chunk);
      });
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        resolve(buffer);
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.write(requestData);
    req.end();
  });
}

// Function to make STT request to OpenAI API
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

// Text-to-speech endpoint
app.post("/api/tts", async (req, res) => {
  console.log("Received TTS request");
  
  try {
    const { text, voice } = req.body;
    
    if (!text) {
      return res.status(400).json({ error: 'No text provided' });
    }
    
    console.log(`Processing TTS request for text: "${text}"`);
    const audioBuffer = await makeTTSRequest(text, voice || 'alloy');
    console.log(`TTS response received: ${audioBuffer.length} bytes of MP3 audio`);
    
    // Set proper headers for MP3 audio
    res.writeHead(200, {
      'Content-Type': 'audio/mpeg',
      'Content-Length': audioBuffer.length,
      'Cache-Control': 'no-cache'
    });
    res.end(audioBuffer);
  } catch (error) {
    console.error('Error with TTS API:', error);
    res.status(500).json({ error: error.message });
  }
});

// Speech-to-text endpoint
app.post("/api/stt", upload.single('file'), async (req, res) => {
  console.log("Received STT request");
  
  try {
    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ error: 'No audio file provided' });
    }
    
    console.log(`Processing STT request: ${req.file.buffer.length} bytes of audio data`);
    const mimetype = req.file.mimetype || 'application/octet-stream';
    const originalname = req.file.originalname || 'recording.webm';
    console.log('Client upload mimetype:', mimetype, 'filename:', originalname);
    const language = (req.body && req.body.language) || 'en';
    const temperature = (req.body && req.body.temperature) || 0;
    const prompt = (req.body && req.body.prompt) || undefined;
    console.log('STT options => language:', language, 'temperature:', temperature, 'prompt:', prompt ? '[provided]' : 'none');
    
    const transcriptionResult = await makeSTTRequest(req.file.buffer, mimetype, originalname, { language, temperature, prompt });
    console.log('STT response received:', transcriptionResult);
    
    res.status(200).json(transcriptionResult);
  } catch (error) {
    console.error('Error with STT API:', error);
    res.status(500).json({ error: error.message });
  }
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log('Server listening on all interfaces on port ' + PORT);
  console.log('Server address:', server.address());
  console.log('TTS API available at: http://localhost:' + PORT + '/api/tts');
  console.log('STT API available at: http://localhost:' + PORT + '/api/stt');
  console.log('WebSocket server available at: ws://localhost:' + PORT + '/webrtc');
});
