# App Engine Deployment Script for Chatroom5

param(
    [string]$ProjectId = "hear-all-v11-1",
    [switch]$SkipBuild = $false,
    [switch]$DeployServerOnly = $false,
    [switch]$DeployWebOnly = $false
)

Write-Host "Starting App Engine Deployment for Chatroom5" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Yellow

# Set gcloud project
Write-Host "Setting gcloud project..." -ForegroundColor Green
gcloud config set project $ProjectId

if (-not $DeployWebOnly) {
    Write-Host "Deploying Backend Server..." -ForegroundColor Cyan
    
    # Check if server/.env exists
    if (-not (Test-Path "server\.env")) {
        Write-Warning "server\.env not found. Please create it with your OPENAI_API_KEY"
        Write-Host "Copy server\.env.example to server\.env and add your API key" -ForegroundColor Yellow
        exit 1
    }
    
    # Deploy server
    Push-Location server
    try {
        Write-Host "Deploying server to App Engine..." -ForegroundColor Green
        gcloud app deploy app.yaml --quiet
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Server deployed successfully!" -ForegroundColor Green
        } else {
            Write-Error "Server deployment failed"
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

if (-not $DeployServerOnly) {
    Write-Host "Preparing Flutter Web App..." -ForegroundColor Cyan
    
    # Create Flutter app.yaml if it doesn't exist
    $flutterAppYaml = "flutter_client\app.yaml"
    if (-not (Test-Path $flutterAppYaml)) {
        Write-Host "Creating flutter_client/app.yaml..." -ForegroundColor Green
        
        $yamlContent = "runtime: nodejs20

handlers:
  - url: /
    static_files: build/web/index.html
    upload: build/web/index.html
    secure: always
    
  - url: /(.*)
    static_files: build/web/\1
    upload: build/web/(.*)
    secure: always

env_variables:
  NODE_ENV: `"production`""
        
        $yamlContent | Out-File -FilePath $flutterAppYaml -Encoding UTF8
        Write-Host "Created flutter_client/app.yaml" -ForegroundColor Green
    }
    
    # Build Flutter web app
    if (-not $SkipBuild) {
        Write-Host "Building Flutter web app..." -ForegroundColor Green
        Push-Location flutter_client
        try {
            flutter build web --release
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Flutter build completed!" -ForegroundColor Green
            } else {
                Write-Error "Flutter build failed"
                exit 1
            }
        }
        finally {
            Pop-Location
        }
    }
    
    # Check if build directory exists
    if (-not (Test-Path "flutter_client\build\web")) {
        Write-Error "Flutter build/web directory not found. Run 'flutter build web' first or remove -SkipBuild flag"
        exit 1
    }
    
    # Deploy Flutter web app
    Write-Host "Deploying Flutter web app to App Engine..." -ForegroundColor Green
    Push-Location flutter_client
    try {
        gcloud app deploy app.yaml --quiet
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Web app deployed successfully!" -ForegroundColor Green
        } else {
            Write-Error "Web app deployment failed"
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

# Get the app URL
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "Your app is available at: https://hear-all-v11-1.uc.r.appspot.com" -ForegroundColor Green

Write-Host "To view logs: gcloud app logs tail -s default" -ForegroundColor Yellow
Write-Host "To view app info: gcloud app describe" -ForegroundColor Yellow
