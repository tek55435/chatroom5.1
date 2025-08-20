# iOS Audio Fix Test Script
# Tests the iOS audio enable functionality

Write-Host "=== Testing iOS Audio Fix Deployment ===" -ForegroundColor Green
Write-Host "Date: $(Get-Date)" -ForegroundColor Yellow

$baseUrl = "https://hear-all-v11-1.uc.r.appspot.com"

Write-Host "`nTesting deployed application..." -ForegroundColor Cyan

# 1. Test health check
Write-Host "1. Health Check..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET
    if ($healthResponse.status -eq "ok") {
        Write-Host "   ✅ Server health: OK" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Server health check failed" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Test TTS endpoint
Write-Host "2. TTS Endpoint Test..." -ForegroundColor Yellow
try {
    $ttsBody = @{
        text = "iOS audio test message"
        voice = "alloy"
    } | ConvertTo-Json

    $ttsResponse = Invoke-WebRequest -Uri "$baseUrl/api/tts" -Method POST -Body $ttsBody -ContentType "application/json"
    
    if ($ttsResponse.StatusCode -eq 200) {
        Write-Host "   ✅ TTS endpoint working (returned $($ttsResponse.RawContentLength) bytes)" -ForegroundColor Green
        Write-Host "   ✅ Content-Type: $($ttsResponse.Headers['Content-Type'])" -ForegroundColor Green
    } else {
        Write-Host "   ❌ TTS endpoint failed with status: $($ttsResponse.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ TTS test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Test main page load
Write-Host "3. Main Page Load Test..." -ForegroundColor Yellow
try {
    $pageResponse = Invoke-WebRequest -Uri $baseUrl -Method GET
    if ($pageResponse.StatusCode -eq 200) {
        Write-Host "   ✅ Main page loaded successfully" -ForegroundColor Green
        
        # Check for Flutter app indicators
        $content = $pageResponse.Content
        if ($content -like "*flutter*" -or $content -like "*main.dart.js*") {
            Write-Host "   ✅ Flutter web app detected in page" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Flutter app not detected in page content" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Main page failed to load: $($pageResponse.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Page load test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== iOS Testing Instructions ===" -ForegroundColor Cyan
Write-Host "1. Open Safari or Chrome on your iPhone" -ForegroundColor White
Write-Host "2. Navigate to: $baseUrl" -ForegroundColor White
Write-Host "3. Look for an ORANGE BANNER at the top saying 'Tap to enable audio on iOS'" -ForegroundColor White
Write-Host "4. Tap the 'Enable Audio' button" -ForegroundColor White
Write-Host "5. The banner should disappear" -ForegroundColor White
Write-Host "6. Send a TTS message from PC and it should now play audio on iPhone" -ForegroundColor White

Write-Host "`n=== Expected Behavior ===" -ForegroundColor Cyan
Write-Host "Before enabling audio:" -ForegroundColor Yellow
Write-Host "  • Orange banner visible on iOS devices" -ForegroundColor White
Write-Host "  • TTS messages sent but no audio heard" -ForegroundColor White
Write-Host "  • Logs show 'Direct TTS audio playing' but silent" -ForegroundColor White

Write-Host "`nAfter enabling audio:" -ForegroundColor Yellow
Write-Host "  • Orange banner disappears" -ForegroundColor White  
Write-Host "  • TTS messages play audibly" -ForegroundColor White
Write-Host "  • Logs show 'iOS audio system unlocked and ready'" -ForegroundColor White

Write-Host "`n=== Diagnostic Information ===" -ForegroundColor Cyan
Write-Host "Check the Diagnostics panel for:" -ForegroundColor White
Write-Host "  • [iOS] Device detected: [user agent string]" -ForegroundColor White
Write-Host "  • [iOS] Audio enabled: true/false" -ForegroundColor White
Write-Host "  • [audio] Context state information" -ForegroundColor White

Write-Host "`n=== Troubleshooting ===" -ForegroundColor Cyan
Write-Host "If audio still doesn't work after enabling:" -ForegroundColor Yellow
Write-Host "  1. Check iPhone volume is up" -ForegroundColor White
Write-Host "  2. Check iPhone is not in silent mode" -ForegroundColor White
Write-Host "  3. Try playing a YouTube video to test general audio" -ForegroundColor White
Write-Host "  4. Refresh the page and try enabling audio again" -ForegroundColor White
Write-Host "  5. Check browser console for any additional errors" -ForegroundColor White

Write-Host "`nApp URL: $baseUrl" -ForegroundColor Green
Write-Host "Test completed at: $(Get-Date)" -ForegroundColor Yellow
