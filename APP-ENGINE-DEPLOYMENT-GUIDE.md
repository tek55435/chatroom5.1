# Google App Engine Deployment Guide

## Prerequisites
1. **Google Cloud CLI installed and authenticated**
   ```powershell
   # Install gcloud CLI if not already installed
   # Download from: https://cloud.google.com/sdk/docs/install
   
   # Authenticate
   gcloud auth login
   
   # Set your project (replace with your project ID)
   gcloud config set project hear-all-v11-1
   ```

2. **Enable required APIs**
   ```powershell
   gcloud services enable appengine.googleapis.com
   ```

## Deployment Steps

### 1. Deploy the Backend Server (Node.js)
```powershell
# Navigate to server directory
cd server

# Deploy to App Engine (uses app.yaml configuration)
gcloud app deploy app.yaml --quiet

# Get the deployed URL
gcloud app browse --no-launch-browser
```

### 2. Create Flutter App Engine Configuration
First, let's create an `app.yaml` for the Flutter web app:

```yaml
# flutter_client/app.yaml
runtime: nodejs20

handlers:
  # Serve static files from build/web
  - url: /
    static_files: build/web/index.html
    upload: build/web/index.html
    secure: always
    
  - url: /(.*)
    static_files: build/web/\1
    upload: build/web/(.*)
    secure: always

# Set environment variables for Flutter web build
env_variables:
  NODE_ENV: "production"
```

### 3. Build and Deploy Flutter Web App
```powershell
# Navigate to flutter client directory
cd flutter_client

# Build Flutter web with production configuration
flutter build web --release

# Deploy the web app as a separate service
gcloud app deploy app.yaml --quiet
```

### 4. Configure Custom Domain (Optional)
```powershell
# Map custom domain
gcloud app domain-mappings create your-domain.com

# View domain mappings
gcloud app domain-mappings list
```

## Configuration Files

### Server app.yaml (already exists)
```yaml
runtime: nodejs20
env_variables:
  PORT: "8080"
  NODE_ENV: "production"
  MODEL: "gpt-4o-realtime-preview-2024-12-17"
  OPENAI_API_KEY: "your-api-key-here"
handlers:
  - url: /.*
    secure: always
    script: auto
```

### Flutter app.yaml (needs to be created)
```yaml
runtime: nodejs20
handlers:
  - url: /
    static_files: build/web/index.html
    upload: build/web/index.html
    secure: always
  - url: /(.*)
    static_files: build/web/\1
    upload: build/web/(.*)
    secure: always
```

## Useful Commands

```powershell
# View logs
gcloud app logs tail -s default

# View app info
gcloud app describe

# Stop/start versions
gcloud app versions stop VERSION_ID
gcloud app versions start VERSION_ID

# View deployed services
gcloud app services list

# Open app in browser
gcloud app browse
```

## Troubleshooting

1. **Build Errors**: Ensure Flutter web build completes successfully
2. **API Key Issues**: Verify OpenAI API key is correctly set in app.yaml
3. **CORS Issues**: Check server CORS configuration for production domain
4. **Static Files**: Ensure build/web directory exists before deployment

## Cost Optimization

- App Engine automatically scales but doesn't scale to zero
- Consider Cloud Run for better cost efficiency with variable traffic
- Monitor usage in Google Cloud Console

## Security Notes

- Never commit API keys to version control
- Use Google Cloud Secret Manager for sensitive data in production
- Enable audit logging for security monitoring
