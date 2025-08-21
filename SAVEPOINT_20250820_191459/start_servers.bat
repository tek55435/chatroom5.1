@echo off
echo Starting main server and ephemeral chat server...

REM Start the main server (background)
cd /d "%~dp0server"
start cmd /k "node index.js"

REM Start the ephemeral chat server (background)
start cmd /k "node ephemeral-chat-server.cjs"

REM Wait a moment to ensure servers have started
timeout /t 2 /nobreak >nul

REM Start Flutter web server
cd /d "%~dp0flutter_client"
echo Starting Flutter web server...
flutter run -d chrome --web-port 8000 --web-hostname localhost
