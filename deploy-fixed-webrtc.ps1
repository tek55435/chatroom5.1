# Deploy script for Chatroom5 with WebRTC fix
Write-Host "Deploying Chatroom5 with WebRTC fixes to Google Cloud App Engine..."

# Check if the OPENAI_API_KEY environment variable exists
if (-not $env:OPENAI_API_KEY) {
    Write-Error "ERROR: OPENAI_API_KEY environment variable not set. Please set it before deploying."
    exit 1
}

# 1. Create or update .env file for server
Write-Host "Creating server/.env file with API key..."
Set-Content -Path "server/.env" -Value "OPENAI_API_KEY=$($env:OPENAI_API_KEY)"

# 2. Change directory to server and install dependencies
Write-Host "Installing server dependencies..."
Push-Location server
npm ci --no-audit --no-fund
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install server dependencies"
    Pop-Location
    exit 1
}

# 3. Deploy to Google App Engine
Write-Host "Deploying to Google App Engine..."
gcloud app deploy --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy to Google App Engine"
    Pop-Location
    exit 1
}
Pop-Location

# 4. Print success message
Write-Host "Deployment complete! The app should be available at:"
Write-Host "https://hear-all-v11-1.uc.r.appspot.com" -ForegroundColor Green
Write-Host ""
Write-Host "To test the app on MacOS, go to this URL and verify that:"
Write-Host "1. Speech-to-Text (STT) works when recording audio"
Write-Host "2. Text-to-Speech (TTS) works when typing messages"
Write-Host "3. WebRTC connection establishes successfully for audio streaming"
