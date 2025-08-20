# Check WebRTC connectivity to deployed service

$apiUrl = "https://hear-all-v11-1.uc.r.appspot.com"

# 1. Test the API health endpoint
Write-Host "Testing API health endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$apiUrl/api/health" -Method Get -TimeoutSec 10
    Write-Host "Health check successful: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "Health check failed: $_" -ForegroundColor Red
}

# 2. Create a simple SDP offer for testing
$testSdp = @"
v=0
o=- 1234567890 1 IN IP4 0.0.0.0
s=-
t=0 0
a=group:BUNDLE audio
m=audio 9 UDP/TLS/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:test
a=ice-pwd:test1234567890123456
a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
a=setup:actpass
a=mid:audio
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1
a=rtcp-fb:111 transport-cc
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=recvonly
a=rtcp-mux
"@

Write-Host "Testing WebRTC /offer endpoint..." -ForegroundColor Yellow
try {
    $headers = @{
        "Content-Type" = "application/json"
    }
    $body = @{
        sdp = $testSdp
    } | ConvertTo-Json

    # Send the test offer
    $response = Invoke-RestMethod -Uri "$apiUrl/offer" -Method Post -Headers $headers -Body $body -TimeoutSec 30
    
    Write-Host "WebRTC offer successfully processed" -ForegroundColor Green
    Write-Host "Response SDP received (first 100 chars):" -ForegroundColor Green
    Write-Host ($response.Substring(0, [Math]::Min(100, $response.Length)))
    
} catch {
    Write-Host "WebRTC test failed: $_" -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host "Error details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}

Write-Host "`nVerification complete. If both tests passed, the WebRTC fix is working."
Write-Host "For complete validation, test the app in a browser at: $apiUrl"
