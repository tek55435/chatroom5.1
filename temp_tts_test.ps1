$body = @{ text = "Automated TTS smoke test" } | ConvertTo-Json
$tmp = Join-Path $env:TEMP "tts_smoke_test.bin"
try {
    Invoke-WebRequest -Uri "http://localhost:3000/api/tts" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 60 -OutFile $tmp -UseBasicParsing
    $len = (Get-Item $tmp).Length
    Write-Host "Saved to $tmp; size=$len"
    $bytes = Get-Content -Path $tmp -Encoding Byte -TotalCount 16
    $preview = ($bytes | ForEach-Object { $_.ToString("X2") }) -join " "
    Write-Host "First bytes (hex): $preview"
} catch {
    Write-Host "POST /api/tts failed: $($_.Exception.Message)"
}
