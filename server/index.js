// server/index.js
import express from "express";
import cors from "cors";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const PORT = process.env.PORT || 3000;
const DEFAULT_MODEL = process.env.MODEL || "gpt-4o-realtime-preview-2024-12-17";

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
      console.log("Using voice: alloy (default for TTS)");
      
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
          
          send(data) {
            try {
              if (typeof data === 'string') {
                const parsed = JSON.parse(data);
                if (parsed.type === 'conversation.item.create') {
                  console.log("TTS REQUEST SENT:", JSON.stringify(parsed));
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

// Optional: a lightweight health route & static serve of flutter web dev build folder
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public/index.html"));
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server listening on all interfaces on port ${PORT}`);
  console.log(`Server address: ${JSON.stringify(server.address())}`);
});
