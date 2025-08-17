# Debug config overrides for Chat endpoints

You can point the Flutter Web client at different chat servers without rebuilding.

Runtime overrides (highest precedence first):

1) URL query params
- chatWs: WebSocket base (ws:// or wss://)
- chatHttp: HTTP base used for REST endpoints (https:// recommended)

Example:
https://your-app.example.com/?chatWs=wss://chat.example.com&chatHttp=https://chat.example.com

2) JS globals (set before app initializes)
- window.CHAT_WS = 'wss://chat.example.com'
- window.CHAT_HTTP = 'https://chat.example.com'

3) Compile-time defaults
- --dart-define CHAT_WS
- --dart-define CHAT_HTTP

Client behavior:
- If the new-session HTTP call fails (e.g., localhost not reachable on device), the client will connect to WS without a sessionId and let the server assign one. The URL will be updated to include ?sessionId=... after the initial session message.
- Participants polling uses chatHttp; if that points to localhost but chatWs is remote, the client derives https://host from chatWs automatically.

Tips:
- On mobile device testing, prefer passing chatWs/chatHttp in the URL so it doesnt try to hit localhost:3001.
- Cloud Run: use wss:// for chatWs and https:// for chatHttp.
