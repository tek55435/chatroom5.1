$body = @{ text = 'Final server health check' } | ConvertTo-Json
$outFile = 'C:\Dev\Chatroom5\server\logs\final_health_check.wav'

try {
    Invoke-WebRequest -Uri 'http://localhost:3000/api/tts' -Method POST -Body $body -ContentType 'application/json' -OutFile $outFile -ErrorAction Stop
    Write-Host "API call successful."
} catch {
    Write-Host "API call FAILED: $($_.Exception.Message)"
}

if (Test-Path $outFile) {
    $fileInfo = Get-Item -Path $outFile
    Write-Host "Verification SUCCESS: File '$($fileInfo.Name)' created with length $($fileInfo.Length) bytes."
} else {
    Write-Host "Verification FAILED: File was not created."
}
