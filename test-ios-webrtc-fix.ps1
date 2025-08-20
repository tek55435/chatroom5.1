# iOS WebRTC Fix Test Script

Write-Host "=== Testing iOS WebRTC Fix ===" -ForegroundColor Green

$baseUrl = "https://hear-all-v11-1.uc.r.appspot.com"

Write-Host "`n1. Testing WebRTC SDP Format..." -ForegroundColor Cyan

# Create a proper test SDP offer (similar to what iOS WebRTC would send)
$testSdp = "v=0`r`no=- 12345678901234567890 2 IN IP4 127.0.0.1`r`ns=-`r`nt=0 0`r`na=group:BUNDLE 0`r`na=extmap-allow-mixed`r`na=msid-semantic: WMS`r`nm=audio 9 UDP/TLS/RTP/SAVPF 111 63 103 104 9 0 8 106 105 13 110 112 113 126`r`nc=IN IP4 0.0.0.0`r`na=rtcp:9 IN IP4 0.0.0.0`r`na=ice-ufrag:test1234`r`na=ice-pwd:testpassword1234567890123456`r`na=ice-options:trickle`r`na=fingerprint:sha-256 12:34:56:78:9A:BC:DE:F0:12:34:56:78:9A:BC:DE:F0:12:34:56:78:9A:BC:DE:F0:12:34:56:78:9A:BC:DE:F0`r`na=setup:actpass`r`na=mid:0`r`na=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level`r`na=sendrecv`r`na=rtcp-mux`r`na=rtpmap:111 opus/48000/2`r`na=fmtp:111 minptime=10;useinbandfec=1`r`n"

$body = @{
    sdp = $testSdp
    model = "gpt-4o-realtime-preview-2024-12-17"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/offer" -Method Post -Body $body -ContentType "application/json"
    
    # Validate SDP response
    if ($response.StartsWith("v=")) {
        Write-Host "   ✅ SDP response starts with 'v='" -ForegroundColor Green
    } else {
        Write-Host "   ❌ SDP response does not start with 'v='" -ForegroundColor Red
    }
    
    if ($response.Contains("`r`n")) {
        Write-Host "   ✅ SDP contains proper CRLF line endings" -ForegroundColor Green
    } else {
        Write-Host "   ❌ SDP missing CRLF line endings" -ForegroundColor Red
    }
    
    # Check for required SDP fields
    $requiredFields = @("o=", "s=", "t=", "m=audio", "a=fingerprint", "a=ice-ufrag", "a=ice-pwd", "a=rtpmap")
    $missingFields = @()
    
    foreach ($field in $requiredFields) {
        if ($response.Contains($field)) {
            Write-Host "   ✅ Contains required field: $field" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Missing required field: $field" -ForegroundColor Red
            $missingFields += $field
        }
    }
    
    if ($missingFields.Count -eq 0) {
        Write-Host "   ✅ All required SDP fields present" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Missing SDP fields: $($missingFields -join ', ')" -ForegroundColor Red
    }
    
    Write-Host "   📊 SDP Response Length: $($response.Length) characters" -ForegroundColor Yellow
    
} catch {
    Write-Host "   ❌ WebRTC offer failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n2. Testing TTS Endpoint..." -ForegroundColor Cyan

$ttsBody = @{
    text = "Testing iOS audio after enabling user interaction"
    voice = "alloy"
} | ConvertTo-Json

try {
    $ttsResponse = Invoke-RestMethod -Uri "$baseUrl/api/tts" -Method Post -Body $ttsBody -ContentType "application/json"
    
    if ($ttsResponse -and $ttsResponse.Length -gt 1000) {
        Write-Host "   ✅ TTS endpoint working (returned $($ttsResponse.Length) bytes of audio)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ TTS endpoint returned insufficient data" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ TTS endpoint failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== iOS Testing Instructions ===" -ForegroundColor Yellow
Write-Host "On your iPhone:" -ForegroundColor White
Write-Host "1. Open Safari and go to: $baseUrl" -ForegroundColor White
Write-Host "2. You should see an orange banner: 'Tap to enable audio on iOS'" -ForegroundColor White
Write-Host "3. Tap the 'Enable Audio' button" -ForegroundColor White
Write-Host "4. Banner should disappear and audio should be unlocked" -ForegroundColor White
Write-Host "5. WebRTC errors should be resolved (no more 'Invalid SDP line')" -ForegroundColor White
Write-Host "6. TTS messages from PC should now play audibly" -ForegroundColor White

Write-Host "`n=== Expected Log Changes ===" -ForegroundColor Yellow
Write-Host "Before fix:" -ForegroundColor Red
Write-Host "  • [retry] Network error joining session... (Invalid SDP line)" -ForegroundColor Red
Write-Host "After fix:" -ForegroundColor Green  
Write-Host "  • WebRTC connection should succeed" -ForegroundColor Green
Write-Host "  • [audio] iOS audio system unlocked and ready" -ForegroundColor Green
Write-Host "  • TTS messages play with audio output" -ForegroundColor Green

Write-Host "`nApp URL: $baseUrl" -ForegroundColor Green
Write-Host "Fix Status: WebRTC SDP format corrected + iOS audio unlock implemented" -ForegroundColor Green
