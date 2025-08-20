Write-Host "Testing iOS Audio and WebRTC Fixes" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

$baseUrl = "https://ios-fix-v1-dot-hear-all-v11-1.uc.r.appspot.com"

Write-Host "App URL: $baseUrl" -ForegroundColor Green

# Test server health
Write-Host "Testing server health..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET -TimeoutSec 5
    Write-Host "✅ Server is healthy: $($response.status)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Server health check failed" -ForegroundColor Red
}

# Test TTS endpoint
Write-Host "Testing TTS endpoint..." -ForegroundColor Yellow
try {
    $ttsBody = '{"text":"Test iOS audio"}'
    Invoke-RestMethod -Uri "$baseUrl/api/tts" -Method POST -Body $ttsBody -ContentType "application/json" -TimeoutSec 10 | Out-Null
    Write-Host "✅ TTS endpoint working" -ForegroundColor Green
}
catch {
    Write-Host "❌ TTS test failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "Key Features Deployed:" -ForegroundColor Cyan
Write-Host "• iOS Audio Keep-Alive System" -ForegroundColor White
Write-Host "• iOS Audio Context Management" -ForegroundColor White
Write-Host "• Touch-based Audio Reactivation" -ForegroundColor White
Write-Host "• Dynamic WebRTC SDP Matching" -ForegroundColor White
Write-Host "• Media Line Order Preservation" -ForegroundColor White

Write-Host ""
Write-Host "📱 iPhone Testing:" -ForegroundColor Yellow
Write-Host "1. Open Safari on iPhone" -ForegroundColor White
Write-Host "2. Go to: $baseUrl" -ForegroundColor White
Write-Host "3. Click 'Enable Audio for iOS' when prompted" -ForegroundColor White
Write-Host "4. Test TTS - audio should play consistently" -ForegroundColor White
Write-Host "5. Test STT - should work without WebRTC errors" -ForegroundColor White

Write-Host ""
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
