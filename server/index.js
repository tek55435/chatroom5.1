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

// Force-load environment from server/.env regardless of CWD
dotenv.config({ path: path.join(__dirname, ".env") });

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const PORT = process.env.PORT || 3000;
const DEFAULT_MODEL = process.env.MODEL || "gpt-4o-realtime-preview-2024-12-17";

if (!OPENAI_API_KEY) {
  console.error("Missing OPENAI_API_KEY in server/.env — create server/.env and set OPENAI_API_KEY");
  // Fail fast so we don't run without credentials
  process.exit(1);
}

const app = express();

// Set up multer for handling multipart form data (for STT)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max file size
  }
});

// Add detailed CORS configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));
app.use(express.json({ limit: "5mb" })); // for any JSON endpoints
app.use(express.static(path.join(__dirname, "public"))); // serve Flutter web build from public folder

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
      body: JSON.stringify({ model })
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
      return res.status(502).send(realtimeText);
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

// Friendly response for accidental GETs to /offer
app.get("/offer", (req, res) => {
  res.status(405).json({ error: "method_not_allowed", detail: "Use POST /offer with JSON body { sdp, model? }" });
});

// Optional: a lightweight health route & static serve of flutter web dev build folder
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public/index.html"));
});

// Function to make TTS request to OpenAI API
async function makeTTSRequest(text, voice = 'alloy') {
  const postData = JSON.stringify({
    model: 'tts-1',
    input: text,
    voice: voice,
    response_format: 'mp3'
  });

  const options = {
    hostname: 'api.openai.com',
    port: 443,
    path: '/v1/audio/speech',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      
      res.on('data', (chunk) => {
        chunks.push(chunk);
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          const audioBuffer = Buffer.concat(chunks);
          resolve(audioBuffer);
        } else {
          reject(new Error(`TTS API returned status ${res.statusCode}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

// Function to make STT request to OpenAI API
async function makeSTTRequest(audioBuffer, mimetype = 'audio/webm', filename = 'recording.webm', { language = 'en', temperature = 0, prompt } = {}) {
  return new Promise((resolve, reject) => {
    const boundary = '----formdata-boundary-' + Math.random().toString(36);
    
    const parts = [];
    
    // Add file part
    parts.push(Buffer.from(`--${boundary}\r\n`));
    parts.push(Buffer.from(`Content-Disposition: form-data; name="file"; filename="${filename}"\r\n`));
    parts.push(Buffer.from(`Content-Type: ${mimetype}\r\n\r\n`));
    parts.push(audioBuffer);
    parts.push(Buffer.from('\r\n'));
    
    // Add model part
    parts.push(Buffer.from(`--${boundary}\r\n`));
    parts.push(Buffer.from('Content-Disposition: form-data; name="model"\r\n\r\n'));
    parts.push(Buffer.from('whisper-1\r\n'));
    
    // Add language part
    parts.push(Buffer.from(`--${boundary}\r\n`));
    parts.push(Buffer.from('Content-Disposition: form-data; name="language"\r\n\r\n'));
    parts.push(Buffer.from(`${language}\r\n`));
    
    // Add temperature part
    parts.push(Buffer.from(`--${boundary}\r\n`));
    parts.push(Buffer.from('Content-Disposition: form-data; name="temperature"\r\n\r\n'));
    parts.push(Buffer.from(`${temperature}\r\n`));
    
    // Add prompt part if provided
    if (prompt) {
      parts.push(Buffer.from(`--${boundary}\r\n`));
      parts.push(Buffer.from('Content-Disposition: form-data; name="prompt"\r\n\r\n'));
      parts.push(Buffer.from(`${prompt}\r\n`));
    }
    
    // End boundary
    parts.push(Buffer.from(`--${boundary}--\r\n`));
    
    const postData = Buffer.concat(parts);
    
    const options = {
      hostname: 'api.openai.com',
      port: 443,
      path: '/v1/audio/transcriptions',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Content-Length': postData.length
      }
    };
    
    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const result = JSON.parse(data);
            resolve(result.text || '');
          } catch (parseError) {
            reject(new Error(`Failed to parse STT response: ${parseError.message}`));
          }
        } else {
          reject(new Error(`STT API returned status ${res.statusCode}: ${data}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.write(postData);
    req.end();
  });
}

// Text-to-speech endpoint
app.post("/api/tts", async (req, res) => {
  console.log("Received TTS request");
  console.log("Request body:", req.body);
  
  try {
    const { text, voice } = req.body;
    
    if (!text) {
      return res.status(400).json({ error: "Text is required" });
    }
    
    console.log(`Processing TTS request for text: "${text}"`);
    const audioBuffer = await makeTTSRequest(text, voice || 'alloy');
    console.log(`TTS response received: ${audioBuffer.length} bytes of MP3 audio`);
    
    res.set({
      'Content-Type': 'audio/mpeg',
      'Content-Length': audioBuffer.length
    });
    
    res.send(audioBuffer);
  } catch (error) {
    console.error('Error with TTS API:', error);
    res.status(500).json({ error: 'Failed to generate speech' });
  }
});

// Speech-to-text endpoint
app.post("/api/stt", upload.single('file'), async (req, res) => {
  console.log("Received STT request");
  console.log("File info:", req.file ? {
    fieldname: req.file.fieldname,
    originalname: req.file.originalname,
    mimetype: req.file.mimetype,
    size: req.file.buffer.length
  } : "No file");
  
  try {
    if (!req.file) {
      return res.status(400).json({ error: "No audio file provided" });
    }
    
    console.log(`Processing STT request: ${req.file.buffer.length} bytes of audio data`);
    
    const { language = 'en', temperature = 0, prompt } = req.body;
    const { mimetype, originalname } = req.file;
    
    console.log('STT options => language:', language, 'temperature:', temperature, 'prompt:', prompt ? '[provided]' : 'none');
    const transcriptionResult = await makeSTTRequest(req.file.buffer, mimetype, originalname, { language, temperature, prompt });
    console.log('STT response received:', transcriptionResult);
    
    res.json({ text: transcriptionResult });
  } catch (error) {
    console.error('Error with STT API:', error);
    res.status(500).json({ error: 'Failed to transcribe audio' });
  }
});

// Health check endpoint to verify env and basic config
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    openaiKeyPresent: Boolean(process.env.OPENAI_API_KEY),
    model: DEFAULT_MODEL,
    port: Number(PORT),
    timestamp: Date.now(),
  });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
  console.log(`Health: GET http://localhost:${PORT}/api/health`);
  console.log(`TTS API available at: http://localhost:${PORT}/api/tts`);
  console.log(`STT API available at: http://localhost:${PORT}/api/stt`);
});
