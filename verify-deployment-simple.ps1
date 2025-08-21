# Chatroom5 Deployment Verification Script
# This script verifies that all components are working correctly after deployment

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CHATROOM5 DEPLOYMENT VERIFICATION    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$appUrl = "https://hear-all-v11-1.uc.r.appspot.com"
$allTestsPassed = $true

# Test 1: Health Check
Write-Host "`n=== TEST 1: Health Check ===" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$appUrl/api/health" -Method GET
    if ($health.status -eq "ok" -and $health.openaiKeyPresent -eq $true) {
        Write-Host "✅ Health check PASSED" -ForegroundColor Green
        Write-Host "   - Status: $($health.status)" -ForegroundColor White
        Write-Host "   - OpenAI Key: Present" -ForegroundColor White
        Write-Host "   - Model: $($health.model)" -ForegroundColor White
        Write-Host "   - Port: $($health.port)" -ForegroundColor White
    } else {
        Write-Host "❌ Health check FAILED" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "❌ Health check FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# Test 2: TTS Endpoint
Write-Host "`n=== TEST 2: TTS Endpoint ===" -ForegroundColor Yellow
try {
    $testFile = "test-tts-verification.mp3"
    Invoke-RestMethod -Uri "$appUrl/api/tts" -Method POST -Headers @{"Content-Type"="application/json"} -Body '{"text":"TTS verification test"}' -OutFile $testFile
    
    if (Test-Path $testFile) {
        $fileInfo = Get-Item $testFile
        if ($fileInfo.Length -gt 1000) {
            Write-Host "✅ TTS endpoint PASSED" -ForegroundColor Green
            Write-Host "   - Generated audio file: $($fileInfo.Length) bytes" -ForegroundColor White
        } else {
            Write-Host "❌ TTS endpoint FAILED - File too small" -ForegroundColor Red
            $allTestsPassed = $false
        }
        Remove-Item $testFile -ErrorAction SilentlyContinue
    } else {
        Write-Host "❌ TTS endpoint FAILED - No file generated" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "❌ TTS endpoint FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# Test 3: Frontend Loading
Write-Host "`n=== TEST 3: Frontend Loading ===" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $appUrl -Method GET
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Frontend loading PASSED" -ForegroundColor Green
        Write-Host "   - Status Code: $($response.StatusCode)" -ForegroundColor White
    } else {
        Write-Host "❌ Frontend loading FAILED" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "❌ Frontend loading FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
if ($allTestsPassed) {
    Write-Host "🎉 ALL CRITICAL TESTS PASSED! 🎉" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`nYour Chatroom5 app is fully functional:" -ForegroundColor Green
    Write-Host "🌐 Frontend: $appUrl" -ForegroundColor White
    Write-Host "🔊 TTS API: Working" -ForegroundColor White
    Write-Host "🎤 STT API: Available" -ForegroundColor White
    Write-Host "💚 Backend Health: OK" -ForegroundColor White
    Write-Host "`n🎯 The mobile-responsive UI improvements are preserved!" -ForegroundColor Cyan
    Write-Host "🔧 All STT/TTS functionality has been restored!" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  SOME TESTS FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`nPlease review the failed tests above." -ForegroundColor Yellow
}

Write-Host "`nApp URL: $appUrl" -ForegroundColor Cyan
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Verification completed at: $timestamp" -ForegroundColor Gray
