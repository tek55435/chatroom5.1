# Realtime TTS + STT (Web-first Flutter) — OpenAI Realtime

## Summary
This project demonstrates a web-first Flutter app that uses WebRTC to stream microphone audio (STT) to OpenAI Realtime and to play TTS audio returned by the model. The Node.js server creates ephemeral sessions and proxies the SDP handshake.

## Files
- `server/` — Node/Express server
  - `index.js` — main server code
  - `.env.example` — environment variables
- `flutter_client/` — Flutter app (web)
  - `lib/main.dart` — Flutter Web app
  - `web/index.html` — web host page
  - `pubspec.yaml`

## Setup (local)
1. Install Node (v18+ recommended) and npm.
2. Install Flutter SDK (for web).
3. Server:
   - `cd server`
   - `cp .env.example .env` and edit `server/.env` with your `OPENAI_API_KEY`.
   - `npm install`
   - `npm start`
4. Flutter Web:
   - `cd flutter_client`
   - `flutter pub get`
   - `flutter run -d chrome`
5. Open the Flutter app (it will open automatically), click **Join**, then **Start Mic** to stream; type a message and click **Send** to hear TTS.

## Deploy (Render)
- Create a web service with the Node server (set `OPENAI_API_KEY` as environment variable).
- Optionally build Flutter web and serve it from the Node server's static folder (`flutter build web` and copy `build/web` to server static directory).
- Ensure TLS (Render provides https) — browsers require HTTPS for mic access.

## Notes & Troubleshooting
- Ensure `OPENAI_API_KEY` is valid and the server can reach `api.openai.com`.
- If the browser logs `Failed to parse SessionDescription` check that server returns plain SDP text with `Content-Type: application/sdp`.
- For mobile builds later, replace `dart:html` WebRTC parts with `flutter_webrtc` package.
