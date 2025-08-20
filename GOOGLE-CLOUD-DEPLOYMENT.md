# Chatroom5 Google Cloud Deployment Guide

This document provides instructions for deploying the Chatroom5 application to Google Cloud App Engine.

## Prerequisites

1. Google Cloud SDK (gcloud) installed
2. Google Cloud account with billing enabled
3. OpenAI API key (stored in `.env` file)

## Deployment Steps

### 1. Prepare the Application

Before deployment, make sure:
- The Flutter web app is built (`flutter build web`)
- Web assets are copied to the server's public directory

### 2. Configuration Files

Two key configuration files are used:

#### app.yaml
```yaml
runtime: nodejs20
service: default  # For first deployment, use default service
env_variables:
  PORT: "8080"
  NODE_ENV: "production"
  MODEL: "gpt-4o-realtime-preview-2024-12-17"
  OPENAI_API_KEY: "your-api-key-here"  # Will be set by deploy script
```

#### appengine-server.js
This combined server file handles:
- Main API server functionality (port 8080)
- Chat server functionality (same port, different WebSocket endpoint)
- Speech-to-text and text-to-speech APIs
- WebRTC signaling

### 3. Deployment Process

Use the provided PowerShell script `deploy-to-appengine.ps1`:

1. It reads your OpenAI API key from `.env`
2. Updates `app.yaml` with the key
3. Sets the Google Cloud project to `hear-all-v11-1`
4. Deploys the application to App Engine

Run the deployment script:
```powershell
.\deploy-to-appengine.ps1
```

### 4. Accessing the Deployed Application

After deployment completes, your app will be available at:
```
https://hear-all-v11-1.uc.r.appspot.com
```

You can view logs using:
```powershell
gcloud app logs tail -s default
```

And open the app in a browser:
```powershell
gcloud app browse
```

## Troubleshooting

### API Key Issues
- If you see authentication errors, check the App Engine logs
- Verify the API key is correctly set in the environment variables

### Deployment Failures
- Check if the project ID is correct
- Ensure you're logged into gcloud: `gcloud auth login`
- Make sure billing is enabled for the project

### Application Errors
- View logs: `gcloud app logs tail`
- Check if services are running correctly: `gcloud app services list`

## Updating the Deployment

To update the deployed application:

1. Make your code changes
2. Build the Flutter web app if needed
3. Copy web assets to server/public
4. Run the deployment script again

## Accessing the API

- Main API endpoints: `https://hear-all-v11-1.uc.r.appspot.com/api/...`
- WebSocket Chat: `wss://hear-all-v11-1.uc.r.appspot.com/chat?sessionId=YOUR_SESSION_ID`
- Health Check: `https://hear-all-v11-1.uc.r.appspot.com/api/health`
