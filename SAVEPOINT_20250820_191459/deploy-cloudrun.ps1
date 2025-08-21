Param(
  [string]$ProjectId = "hear-all-v11-1",
  [string]$Region = "us-central1",
  [string]$OpenAIKey,
  [string]$Model
)

# Try to read from server/.env if not provided
if (-not $OpenAIKey -or -not $Model) {
  $envPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'server') -ChildPath '.env'
  if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Raw
    if (-not $OpenAIKey) {
      $m = [regex]::Match($envContent, "(?m)^OPENAI_API_KEY\s*=\s*(.+)$")
      if ($m.Success) { $OpenAIKey = $m.Groups[1].Value.Trim() }
    }
    if (-not $Model) {
      $m2 = [regex]::Match($envContent, "(?m)^MODEL\s*=\s*(.+)$")
      if ($m2.Success) { $Model = $m2.Groups[1].Value.Trim() }
    }
  }
}

if (-not $OpenAIKey) {
  Write-Error "Provide -OpenAIKey or set it in server/.env (OPENAI_API_KEY=...)"
  exit 1
}
if (-not $Model) { $Model = "gpt-4o-realtime-preview-2024-12-17" }

Write-Host "Setting gcloud project to $ProjectId and region $Region" -ForegroundColor Cyan
gcloud config set project $ProjectId | Out-Null
gcloud config set run/region $Region | Out-Null

# 1) Deploy API
Write-Host "Deploying API (chat5-api)..." -ForegroundColor Cyan
gcloud run deploy chat5-api --source=server --allow-unauthenticated --set-env-vars "OPENAI_API_KEY=$OpenAIKey,MODEL=$Model"

# Capture API URL
$apiUrl = (gcloud run services describe chat5-api --format="value(status.url)")
if (-not $apiUrl) { Write-Error "Failed to get API URL"; exit 1 }
Write-Host "API URL: $apiUrl"

# 2) Deploy Chat WS
Write-Host "Deploying Chat WS (chat5-ws)..." -ForegroundColor Cyan
gcloud run deploy chat5-ws --source=server-chat --allow-unauthenticated
$wsUrl = (gcloud run services describe chat5-ws --format="value(status.url)")
if (-not $wsUrl) { Write-Error "Failed to get WS URL"; exit 1 }
Write-Host "WS URL (https): $wsUrl"

# 3) Build Flutter Web with correct endpoints
$chatWs = $wsUrl -replace '^https://', 'wss://'
Write-Host "Building Flutter web with SERVER_BASE=$apiUrl CHAT_WS=$chatWs CHAT_HTTP=$wsUrl" -ForegroundColor Cyan
Push-Location flutter_client
flutter build web --release --dart-define "SERVER_BASE=$apiUrl" --dart-define "CHAT_WS=$chatWs" --dart-define "CHAT_HTTP=$wsUrl"
Pop-Location

# 4) Deploy Web static site
Write-Host "Deploying Web (chat5-web)..." -ForegroundColor Cyan
gcloud run deploy chat5-web --source=flutter_client --allow-unauthenticated
$webUrl = (gcloud run services describe chat5-web --format="value(status.url)")
Write-Host "Web URL: $webUrl" -ForegroundColor Green

Write-Host "Done. Share this link: $webUrl" -ForegroundColor Green
