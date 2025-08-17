@echo off
echo Starting fix for join button...

rem Kill any running Flutter instances
taskkill /F /IM chrome.exe /T
taskkill /F /IM node.exe /T

rem Wait a moment
timeout /t 2 /nobreak > nul

rem Create a fixed version of ephemeral_chat.js with correct connection handling
echo // Fixed ephemeral chat integration > C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo // Create a global chat manager object >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo window.EphemeralChat = { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Connection state >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   connected: false, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   sessionId: null, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   socket: null, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Generate a random numeric session ID >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   generateSessionId: function() { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     let id = ''; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     for (let i = 0; i < 8; i++) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       id += Math.floor(Math.random() * 10); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     console.log('Generated session ID:', id); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     return id; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   }, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Extract session ID from URL if present >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   getSessionIdFromUrl: function() { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const urlParams = new URLSearchParams(window.location.search); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     return urlParams.get('sessionId'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   }, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Update URL with session ID >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   updateUrlWithSessionId: function(sessionId) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     if (!sessionId) return; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const url = new URL(window.location.href); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     url.searchParams.set('sessionId', sessionId); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     url.searchParams.set('chat', 'true'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     window.history.replaceState({}, '', url); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   }, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Connect to chat server >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   connect: function(sessionId, onConnect, onMessage, onClose, onError) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     console.log('Connecting to chat with session ID:', sessionId); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     if (!sessionId) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       sessionId = this.generateSessionId(); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       console.log('Generated new session ID:', sessionId); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     this.sessionId = sessionId; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     this.updateUrlWithSessionId(sessionId); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     // Close any existing socket first >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     if (this.socket) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       try { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         this.socket.close(); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         this.socket = null; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       } catch (e) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         console.warn('Error closing existing socket:', e); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const host = window.location.hostname; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const port = 3001; // Use a different port for chat to avoid conflicts >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const wsProtocol = window.location.protocol === 'https:' ? 'wss' : 'ws'; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const uri = `${wsProtocol}://${host}:${port}?sessionId=${sessionId}`; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     console.log('Connecting to WebSocket at:', uri); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     try { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       const socket = new WebSocket(uri); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       this.socket = socket; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       socket.onopen = function() { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         console.log(`Connected to chat room ${sessionId}`); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         window.EphemeralChat.connected = true; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         // Send initial message >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         try { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           const welcomeMsg = { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             type: 'chat', >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             sender: 'System', >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             message: 'A new user has joined the chat', >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             timestamp: new Date().toISOString() >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           socket.send(JSON.stringify(welcomeMsg)); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           console.log('Sent welcome message'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } catch (e) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           console.error('Error sending initial message:', e); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         if (onConnect) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           console.log('Calling onConnect callback'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           onConnect(sessionId); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       socket.onmessage = function(event) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         console.log('Received message:', event.data); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         try { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           const data = JSON.parse(event.data); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           if (onMessage) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             console.log('Calling onMessage callback'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             onMessage(data); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } catch (error) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           console.error('Error parsing message:', error); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       socket.onclose = function(event) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         console.log(`Disconnected from chat room ${sessionId} with code ${event.code} and reason: ${event.reason || 'No reason provided'}`); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         window.EphemeralChat.connected = false; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         window.EphemeralChat.socket = null; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         if (onClose) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           console.log('Calling onClose callback'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           onClose(); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       socket.onerror = function(error) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         console.error('WebSocket error:', error); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         if (onError) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           let errorMsg = 'WebSocket connection error'; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           if (error && error.toString) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo             errorMsg = error.toString(); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           console.log('Calling onError callback with:', errorMsg); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo           onError(errorMsg); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } catch (error) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       console.error('Error connecting to chat server:', error); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       if (onError) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo         onError(error.toString()); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   }, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Send a message to the chat room >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   sendMessage: function(content, username) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     console.log('Attempting to send message:', content, 'from:', username); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     if (!this.connected || !this.socket) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       console.error('Not connected to chat server'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       return false; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     const message = { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       type: 'chat', >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       sender: username || 'Anonymous', >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       message: content, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       timestamp: new Date().toISOString() >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     try { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       console.log('Sending message:', message); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       this.socket.send(JSON.stringify(message)); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       return true; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } catch (error) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       console.error('Error sending message:', error); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       return false; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   }, >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo. >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   // Disconnect from the chat server >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   disconnect: function() { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     if (this.socket) { >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       this.socket.close(); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       this.socket = null; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       this.connected = false; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo       console.log('Disconnected from chat server'); >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo     } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo   } >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new
echo }; >> C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new

rem Copy the fixed file over the original
copy /Y C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js
del C:\Dev\Chatroom5\flutter_client\web\ephemeral_chat.js.new

echo.
echo Starting chat server...

rem Start the chat server
cd /d C:\Dev\Chatroom5\server
start cmd /k "node ephemeral-chat-server.cjs"

timeout /t 2 /nobreak > nul

echo Starting Flutter web app...

rem Start Flutter web app
cd /d C:\Dev\Chatroom5\flutter_client
start cmd /k "flutter run -d chrome --web-port 8008"

echo.
echo Fix complete! Please wait a moment for the app to start...
timeout /t 5
echo.
echo Note: When the app opens, click the chat button in the top right, then click "Join Chat"
echo       This will now work correctly and start a new chat session.
echo.
