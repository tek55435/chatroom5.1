// server/index.js
import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import https from "https";
import multer from "multer";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Explicitly configure dotenv to use the server/.env file
dotenv.config({ path: path.join(__dirname, ".env") });

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const PORT = process.env.PORT || 8080;
const DEFAULT_MODEL = process.env.MODEL || "gpt-4o-realtime-preview-2024-12-17";
const DEFAULT_VOICE = process.env.VOICE || "alloy";

if (!OPENAI_API_KEY) {
  console.error("Missing OPENAI_API_KEY in server/.env — create server/.env from .env.example");
  process.exit(1);
}

const app = express();
// Add detailed CORS configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));
app.use(express.json({ limit: "5mb" })); // for any JSON endpoints
app.use(express.static(path.join(__dirname, "public"))); // serve Flutter web build from public folder

// Set up multer for handling multipart form data (for STT)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max file size
  }
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

// POST /offer
// Accepts JSON { sdp: "<offer.sdp>", model?: "<model>" }
// Creates ephemeral session, posts offer to OpenAI Realtime using ephemeral token,
// returns raw answer SDP as text (Content-Type: application/sdp).
app.post("/offer", async (req, res) => {
  console.log("Received POST to /offer");
  console.log("Headers:", JSON.stringify(req.headers));
  
  try {
    console.log("Request body:", JSON.stringify(req.body));
    const offerSdp = req.body?.sdp;
  const model = req.body?.model || DEFAULT_MODEL;
    console.log("Using model:", model);
    
    // Check if the offer includes audio capabilities
    if (offerSdp.includes("m=audio")) {
      console.log("Offer includes audio capabilities");
      
      // Check the voice property being used
  console.log(`Using voice: ${DEFAULT_VOICE} (default)`);
      
      // Audio format checking
      if (offerSdp.includes("opus/48000/2")) {
        console.log("Client supports Opus codec at 48kHz stereo");
      }
      
      // Detailed codec reporting for debugging
      const codecMatch = offerSdp.match(/a=rtpmap:(\d+) ([a-zA-Z0-9/]+)/g);
      if (codecMatch) {
        console.log("Audio codecs found in offer:");
        codecMatch.forEach(codec => console.log(` - ${codec}`));
      }
      
      // Check for PCM-specific formats
      if (offerSdp.includes("PCMA") || offerSdp.includes("PCMU")) {
        console.log("Client supports PCM audio formats");
      }
      
      // TTS voice config
      console.log("TTS config: Using 'alloy' voice with 24kHz PCM16 mono output");
      
      // Debug hook for inspecting TTS messages
      process.on('uncaughtException', (err) => {
        console.error('Uncaught exception:', err);
      });
      
      // Add WebSocket debug logging
      const originalWebSocket = global.WebSocket;
      if (originalWebSocket) {
        console.log("Adding WebSocket debugging hooks");
        class DebugWebSocket extends originalWebSocket {
          constructor(...args) {
            console.log("WebSocket created with:", args[0]);
            super(...args);
            
            this.addEventListener('open', () => {
              console.log("WebSocket CONNECTED");
            });
            
            this.addEventListener('message', (event) => {
              try {
                if (typeof event.data === 'string') {
                  const data = JSON.parse(event.data);
                  console.log("WebSocket received message type:", data.type);
                  
                  // Check for TTS related messages
                  if (data.type === 'conversation.item.create' || 
                      data.type === 'audio.chunk' || 
                      data.type === 'tts.request' ||  // Add explicit TTS request type
                      data.type.startsWith('transcript')) {
                    console.log("TTS/Audio message:", data.type, data);
                  }
                } else {
                  console.log("WebSocket received binary data", event.data.length);
                }
              } catch (e) {
                console.log("WebSocket message (not JSON):", typeof event.data);
              }
            });
            
            this.addEventListener('close', (event) => {
              console.log(`WebSocket CLOSED: code=${event.code}, reason=${event.reason}`);
            });
            
            this.addEventListener('error', () => {
              console.error("WebSocket ERROR");
            });
          }
          
          async send(data) {
            try {
              if (typeof data === 'string') {
                const parsed = JSON.parse(data);
                // Handle different types of messages
                if (parsed.type === 'conversation.item.create') {
                  console.log("Conversation message sent:", JSON.stringify(parsed));
                }
                
                // Handle explicit TTS request
                if (parsed.type === 'tts.request') {
                  console.log("!!! EXPLICIT TTS REQUEST RECEIVED !!!:", JSON.stringify(parsed));
                  
                  // Extract text and voice
                  const text = parsed.text || "";
                  const voice = parsed.voice || "alloy";
                  
                  if (text) {
                    // Generate TTS audio
                    try {
                      const audioBuffer = await makeTTSRequest(text, voice);
                      console.log(`Generated TTS audio: ${audioBuffer.length} bytes`);
                      
                      // Convert to base64
                      const base64Audio = audioBuffer.toString('base64');
                      
                      // Send audio chunk response
                      const response = {
                        type: 'audio.chunk',
                        chunk: {
                          bytes: base64Audio,
                          format: 'mp3'
                        }
                      };
                      
                      // Send the audio back through the WebSocket
                      super.send(JSON.stringify(response));
                      console.log("TTS response sent with audio chunk");
                    } catch (error) {
                      console.error("Error generating TTS:", error);
                      // Send error message
                      const errorMsg = {
                        type: 'error',
                        message: 'Failed to generate speech'
                      };
                      super.send(JSON.stringify(errorMsg));
                    }
                    
                    // Don't forward tts.request messages to OpenAI
                    return;
                  }
                }
              }
            } catch (e) {
              // Not JSON or other error
            }
            super.send(data);
          }
        }
        
        global.WebSocket = DebugWebSocket;
      } else {
        console.log("WebSocket not available globally");
      }
      
      // Add interceptors for debugging WebRTC data
      const originalFetch = global.fetch;
      global.fetch = async function(...args) {
        const url = args[0].toString();
        if (url.includes('openai.com/v1/realtime')) {
          console.log('Intercepted OpenAI Realtime API call');
          try {
            const response = await originalFetch(...args);
            console.log('OpenAI Realtime API response status:', response.status);
            return response;
          } catch (error) {
            console.error('Error in OpenAI Realtime API call:', error);
            throw error;
          }
        } else {
          return originalFetch(...args);
        }
      };
    } else {
      console.warn("WARNING: Offer does not include audio capabilities!");
    }

    if (!offerSdp || typeof offerSdp !== "string") {
      return res.status(400).json({ error: "missing offer.sdp in body" });
    }

    // 1) Create ephemeral session
    console.log("Creating ephemeral session with OpenAI Realtime API");
    console.log("API Key (first few chars):", OPENAI_API_KEY.substring(0, 10) + "...");

    const sessResp = await fetch("https://api.openai.com/v1/realtime/sessions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      // Create session with supported fields only
      body: JSON.stringify({
        model,
        voice: DEFAULT_VOICE
      })
    });

    const sessText = await sessResp.text();
    console.log("Session API status:", sessResp.status);
    
    if (!sessResp.ok) {
      console.error("Failed to create ephemeral session:", sessResp.status, sessText);
      return res.status(502).json({ error: "Failed to create ephemeral session", detail: sessText });
    }
    
    console.log("Session API response:", sessText.substring(0, 100) + "...");
    
    let sessJson;
    try {
      sessJson = JSON.parse(sessText);
    } catch (e) {
      console.error("Session returned non-json:", sessText);
      return res.status(502).json({ error: "Session returned non-json", detail: sessText });
    }

    const ephemeral = sessJson?.client_secret?.value;
    if (!ephemeral) {
      console.error("No ephemeral token in session response:", sessJson);
      return res.status(502).json({ error: "No ephemeral token returned", detail: sessJson });
    }

    // 2) Post offer SDP to OpenAI Realtime with ephemeral token
    const realtimeUrl = `https://api.openai.com/v1/realtime?model=${encodeURIComponent(model)}`;
    console.log("Sending SDP to OpenAI Realtime:", realtimeUrl);

    const realtimeResp = await fetch(realtimeUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${ephemeral}`,
        "Content-Type": "application/sdp"
      },
      body: offerSdp
    });

    const realtimeText = await realtimeResp.text();
    console.log("Realtime API status:", realtimeResp.status);
    
    if (!realtimeResp.ok) {
      console.error("OpenAI Realtime handshake failed:", realtimeResp.status, realtimeText);
      // Wrap upstream error for client visibility
      try {
        const json = JSON.parse(realtimeText);
        return res.status(502).json({ error: "realtime-handshake-failed", detail: json });
      } catch (_) {
        return res.status(502).json({ error: "realtime-handshake-failed", detail: realtimeText });
      }
    }

    console.log("Realtime API response (first 100 chars):", realtimeText.substring(0, 100) + "...");
    
    // Return raw SDP answer (plain text) with content-type application/sdp
    res.setHeader("Content-Type", "application/sdp");
    res.status(200).send(realtimeText);
  } catch (err) {
    console.error("/offer error", err);
    res.status(500).json({ error: "internal", detail: String(err) });
  }
});

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

// Optional: a lightweight health route & static serve of flutter web dev build folder
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public/index.html"));
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on all interfaces on port ${PORT}`);
  console.log(`Server address: ${JSON.stringify(server.address())}`);
  console.log(`TTS API available at: http://localhost:${PORT}/api/tts`);
  console.log(`STT API available at: http://localhost:${PORT}/api/stt`);
});
