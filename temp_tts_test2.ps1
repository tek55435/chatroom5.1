$tmp = Join-Path $env:TEMP 'tts_test_resp.bin'
$body = @{ text = 'smoke test' } | ConvertTo-Json
try {
  Invoke-WebRequest -Uri 'http://localhost:3000/api/tts' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 60 -OutFile $tmp -UseBasicParsing
  Write-Host "Saved to $tmp"
  $len=(Get-Item $tmp).Length
  Write-Host "Size= $len"
  $bytes=Get-Content -Path $tmp -Encoding Byte -TotalCount 12
  $hex=($bytes|ForEach-Object { $_.ToString('X2') }) -join ' '
  Write-Host "First bytes: $hex"
} catch {
  Write-Host "POST /api/tts failed: $($_.Exception.Message)"
}
