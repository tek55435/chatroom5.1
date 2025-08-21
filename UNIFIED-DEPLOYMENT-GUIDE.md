# Chatroom5 Unified Deployment Guide

## Overview
This guide explains how to deploy the Chatroom5 application using a unified approach where the Node.js backend serves both the API endpoints and the Flutter web frontend from a single App Engine service.

## Architecture
- **Frontend**: Flutter web app (mobile-responsive UI)
- **Backend**: Node.js Express server with OpenAI STT/TTS integration
- **Deployment**: Single App Engine default service
- **Static Files**: Flutter build served from `/server/public/` directory

## Quick Deployment

### Option 1: Automated Script (Recommended)
```powershell
.\deploy-complete-unified.ps1
```

This script will:
1. Build the Flutter web app for production
2. Copy the build files to the server's public directory
3. Verify server configuration
4. Optionally test locally
5. Deploy to App Engine

### Option 2: Manual Steps

1. **Build Flutter Web App**
   ```powershell
   cd flutter_client
   flutter build web --release
   cd ..
   ```

2. **Copy Build to Server**
   ```powershell
   # Create public directory if it doesn't exist
   mkdir server/public -ErrorAction SilentlyContinue
   
   # Remove old files and copy new build
   Remove-Item server/public/* -Recurse -Force -ErrorAction SilentlyContinue
   Copy-Item flutter_client/build/web/* -Destination server/public/ -Recurse -Force
   ```

3. **Deploy to App Engine**
   ```powershell
   cd server
   gcloud app deploy app.yaml --quiet
   ```

## Configuration Files

### server/app.yaml
```yaml
runtime: nodejs20
env: standard

instance_class: F1

env_variables:
  OPENAI_API_KEY: "your-openai-api-key-here"

handlers:
  - url: /.*
    secure: always
    script: auto
```

### server/.env
```env
OPENAI_API_KEY=your-openai-api-key-here
PORT=8080
MODEL=gpt-4o-realtime-preview-2024-12-17
```

## API Endpoints

Once deployed, your app will be available at `https://PROJECT-ID.uc.r.appspot.com` with the following endpoints:

- **Frontend**: `/` (Flutter web app)
- **Health Check**: `/api/health`
- **Text-to-Speech**: `POST /api/tts`
- **Speech-to-Text**: `POST /api/stt`
- **WebRTC Offer**: `POST /offer`

## Mobile Responsiveness Features

The Flutter frontend includes enhanced mobile responsiveness:
- Larger touch targets (48px minimum)
- Improved spacing and padding
- Modern Material Design 3 components
- Responsive breakpoints at 600px width
- Enhanced persona creation dialog
- Mobile-optimized communication mode selection

## Troubleshooting

### Common Issues

1. **404 Errors on API Endpoints**
   - Cause: Flutter deployment overwrote Node.js backend
   - Solution: Use the unified deployment approach

2. **STT/TTS Not Working**
   - Check: OPENAI_API_KEY is properly configured
   - Verify: `/api/health` endpoint returns `openaiKeyPresent: true`

3. **Mobile UI Issues**
   - Ensure: Flutter web build is properly copied to server/public
   - Check: Browser developer tools for responsive design

### Verification Steps

1. **Check Health Endpoint**
   ```powershell
   curl https://your-app.appspot.com/api/health
   ```

2. **Test TTS Endpoint**
   ```powershell
   curl -X POST https://your-app.appspot.com/api/tts -H "Content-Type: application/json" -d '{"text":"Hello world"}'
   ```

3. **Verify Static Files**
   - Navigate to your app URL
   - Confirm Flutter UI loads correctly
   - Test mobile responsiveness

## Deployment History

- **Previous Issue**: Separate deployments caused conflicts
- **Current Solution**: Unified deployment with Node.js serving static files
- **Benefits**: Single service, no conflicts, easier management

## Environment Variables

Required in both `app.yaml` and `.env`:
- `OPENAI_API_KEY`: Your OpenAI API key
- `PORT`: Server port (8080 for App Engine)
- `MODEL`: OpenAI model to use for realtime features

## Security Notes

- All traffic is forced to HTTPS
- CORS is configured for cross-origin requests
- File upload limits are set to 10MB for STT
- API keys are stored as environment variables

## Support

For issues or questions:
1. Check the health endpoint first
2. Review App Engine logs in Google Cloud Console
3. Verify Flutter build completed successfully
4. Ensure all configuration files are properly set
