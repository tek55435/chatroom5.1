# Complete Cross-Platform WebRTC Verification Script
Write-Host "=== Testing Cross-Platform WebRTC Fix ===" -ForegroundColor Magenta

$cloudUrl = "https://hear-all-v11-1.uc.r.appspot.com"
$localUrl = "http://localhost:3000"

Write-Host ""
Write-Host "Testing Cloud Deployment..." -ForegroundColor Yellow

# Test 1: Health check
Write-Host "1. Health Check..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "$cloudUrl/api/health" -TimeoutSec 10
    Write-Host "   ✅ Status: $($health.status)" -ForegroundColor Green
    Write-Host "   ✅ OpenAI Key: $($health.openaiKeyPresent)" -ForegroundColor Green
    Write-Host "   ✅ Model: $($health.model)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Health check failed: $_" -ForegroundColor Red
}

# Test 2: WebRTC Offer endpoint
Write-Host "2. WebRTC Offer Endpoint..." -ForegroundColor Cyan
$testSdp = @"
v=0
o=- 1234567890123456 1 IN IP4 0.0.0.0
s=-
t=0 0
a=group:BUNDLE audio
m=audio 9 UDP/TLS/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:test1234
a=ice-pwd:test1234567890123456789012
a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
a=setup:actpass
a=mid:audio
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1
a=recvonly
a=rtcp-mux
"@

try {
    $headers = @{
        "Content-Type" = "application/json"
    }
    $body = @{
        sdp = $testSdp
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$cloudUrl/offer" -Method POST -Headers $headers -Body $body -TimeoutSec 30
    
    if ($response.StatusCode -eq 200) {
        $responseText = $response.Content
        if ($responseText.StartsWith("v=")) {
            Write-Host "   ✅ WebRTC offer processed successfully" -ForegroundColor Green
            Write-Host "   ✅ Response SDP format correct (starts with 'v=')" -ForegroundColor Green
            Write-Host "   ✅ Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Response doesn't start with 'v=' (SDP format issue)" -ForegroundColor Red
            Write-Host "   Response starts with: $($responseText.Substring(0, [Math]::Min(50, $responseText.Length)))" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ WebRTC offer failed with status: $($response.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ WebRTC offer test failed: $_" -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host "   Error details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

# Test 3: TTS endpoint
Write-Host "3. TTS Endpoint..." -ForegroundColor Cyan
try {
    $headers = @{
        "Content-Type" = "application/json"
    }
    $body = @{
        text = "This is a test of the text to speech system"
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$cloudUrl/api/tts" -Method POST -Headers $headers -Body $body -TimeoutSec 30
    
    if ($response.StatusCode -eq 200 -and $response.Headers.'Content-Type' -like "*audio*") {
        Write-Host "   ✅ TTS endpoint working (returned audio data)" -ForegroundColor Green
        Write-Host "   ✅ Content-Type: $($response.Headers.'Content-Type')" -ForegroundColor Green
    } else {
        Write-Host "   ❌ TTS endpoint failed or returned wrong content type" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ TTS test failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Testing Local Development (if server is running)..." -ForegroundColor Yellow

# Test local server if running
Write-Host "4. Local Server Check..." -ForegroundColor Cyan
try {
    $localHealth = Invoke-RestMethod -Uri "$localUrl/api/health" -TimeoutSec 5
    Write-Host "   ✅ Local server running" -ForegroundColor Green
    Write-Host "   ✅ Status: $($localHealth.status)" -ForegroundColor Green
    
    # Test local WebRTC
    try {
        $response = Invoke-WebRequest -Uri "$localUrl/offer" -Method POST -Headers @{"Content-Type"="application/json"} -Body (@{sdp=$testSdp} | ConvertTo-Json) -TimeoutSec 10
        if ($response.Content.StartsWith("v=")) {
            Write-Host "   ✅ Local WebRTC working" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Local WebRTC response format issue" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️  Local WebRTC test failed (may need API key): $_" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Local server not running or not accessible" -ForegroundColor Yellow
    Write-Host "   To test locally, run: cd C:\Dev\Chatroom5\server && node appengine-server.js" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Cross-Platform URL Resolution Test..." -ForegroundColor Yellow

# Test URL resolution logic
Write-Host "5. URL Resolution Logic..." -ForegroundColor Cyan
Write-Host "   Expected behavior:" -ForegroundColor Gray
Write-Host "     • localhost access: http://localhost:3000" -ForegroundColor Gray
Write-Host "     • Cloud access: https://hear-all-v11-1.uc.r.appspot.com" -ForegroundColor Gray
Write-Host "     • Mac remote access: automatically uses cloud URL" -ForegroundColor Gray
Write-Host "     • Windows localhost: forces http:// (never https://)" -ForegroundColor Gray

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Magenta

Write-Host ""
Write-Host "If all tests passed:" -ForegroundColor Green
Write-Host "  ✅ Mac users should no longer see 'Expect line: v=' errors" -ForegroundColor White
Write-Host "  ✅ Windows users should no longer see 'https://localhost' errors" -ForegroundColor White
Write-Host "  ✅ Both platforms should have working STT, TTS, and WebRTC" -ForegroundColor White

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test the app in browsers on both Mac and Windows" -ForegroundColor White
Write-Host "  2. Verify STT recording works" -ForegroundColor White
Write-Host "  3. Verify TTS playback works" -ForegroundColor White
Write-Host "  4. Verify WebRTC audio streaming works" -ForegroundColor White

Write-Host ""
Write-Host "App URLs:" -ForegroundColor Cyan
Write-Host "  Cloud:  $cloudUrl" -ForegroundColor White
Write-Host "  Local:  $localUrl" -ForegroundColor White
