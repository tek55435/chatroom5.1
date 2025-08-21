# Cloud Run quick deploy (API, Chat WS, Flutter Web)

Prereqs:
- gcloud CLI authenticated and project set: `gcloud auth login` and `gcloud config set project hear-all-v11-1`
- Docker installed (gcloud will use Cloud Build if local Docker not available)
- OPENAI_API_KEY ready (do not commit it)

Services:
- API: container from `server/Dockerfile`
- Chat WS: container from `server-chat/Dockerfile`
- Web: container from `flutter_client/Dockerfile` (expects `flutter build web` output in `flutter_client/build/web`)

Build Flutter web:
- Run:
  flutter build web --release --dart-define=SERVER_BASE=https://<API_URL> --dart-define=CHAT_WS=wss://<CHAT_URL> --dart-define=CHAT_HTTP=https://<CHAT_URL>

Deploy (replace REGION with us-central1):
- API:
  gcloud run deploy chat5-api --source=server --region=us-central1 --allow-unauthenticated --set-env-vars=OPENAI_API_KEY=YOUR_KEY,MODEL=gpt-4o-realtime-preview-2024-12-17
- Chat WS:
  gcloud run deploy chat5-ws --source=server-chat --region=us-central1 --allow-unauthenticated
- Web (after flutter build):
  gcloud run deploy chat5-web --source=flutter_client --region=us-central1 --allow-unauthenticated

After deploy, note the service URLs printed by gcloud and rebuild the Flutter web with dart-defines that point to those URLs, then redeploy the Web service.

CORS: This repo currently allows all origins. You can lock it later by setting specific origins in the Express/CORS config.
