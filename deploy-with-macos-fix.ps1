# Build and deploy the Flutter web app with MacOS STT/TTS fixes

# Navigate to flutter_client
Set-Location -Path C:\Dev\Chatroom5\flutter_client

# Check if Flutter is available
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    Write-Host "Building Flutter web app..." -ForegroundColor Cyan
    flutter build web
} else {
    Write-Host "Flutter command not found, using existing build..." -ForegroundColor Yellow
}

# Ensure server public directory exists
if (!(Test-Path C:\Dev\Chatroom5\server\public)) {
    New-Item -Path C:\Dev\Chatroom5\server\public -ItemType Directory
}

# Copy the web build to server public folder
Write-Host "Copying web build to server/public directory..." -ForegroundColor Cyan
Copy-Item -Path C:\Dev\Chatroom5\flutter_client\build\web\* -Destination C:\Dev\Chatroom5\server\public\ -Recurse -Force

# Return to main directory
Set-Location -Path C:\Dev\Chatroom5

# Deploy to App Engine
Write-Host "Deploying to Google App Engine..." -ForegroundColor Cyan
.\deploy-to-appengine.ps1

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Your app is available at: https://hear-all-v11-1.uc.r.appspot.com" -ForegroundColor Green
