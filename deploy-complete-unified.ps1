# Complete unified deployment script for Chatroom5
# This script builds the Flutter web app and deploys it with the Node.js backend to App Engine

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CHATROOM5 UNIFIED DEPLOYMENT SCRIPT  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Get the current directory
$currentDir = Get-Location
Write-Host "Current directory: $currentDir" -ForegroundColor Green

# Step 1: Build Flutter web app
Write-Host "`n=== STEP 1: Building Flutter Web App ===" -ForegroundColor Yellow
Set-Location "flutter_client"

if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "Error: pubspec.yaml not found in flutter_client directory" -ForegroundColor Red
    Set-Location $currentDir
    exit 1
}

Write-Host "Building Flutter web app for production..." -ForegroundColor Green
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter build failed" -ForegroundColor Red
    Set-Location $currentDir
    exit 1
}

Write-Host "Flutter build completed successfully!" -ForegroundColor Green

# Step 2: Copy Flutter build to server's public folder
Write-Host "`n=== STEP 2: Copying Flutter Build to Server ===" -ForegroundColor Yellow
Set-Location $currentDir

# Create server/public directory if it doesn't exist
if (-not (Test-Path "server/public")) {
    New-Item -ItemType Directory -Path "server/public" -Force
    Write-Host "Created server/public directory" -ForegroundColor Green
}

# Remove old files
Write-Host "Cleaning old build files..." -ForegroundColor Green
Remove-Item "server/public/*" -Recurse -Force -ErrorAction SilentlyContinue

# Copy new build
Write-Host "Copying Flutter web build to server/public..." -ForegroundColor Green
Copy-Item "flutter_client/build/web/*" -Destination "server/public/" -Recurse -Force

Write-Host "Flutter build copied to server/public successfully!" -ForegroundColor Green

# Step 3: Verify server configuration
Write-Host "`n=== STEP 3: Verifying Server Configuration ===" -ForegroundColor Yellow
Set-Location "server"

if (-not (Test-Path ".env")) {
    Write-Host "Warning: .env file not found in server directory" -ForegroundColor Red
    Write-Host "Please ensure OPENAI_API_KEY is configured" -ForegroundColor Red
} else {
    Write-Host ".env file found" -ForegroundColor Green
}

if (-not (Test-Path "app.yaml")) {
    Write-Host "Error: app.yaml not found in server directory" -ForegroundColor Red
    Set-Location $currentDir
    exit 1
} else {
    Write-Host "app.yaml file found" -ForegroundColor Green
}

# Step 4: Test server locally (optional)
Write-Host "`n=== STEP 4: Optional Local Test ===" -ForegroundColor Yellow
$testLocal = Read-Host "Do you want to test the server locally before deployment? (y/n)"
if ($testLocal -eq "y" -or $testLocal -eq "Y") {
    Write-Host "Starting local server for testing..." -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop the server and continue with deployment" -ForegroundColor Yellow
    Write-Host "Test URL: http://localhost:3000" -ForegroundColor Cyan
    
    try {
        node index.js
    } catch {
        Write-Host "Local test interrupted or failed" -ForegroundColor Yellow
    }
}

# Step 5: Deploy to App Engine
Write-Host "`n=== STEP 5: Deploying to App Engine ===" -ForegroundColor Yellow

# Check if gcloud is installed and authenticated
try {
    $gcloudAuth = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if (-not $gcloudAuth) {
        Write-Host "Error: Not authenticated with Google Cloud" -ForegroundColor Red
        Write-Host "Please run: gcloud auth login" -ForegroundColor Yellow
        Set-Location $currentDir
        exit 1
    }
    Write-Host "Authenticated as: $gcloudAuth" -ForegroundColor Green
} catch {
    Write-Host "Error: gcloud CLI not found or not working" -ForegroundColor Red
    Write-Host "Please install Google Cloud CLI: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    Set-Location $currentDir
    exit 1
}

# Deploy to App Engine
Write-Host "Deploying unified app to App Engine..." -ForegroundColor Green
Write-Host "This will serve both the Flutter frontend and Node.js backend from the same service" -ForegroundColor Cyan

gcloud app deploy app.yaml --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: App Engine deployment failed" -ForegroundColor Red
    Set-Location $currentDir
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "     DEPLOYMENT COMPLETED SUCCESSFULLY! " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Get the app URL
try {
    $appUrl = gcloud app browse --no-launch-browser 2>$null | Select-String -Pattern "https://.*\.appspot\.com" | ForEach-Object { $_.Matches[0].Value }
    if ($appUrl) {
        Write-Host "`nYour app is now available at: $appUrl" -ForegroundColor Green
        Write-Host "API endpoints are available at:" -ForegroundColor Cyan
        Write-Host "  - Health check: $appUrl/api/health" -ForegroundColor White
        Write-Host "  - TTS API: $appUrl/api/tts" -ForegroundColor White
        Write-Host "  - STT API: $appUrl/api/stt" -ForegroundColor White
        Write-Host "  - WebRTC offer: $appUrl/offer" -ForegroundColor White
    }
} catch {
    Write-Host "`nDeployment completed. Check the App Engine console for your app URL." -ForegroundColor Green
}

Set-Location $currentDir
Write-Host "`nDeployment script completed!" -ForegroundColor Green
