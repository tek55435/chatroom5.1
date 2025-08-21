$port = 3000
Write-Host "Checking for process on port $port..."
$conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
if ($conn) {
  $pids = $conn | Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($p in $pids) {
    try {
      Write-Host "Killing PID $p"
      Stop-Process -Id $p -Force -ErrorAction Stop
    } catch {
      Write-Host ("Failed to kill PID {0}: {1}" -f $p, $_.Exception.Message)
    }
  }
} else {
  Write-Host "No process on port $port"
}

Write-Host "Starting node index.cjs in $PWD"
Start-Process -FilePath "node" -ArgumentList "index.cjs" -WorkingDirectory $PWD -NoNewWindow
Start-Sleep -Seconds 1
Write-Host "Listener status:"
Get-NetTCPConnection -LocalPort $port | Select-Object LocalAddress,LocalPort,State,OwningProcess | Format-List
