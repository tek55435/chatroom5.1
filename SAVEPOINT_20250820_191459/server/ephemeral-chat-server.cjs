// ephemeral-chat-server.cjs
const { WebSocketServer } = require('ws');
const { v4: uuidv4 } = require('uuid');
const { createServer } = require('http');
const express = require('express');
const cors = require('cors');
const path = require('path');

// Constants
const PORT = process.env.CHAT_PORT || 3001;
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
app.use(express.static(path.join(__dirname, "public")));

// Create HTTP server
const server = createServer(app);

// WebSocket server setup
const wss = new WebSocketServer({ server });

// In-memory storage for chat rooms
const chatRooms = new Map(); // sessionId -> { clients: [], messages: [] }

// Generate a random numeric session ID
function generateSessionId() {
  // Generate a random 8-digit number
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
  
  // If no session ID provided, generate one
  if (!sessionId) {
    sessionId = generateSessionId();
    console.log(`Generated new session ID: ${sessionId}`);
  }
  
  // Send the session ID back to the client
  ws.send(JSON.stringify({
    type: 'session',
    sessionId,
    clientId
  }));
  
  // Create a new room if it doesn't exist
  if (!chatRooms.has(sessionId)) {
    chatRooms.set(sessionId, {
      clients: new Map(),
      messages: []
    });
    console.log(`Created new chat room: ${sessionId}`);
  }
  
  const room = chatRooms.get(sessionId);
  
  // Add client to the room
  room.clients.set(clientId, {
    ws,
    name: 'Guest', // Default name
    timestamp: Date.now()
  });
  
  console.log(`Client ${clientId} joined room ${sessionId} (${room.clients.size} clients)`);
  
  // Broadcast join notification to all clients in the room
  broadcastToRoom(sessionId, {
    type: 'system',
    message: `A new user joined the chat`,
    timestamp: Date.now()
  });
  
  // Send room history to the new client
  if (room.messages.length > 0) {
    ws.send(JSON.stringify({
      type: 'history',
      messages: room.messages
    }));
  }
  
  // Handle messages from client
  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);
      
      // Handle different message types
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
  
  // Handle client disconnection
  ws.on('close', () => {
    handleClientDisconnect(sessionId, clientId);
  });
  
  // Handle errors
  ws.on('error', (error) => {
    console.error(`Client ${clientId} error: ${error.message}`);
  });
});

// Handle chat messages
function handleChatMessage(sessionId, clientId, message) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const client = room.clients.get(clientId);
  if (!client) return;
  
  // Create the chat message
  const chatMessage = {
    type: 'chat',
    clientId,
    sender: client.name,
    message: message.text,
    timestamp: Date.now()
  };
  
  // Store message in room history
  room.messages.push(chatMessage);
  
  // Broadcast message to all clients in the room
  broadcastToRoom(sessionId, chatMessage);
  
  console.log(`Message from ${client.name} in room ${sessionId}: ${message.text}`);
}

// Handle user updates (name, avatar, etc.)
function handleUserUpdate(sessionId, clientId, message) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const client = room.clients.get(clientId);
  if (!client) return;
  
  // Update user properties
  if (message.name && message.name !== client.name) {
    const oldName = client.name;
    client.name = message.name;
    
    // Broadcast name change
    broadcastToRoom(sessionId, {
      type: 'system',
      message: `"${oldName}" changed their name to "${message.name}"`,
      timestamp: Date.now()
    });
  }
  
  // Update other user properties as needed
  if (message.avatar) {
    client.avatar = message.avatar;
  }
}

// Handle client disconnection
function handleClientDisconnect(sessionId, clientId) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const client = room.clients.get(clientId);
  if (!client) return;
  
  // Remove client from room
  room.clients.delete(clientId);
  console.log(`Client ${clientId} (${client.name}) left room ${sessionId} (${room.clients.size} clients remaining)`);
  
  // Broadcast leave notification
  broadcastToRoom(sessionId, {
    type: 'system',
    message: `${client.name} left the chat`,
    timestamp: Date.now()
  });
  
  // If room is empty, delete it
  if (room.clients.size === 0) {
    console.log(`Room ${sessionId} is now empty, deleting room and all messages`);
    chatRooms.delete(sessionId);
  }
}

// Broadcast message to all clients in a room
function broadcastToRoom(sessionId, message) {
  const room = chatRooms.get(sessionId);
  if (!room) return;
  
  const messageStr = JSON.stringify(message);
  
  room.clients.forEach((client) => {
    if (client.ws.readyState === 1) { // OPEN
      client.ws.send(messageStr);
    }
  });
}

// API routes for session management
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

// Start the server
server.listen(PORT, () => {
  console.log(`Ephemeral Chat Server listening on port ${PORT}`);
  console.log(`Connect via WebSocket: ws://localhost:${PORT}?sessionId=YOUR_SESSION_ID`);
});

module.exports = server;
