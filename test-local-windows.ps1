# Local Development Test Script for Windows
Write-Host "=== Testing Local Development Setup (Windows) ===" -ForegroundColor Magenta

$localUrl = "http://localhost:3000"

Write-Host ""
Write-Host "Checking local development environment..." -ForegroundColor Yellow

# Check if .env file exists
Write-Host "1. Environment Configuration..." -ForegroundColor Cyan
if (Test-Path "C:\Dev\Chatroom5\server\.env") {
    Write-Host "   ✅ .env file exists" -ForegroundColor Green
    $envContent = Get-Content "C:\Dev\Chatroom5\server\.env" -Raw
    if ($envContent -match "OPENAI_API_KEY=sk-") {
        Write-Host "   ✅ OpenAI API key configured" -ForegroundColor Green
    } else {
        Write-Host "   ❌ OpenAI API key not configured properly" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ .env file missing" -ForegroundColor Red
    Write-Host "   Create it with: OPENAI_API_KEY=your_key_here" -ForegroundColor Gray
}

# Check dependencies
Write-Host "2. Dependencies..." -ForegroundColor Cyan
Push-Location "C:\Dev\Chatroom5\server"
if (Test-Path "package.json") {
    Write-Host "   ✅ package.json exists" -ForegroundColor Green
    if (Test-Path "node_modules") {
        Write-Host "   ✅ node_modules exists" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  node_modules missing - run 'npm install'" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ package.json missing" -ForegroundColor Red
}
Pop-Location

# Check if Flutter build exists
Write-Host "3. Flutter Build..." -ForegroundColor Cyan
if (Test-Path "C:\Dev\Chatroom5\server\public\index.html") {
    Write-Host "   ✅ Flutter web build exists in server/public" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Flutter build missing - run 'flutter build web' and copy to server/public" -ForegroundColor Yellow
}

# Test if server is running
Write-Host "4. Server Status..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$localUrl/api/health" -TimeoutSec 5
    Write-Host "   ✅ Server is running" -ForegroundColor Green
    Write-Host "   ✅ Status: $($health.status)" -ForegroundColor Green
    Write-Host "   ✅ OpenAI Key Present: $($health.openaiKeyPresent)" -ForegroundColor Green
    
    # Test endpoints
    Write-Host "5. Testing Endpoints..." -ForegroundColor Cyan
    
    # Test TTS
    try {
        $ttsBody = @{ text = "Hello World" } | ConvertTo-Json
        $ttsResponse = Invoke-WebRequest -Uri "$localUrl/api/tts" -Method POST -Headers @{"Content-Type"="application/json"} -Body $ttsBody -TimeoutSec 10
        if ($ttsResponse.StatusCode -eq 200) {
            Write-Host "   ✅ TTS endpoint working" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ❌ TTS endpoint failed: $_" -ForegroundColor Red
    }
    
    # Test WebRTC offer
    try {
        $sdp = "v=0`r`no=test 1 1 IN IP4 0.0.0.0`r`ns=test"
        $offerBody = @{ sdp = $sdp } | ConvertTo-Json
        $offerResponse = Invoke-WebRequest -Uri "$localUrl/offer" -Method POST -Headers @{"Content-Type"="application/json"} -Body $offerBody -TimeoutSec 10
        if ($offerResponse.StatusCode -eq 200) {
            Write-Host "   ✅ WebRTC offer endpoint working" -ForegroundColor Green
        }
    } catch {
        Write-Host "   ❌ WebRTC offer failed: $_" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ❌ Server not running" -ForegroundColor Red
    Write-Host ""
    Write-Host "To start the server:" -ForegroundColor Yellow
    Write-Host "   cd C:\Dev\Chatroom5\server" -ForegroundColor Gray
    Write-Host "   npm install" -ForegroundColor Gray
    Write-Host "   node appengine-server.js" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Write-Host "=== URL Resolution Test ===" -ForegroundColor Magenta

Write-Host ""
Write-Host "Expected Windows behavior:" -ForegroundColor Yellow
Write-Host "  • When accessing http://localhost:3000 → Uses http://localhost:3000" -ForegroundColor White
Write-Host "  • Should NEVER try to use https://localhost:3000" -ForegroundColor White
Write-Host "  • WebRTC connections should use http://localhost:3000/offer" -ForegroundColor White

Write-Host ""
Write-Host "If you see errors like:" -ForegroundColor Red
Write-Host "  • 'Sending offer to: https://localhost:3000/offer'" -ForegroundColor Gray
Write-Host "  • 'Fetch error: Failed to fetch'" -ForegroundColor Gray
Write-Host "Then the URL resolution fix is not working properly." -ForegroundColor Gray

Write-Host ""
Write-Host "Testing complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Start the local server if not running" -ForegroundColor White
Write-Host "  2. Open browser to http://localhost:3000" -ForegroundColor White
Write-Host "  3. Test STT (speech recording)" -ForegroundColor White
Write-Host "  4. Test TTS (text typing)" -ForegroundColor White
Write-Host "  5. Check browser console for URL resolution logs" -ForegroundColor White
