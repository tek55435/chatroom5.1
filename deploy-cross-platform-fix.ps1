# Deploy script for Chatroom5 with Cross-Platform WebRTC fix
Write-Host "Deploying Chatroom5 with Cross-Platform WebRTC fixes to Google Cloud App Engine..." -ForegroundColor Cyan

# Check if the OPENAI_API_KEY environment variable exists
if (-not $env:OPENAI_API_KEY) {
    Write-Error "ERROR: OPENAI_API_KEY environment variable not set. Please set it before deploying."
    exit 1
}

# 1. Create or update .env file for server
Write-Host "Creating server/.env file with API key..." -ForegroundColor Green
Set-Content -Path "server/.env" -Value "OPENAI_API_KEY=$($env:OPENAI_API_KEY)"

# 2. Build the Flutter web app
Write-Host "Building Flutter web app..." -ForegroundColor Green
Push-Location flutter_client
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Flutter web app"
    Pop-Location
    exit 1
}
Pop-Location

# 3. Copy Flutter build to server's public directory
Write-Host "Copying Flutter build to server/public..." -ForegroundColor Green
if (-not (Test-Path "server/public")) {
    New-Item -ItemType Directory -Path "server/public" | Out-Null
}
Copy-Item -Path "flutter_client/build/web/*" -Destination "server/public/" -Recurse -Force

# 4. Change directory to server and install dependencies
Write-Host "Installing server dependencies..." -ForegroundColor Green
Push-Location server
npm ci --no-audit --no-fund
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install server dependencies"
    Pop-Location
    exit 1
}

# 5. Deploy to Google App Engine
Write-Host "Deploying to Google App Engine..." -ForegroundColor Green
gcloud app deploy --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy to Google App Engine"
    Pop-Location
    exit 1
}
Pop-Location

# 6. Print success message
Write-Host "Deployment complete! The app should be available at:" -ForegroundColor Cyan
Write-Host "https://hear-all-v11-1.uc.r.appspot.com" -ForegroundColor Yellow
Write-Host ""
Write-Host "To test the app, verify that:" -ForegroundColor Cyan
Write-Host "1. Speech-to-Text (STT) works when recording audio" -ForegroundColor White
Write-Host "2. Text-to-Speech (TTS) works when typing messages" -ForegroundColor White
Write-Host "3. WebRTC connection establishes successfully for audio streaming" -ForegroundColor White
Write-Host ""
Write-Host "This deployment includes fixes for both Windows and MacOS platforms." -ForegroundColor Green
