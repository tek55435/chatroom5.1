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

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
