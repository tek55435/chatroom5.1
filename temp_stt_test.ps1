$tmp = Join-Path $env:TEMP "test_audio.bin"
[System.IO.File]::WriteAllBytes($tmp, [byte[]](0x52,0x49,0x46,0x46))
try {
    $resp = Invoke-RestMethod -Uri "http://localhost:3000/api/stt" -Method Post -Form @{ audio = Get-Item $tmp } -TimeoutSec 60
    Write-Host "Response:"; $resp | ConvertTo-Json -Depth 5 | Write-Host
} catch {
    Write-Host "POST /api/stt failed: $($_.Exception.Message)"
}
