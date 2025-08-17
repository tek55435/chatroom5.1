// Standalone Ephemeral Chat WS server (copy of server/ephemeral-chat-server.js)
import { WebSocketServer } from 'ws';
import { v4 as uuidv4 } from 'uuid';
import { createServer } from 'http';
import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Constants
const PORT = process.env.PORT || 3001;
const SESSION_ID_LENGTH = 8;

// Express app setup
const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Create HTTP server
const server = createServer(app);

// WebSocket server setup
const wss = new WebSocketServer({ server });

// In-memory storage for chat rooms
const chatRooms = new Map(); // sessionId -> { clients: [], messages: [] }

// Generate a random numeric session ID
function generateSessionId() {
  let sessionId = '';
  for (let i = 0; i < SESSION_ID_LENGTH; i++) {
    sessionId += Math.floor(Math.random() * 10);
  }
  return sessionId;
}

// Handle WebSocket connections
wss.on('connection', (ws, req) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let sessionId = url.searchParams.get('sessionId');
  const clientId = uuidv4();
  
  if (!sessionId) {
    sessionId = generateSessionId();
    console.log(`Generated new session ID: ${sessionId}`);
  }
  
  ws.send(JSON.stringify({
    type: 'session',
    sessionId,
    clientId
  }));
  
  if (!chatRooms.has(sessionId)) {
    chatRooms.set(sessionId, {
      clients: new Map(),
      messages: []
    });
    console.log(`Created new chat room: ${sessionId}`);
  }
  
  const room = chatRooms.get(sessionId);
  
  room.clients.set(clientId, {
    ws,
    name: 'Guest',
    timestamp: Date.now()
  });
  
  console.log(`Client ${clientId} joined room ${sessionId} (${room.clients.size} clients)`);
  
  broadcastToRoom(sessionId, {
    type: 'system',
    message: `A new user joined the chat`,
    timestamp: Date.now()
  });
  
  if (room.messages.length > 0) {
    ws.send(JSON.stringify({
      type: 'history',
      messages: room.messages
    }));
  }
  
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);
      switch(message.type) {
        case 'chat':
          handleChatMessage(sessionId, clientId, message);
          break;
        case 'update-user':
          handleUserUpdate(sessionId, clientId, message);
          break;
        default:
          console.log(`Unknown message type: ${message.type}`);
      }
    } catch (err) {
      console.error(`Error processing message: ${err.message}`);
    }
  });
  
  ws.on('close', () => {
    handleClientDisconnect(sessionId, clientId);
  });
  
  ws.on('error', (error) => {
    console.error(`Client ${clientId} error: ${error.message}`);
  });
});

function handleChatMessage(sessionId, clientId, message) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const client = room.clients.get(clientId);
  if (!client) return;
  
  const chatMessage = {
    type: 'chat',
    clientId,
    sender: client.name,
    message: message.text,
    timestamp: Date.now()
  };
  
  room.messages.push(chatMessage);
  broadcastToRoom(sessionId, chatMessage);
  console.log(`Message from ${client.name} in room ${sessionId}: ${message.text}`);
}

function handleUserUpdate(sessionId, clientId, message) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const client = room.clients.get(clientId);
  if (!client) return;
  
  if (message.name && message.name !== client.name) {
    const oldName = client.name;
    client.name = message.name;
    broadcastToRoom(sessionId, {
      type: 'system',
      message: `"${oldName}" changed their name to "${message.name}"`,
      timestamp: Date.now()
    });
  }
  if (message.avatar) {
    client.avatar = message.avatar;
  }
}

function handleClientDisconnect(sessionId, clientId) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const client = room.clients.get(clientId);
  if (!client) return;
  
  room.clients.delete(clientId);
  console.log(`Client ${clientId} (${client.name}) left room ${sessionId} (${room.clients.size} clients remaining)`);
  
  broadcastToRoom(sessionId, {
    type: 'system',
    message: `${client.name} left the chat`,
    timestamp: Date.now()
  });
  
  if (room.clients.size === 0) {
    console.log(`Room ${sessionId} is now empty, deleting room and all messages`);
    chatRooms.delete(sessionId);
  }
}

function broadcastToRoom(sessionId, message) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const messageStr = JSON.stringify(message);
  
  room.clients.forEach((client) => {
    if (client.ws.readyState === 1) {
      client.ws.send(messageStr);
    }
  });
}

app.get('/api/chat/new-session', (req, res) => {
  const sessionId = generateSessionId();
  res.json({ sessionId });
});

app.get('/api/chat/session/:sessionId/active', (req, res) => {
  const { sessionId } = req.params;
  const isActive = chatRooms.has(sessionId);
  
  res.json({ 
    sessionId, 
    active: isActive,
    participants: isActive ? chatRooms.get(sessionId).clients.size : 0
  });
});

server.listen(PORT, () => {
  console.log(`Ephemeral Chat Server listening on port ${PORT}`);
  const scheme = PORT.toString() === '443' ? 'wss' : 'ws';
  console.log(`Connect via WebSocket: ${scheme}://localhost:${PORT}?sessionId=YOUR_SESSION_ID`);
});

export default server;
