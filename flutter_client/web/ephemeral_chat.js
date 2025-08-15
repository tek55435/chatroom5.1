// Fixed ephemeral chat integration 
 
// Create a global chat manager object 
window.EphemeralChat = { 
  // Connection state 
  connected: false, 
  sessionId: null, 
  socket: null, 
 
  // Generate a random numeric session ID 
  generateSessionId: function() { 
    let id = ''; 
    for (let i = 0; i < 8; i++) {
      id += Math.floor(Math.random() * 10); 
    } 
    console.log('Generated session ID:', id); 
    return id; 
  }, 
 
  // Extract session ID from URL if present 
  getSessionIdFromUrl: function() { 
    const urlParams = new URLSearchParams(window.location.search); 
    return urlParams.get('sessionId'); 
  }, 
 
  // Update URL with session ID 
  updateUrlWithSessionId: function(sessionId) { 
    if (!sessionId) return; 
 
    const url = new URL(window.location.href); 
    url.searchParams.set('sessionId', sessionId); 
    url.searchParams.set('chat', 'true'); 
    window.history.replaceState({}, '', url); 
  }, 
 
  // Connect to chat server 
  connect: function(sessionId, onConnect, onMessage, onClose, onError) { 
    console.log('Connecting to chat with session ID:', sessionId); 
 
    if (!sessionId) { 
      sessionId = this.generateSessionId(); 
      console.log('Generated new session ID:', sessionId); 
    } 
 
    this.sessionId = sessionId; 
    this.updateUrlWithSessionId(sessionId); 
 
    // Close any existing socket first 
    if (this.socket) { 
      try { 
        this.socket.close(); 
        this.socket = null; 
      } catch (e) { 
        console.warn('Error closing existing socket:', e); 
      } 
    } 
 
    const host = window.location.hostname; 
    const port = 3001; // Use a different port for chat to avoid conflicts 
    const wsProtocol = window.location.protocol === 'https:' ? 'wss' : 'ws'; 
    const uri = `${wsProtocol}://${host}:${port}?sessionId=${sessionId}`; 
    console.log('Connecting to WebSocket at:', uri); 
 
    try { 
      const socket = new WebSocket(uri); 
      this.socket = socket; 
 
      socket.onopen = function() { 
        console.log(`Connected to chat room ${sessionId}`); 
        window.EphemeralChat.connected = true; 
 
        // Send initial message 
        try { 
          const welcomeMsg = { 
            type: 'chat', 
            sender: 'System', 
            message: 'A new user has joined the chat', 
            timestamp: new Date().toISOString() 
          }; 
          socket.send(JSON.stringify(welcomeMsg)); 
          console.log('Sent welcome message'); 
        } catch (e) { 
          console.error('Error sending initial message:', e); 
        } 
 
        if (onConnect) { 
          console.log('Calling onConnect callback'); 
          onConnect(sessionId); 
        } 
      }; 
 
      socket.onmessage = function(event) { 
        console.log('Received message:', event.data); 
        try { 
          const data = JSON.parse(event.data); 
          if (onMessage) { 
            console.log('Calling onMessage callback'); 
            onMessage(data); 
          } 
        } catch (error) { 
          console.error('Error parsing message:', error); 
        } 
      }; 
 
      socket.onclose = function(event) { 
        window.EphemeralChat.connected = false; 
        window.EphemeralChat.socket = null; 
        if (onClose) { 
          console.log('Calling onClose callback'); 
          onClose(); 
        } 
      }; 
 
      socket.onerror = function(error) { 
        console.error('WebSocket error:', error); 
        if (onError) { 
          let errorMsg = 'WebSocket connection error'; 
          if (error && error.toString) {
            errorMsg = error.toString(); 
          } 
          console.log('Calling onError callback with:', errorMsg); 
          onError(errorMsg); 
        } 
      }; 
 
    } catch (error) { 
      console.error('Error connecting to chat server:', error); 
      if (onError) { 
        onError(error.toString()); 
      } 
    } 
  }, 
 
  // Send a message to the chat room 
  sendMessage: function(content, username) { 
    console.log('Attempting to send message:', content, 'from:', username); 

    if (!this.socket || !this.connected) {
      console.error('Not connected to chat server'); 
      return false; 
    } 

    const message = { 
      type: 'chat', 
      message: content, 
      timestamp: new Date().toISOString() 
    }; 

    try { 
      console.log('Sending message:', message); 
      this.socket.send(JSON.stringify(message)); 
      return true; 
    } catch (error) { 
      console.error('Error sending message:', error); 
      return false; 
    } 
  },  // Disconnect from the chat server 
  disconnect: function() { 
    if (this.socket) { 
      this.socket.close(); 
      this.socket = null; 
      this.connected = false; 
      console.log('Disconnected from chat server'); 
    } 
  } 
}; 
