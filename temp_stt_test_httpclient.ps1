Add-Type -AssemblyName System.Net.Http
$tmp = Join-Path $env:TEMP 'test_audio.bin'
[System.IO.File]::WriteAllBytes($tmp, [byte[]](0x52,0x49,0x46,0x46))
$client = New-Object System.Net.Http.HttpClient
$content = New-Object System.Net.Http.MultipartFormDataContent
$fileStream = [System.IO.File]::OpenRead($tmp)
$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('audio/webm')
$content.Add($fileContent, 'audio', 'test_audio.bin')
try {
    $resp = $client.PostAsync('http://localhost:3000/api/stt', $content).Result
    if ($resp.IsSuccessStatusCode) {
        $body = $resp.Content.ReadAsStringAsync().Result
        Write-Host 'Status:' $resp.StatusCode
        Write-Host 'Body:'
        Write-Host $body
    } else {
        Write-Host 'Status:' $resp.StatusCode
        Write-Host 'Reason:' $resp.ReasonPhrase
        $body = $resp.Content.ReadAsStringAsync().Result
        Write-Host 'Body:'
        Write-Host $body
    }
} catch {
    Write-Host "POST /api/stt failed: $($_.Exception.Message)"
} finally {
    $fileStream.Dispose()
    $content.Dispose()
    $client.Dispose()
}
