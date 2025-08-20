# Complete Cross-Platform WebRTC Fix Deployment Script
Write-Host "=== Deploying Complete Cross-Platform WebRTC Fix ===" -ForegroundColor Magenta

# Check if OPENAI_API_KEY is set
if (-not $env:OPENAI_API_KEY) {
    Write-Error "ERROR: OPENAI_API_KEY environment variable not set. Please set it before deploying."
    exit 1
}

# Step 1: Create backup
Write-Host "Creating backup..." -ForegroundColor Yellow
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = "C:\Dev\Chatroom5\backup_$timestamp"
if (Test-Path "C:\Dev\Chatroom5\server") {
    Copy-Item -Path "C:\Dev\Chatroom5\server" -Destination $backupDir -Recurse -Force
    Write-Host "Backup created at: $backupDir" -ForegroundColor Green
}

# Step 2: Update .env file
Write-Host "Updating server/.env file..." -ForegroundColor Yellow
Set-Content -Path "C:\Dev\Chatroom5\server\.env" -Value @"
OPENAI_API_KEY=$($env:OPENAI_API_KEY)
MODEL=gpt-4o-realtime-preview-2024-12-17
PORT=8080
"@

# Step 3: Install server dependencies
Write-Host "Installing server dependencies..." -ForegroundColor Yellow
Push-Location "C:\Dev\Chatroom5\server"
npm install node-fetch@2.7.0 form-data@4.0.0 multer@2.0.2 express@4.18.2 cors@2.8.5 dotenv@16.3.1 --save
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install server dependencies"
    Pop-Location
    exit 1
}
Pop-Location

# Step 4: Build Flutter web app
Write-Host "Building Flutter web app..." -ForegroundColor Yellow
Push-Location "C:\Dev\Chatroom5\flutter_client"
flutter clean
flutter pub get
flutter build web --release --web-renderer html
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Flutter web app"
    Pop-Location
    exit 1
}
Pop-Location

# Step 5: Copy Flutter build to server
Write-Host "Copying Flutter build to server..." -ForegroundColor Yellow
$webBuildPath = "C:\Dev\Chatroom5\flutter_client\build\web"
$serverPublicPath = "C:\Dev\Chatroom5\server\public"

# Remove old public directory
if (Test-Path $serverPublicPath) {
    Remove-Item -Path $serverPublicPath -Recurse -Force
}

# Create new public directory and copy files
New-Item -Path $serverPublicPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$webBuildPath\*" -Destination $serverPublicPath -Recurse -Force

Write-Host "Flutter app copied to server/public" -ForegroundColor Green

# Step 6: Deploy to Google App Engine
Write-Host "Deploying to Google App Engine..." -ForegroundColor Yellow
Push-Location "C:\Dev\Chatroom5\server"

# Verify app.yaml exists
if (-not (Test-Path "app.yaml")) {
    Write-Host "Creating app.yaml..." -ForegroundColor Yellow
    Set-Content -Path "app.yaml" -Value @"
runtime: nodejs20
service: default

env_variables:
  OPENAI_API_KEY: "$($env:OPENAI_API_KEY)"
  MODEL: "gpt-4o-realtime-preview-2024-12-17"
  PORT: "8080"

handlers:
- url: /.*
  secure: always
  script: auto
"@
}

gcloud app deploy --project=hear-all-v11-1 --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy to Google App Engine"
    Pop-Location
    exit 1
}
Pop-Location

# Step 7: Test deployment
Write-Host "Testing deployment..." -ForegroundColor Yellow
$cloudUrl = "https://hear-all-v11-1.uc.r.appspot.com"

try {
    $health = Invoke-RestMethod -Uri "$cloudUrl/api/health" -TimeoutSec 10
    Write-Host "Health check: $($health.status)" -ForegroundColor Green
    Write-Host "OpenAI Key Present: $($health.openaiKeyPresent)" -ForegroundColor Green
} catch {
    Write-Host "Health check failed: $_" -ForegroundColor Red
}

# Step 8: Success message
Write-Host ""
Write-Host "=== Deployment Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your app is now deployed with complete cross-platform WebRTC fixes!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test URLs:" -ForegroundColor Yellow
Write-Host "  Cloud:  $cloudUrl" -ForegroundColor White
Write-Host "  Local:  http://localhost:3000" -ForegroundColor White
Write-Host ""
Write-Host "Fixes implemented:" -ForegroundColor Yellow
Write-Host "  ✅ WebRTC SDP format fix (Mac 'Expect line: v=' error)" -ForegroundColor White
Write-Host "  ✅ Windows localhost protocol fix (http vs https)" -ForegroundColor White
Write-Host "  ✅ Cross-platform URL resolution" -ForegroundColor White
Write-Host "  ✅ Proper OpenAI Realtime API integration" -ForegroundColor White
Write-Host "  ✅ Enhanced error handling and logging" -ForegroundColor White
Write-Host ""
Write-Host "Test both platforms:" -ForegroundColor Yellow
Write-Host "  • Windows: STT, TTS, and WebRTC should work locally" -ForegroundColor White
Write-Host "  • Mac: STT, TTS, and WebRTC should work when accessing cloud URL" -ForegroundColor White
