Set-Location -Path 'C:\Dev\Chatroom5\server'
Write-Host "Checking port 3001..."
$conn = Get-NetTCPConnection -LocalPort 3001 -ErrorAction SilentlyContinue
if ($conn) { Write-Host "Port 3001 has connections (state):"; $conn | Select-Object LocalAddress,LocalPort,State,OwningProcess | Format-List } else { Write-Host "Port 3001 not in use" }

# Try HTTP GET
try {
  Write-Host "Attempting GET http://localhost:3001/api/chat/new-session"
  $r = Invoke-RestMethod -Uri 'http://localhost:3001/api/chat/new-session' -Method Get -TimeoutSec 5 -UseBasicParsing
  Write-Host "Response:"; $r | ConvertTo-Json
  exit 0
} catch {
  Write-Host "GET failed: $($_.Exception.Message)"
}

# Start ephemeral chat server if not running
Write-Host "Starting ephemeral-chat-server.cjs..."
Start-Process -FilePath 'node' -ArgumentList 'ephemeral-chat-server.cjs' -WorkingDirectory (Get-Location) -NoNewWindow
Start-Sleep -Seconds 1

# Retry GET
try {
  Write-Host "Retrying GET http://localhost:3001/api/chat/new-session"
  $r = Invoke-RestMethod -Uri 'http://localhost:3001/api/chat/new-session' -Method Get -TimeoutSec 10 -UseBasicParsing
  Write-Host "Response after start:"; $r | ConvertTo-Json
  exit 0
} catch {
  Write-Host "Still failed after start: $($_.Exception.Message)"
  exit 1
}
