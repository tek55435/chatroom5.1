# Deploy Chatroom5 to Google Cloud App Engine
# This script deploys the app with the OpenAI API key from the .env file

# Load the OpenAI API key from .env
$envPath = "C:\Dev\Chatroom5\server\.env"
$apiKey = ""

if (Test-Path $envPath) {
    $envContent = Get-Content $envPath
    foreach ($line in $envContent) {
        if ($line -match "OPENAI_API_KEY=(.+)") {
            $apiKey = $matches[1]
            break
        }
    }
}

if (-not $apiKey) {
    Write-Host "Error: Could not find OPENAI_API_KEY in .env file" -ForegroundColor Red
    exit 1
}

# Navigate to server directory
Set-Location -Path "C:\Dev\Chatroom5\server"

# Check if user is logged into gcloud
$loginCheck = gcloud auth list --filter=status:ACTIVE --format="value(account)"
if (-not $loginCheck) {
    Write-Host "You need to log in to Google Cloud first" -ForegroundColor Yellow
    gcloud auth login
}

# Set the project
Write-Host "Setting Google Cloud project to: hear-all-v11-1" -ForegroundColor Cyan
gcloud config set project hear-all-v11-1

# Update app.yaml with the API key
Write-Host "Updating app.yaml with API key..." -ForegroundColor Cyan
$appYamlPath = "app.yaml"
$appYamlContent = Get-Content $appYamlPath -Raw
$updatedContent = $appYamlContent -replace "# OPENAI_API_KEY will be set during deployment", "OPENAI_API_KEY: `"$apiKey`""
Set-Content -Path $appYamlPath -Value $updatedContent

# Deploy the app
Write-Host "Deploying Chatroom5 to Google App Engine..." -ForegroundColor Cyan
gcloud app deploy --quiet

# Get the deployed URL
$url = (gcloud app describe --format="value(defaultHostname)") 2>$null
if (-not $url) {
    $url = "hear-all-v11-1.uc.r.appspot.com" # Default URL pattern for App Engine
}
Write-Host "`nDeployment complete!" -ForegroundColor Green
Write-Host "Your app is available at: https://$url" -ForegroundColor Green
