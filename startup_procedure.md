# Chatroom5 Startup and Shutdown Procedures

## Startup Procedure

### Step 1: Start Main Backend Server (Terminal 1)
```powershell
# Navigate to server directory
cd C:\Dev\Chatroom5\server

# Start the main backend server
node index.cjs
```
Expected output: "HearAll server is running on http://localhost:3000"

### Step 2: Start Ephemeral Chat Server (Terminal 2)
```powershell
# Navigate to chat server directory
cd C:\Dev\Chatroom5\server-chat
# OR if using the version in server folder:
# cd C:\Dev\Chatroom5\server

# Start the ephemeral chat server
node ephemeral-chat-server.js
# OR if using CJS version:
# node ephemeral-chat-server.cjs
```
Expected output: "Ephemeral Chat Server listening on port 3001"

### Step 3: Access the Application
Open your web browser and navigate to:
```
http://localhost:3000
```

## Shutdown Procedure

### Method 1: Graceful Shutdown (Recommended)
In each terminal window:
1. Click on the terminal to make it active
2. Press Ctrl+C
3. Wait until the command prompt returns
4. Repeat for the other terminal

### Method 2: Force Kill All Node Processes
```powershell
Stop-Process -Name "node" -Force -ErrorAction SilentlyContinue
```

### Verify Shutdown
To confirm servers are no longer running:
```powershell
Get-NetTCPConnection -LocalPort 3000,3001 -ErrorAction SilentlyContinue
```
No output means servers are stopped.

## Troubleshooting

### OpenAI API Key Issues
If you see authentication errors:
1. Use a standard OpenAI API key (starts with "sk-") instead of a service account key
2. Edit the .env file:
```powershell
notepad C:\Dev\Chatroom5\server\.env
```
3. Replace the OPENAI_API_KEY value and save
4. Restart the main server

### Port Already In Use
If you get "port already in use" errors:
```powershell
# Find process using port 3000
Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object OwningProcess
# Kill the process (replace XXXX with actual process ID)
Stop-Process -Id XXXX -Force
```

### Testing the Health Endpoint
To verify the main server is running properly:
```powershell
Invoke-RestMethod -Uri "http://localhost:3000/api/health" | ConvertTo-Json -Depth 3
```

### Server Logs Location
If you need to check server logs:
```powershell
# Main server logs
Get-Content -Path "C:\Dev\Chatroom5\server\logs\server.log" -Tail 50

# Chat server logs (if enabled)
Get-Content -Path "C:\Dev\Chatroom5\server-chat\logs\chat.log" -Tail 50
```

## API Endpoints Reference

### Main Server (Port 3000)
- `GET /api/health` - Server health status
- `POST /api/tts` - Text-to-Speech conversion
- `POST /api/stt` - Speech-to-Text conversion
- `POST /offer` - WebRTC signaling (OpenAI Realtime)

### Chat Server (Port 3001)
- WebSocket endpoint for real-time chat messaging
- Room management and user presence tracking

## Application Features

- Real-time audio processing via WebRTC
- Text-to-Speech and Speech-to-Text capabilities
- Multi-user chat rooms with session sharing
- Diagnostic panel for troubleshooting
