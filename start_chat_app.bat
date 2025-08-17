@echo off
echo Starting Ephemeral Chat Server and Flutter Web App...
echo.

REM Start the server in a new window
start cmd /k "cd C:\Dev\Chatroom5\server && node ephemeral-chat-server.cjs"

REM Wait for server to initialize
echo Waiting for server to start...
timeout /t 5 /nobreak

REM Start Flutter web app
echo Starting Flutter web app...
start cmd /k "cd C:\Dev\Chatroom5\flutter_client && flutter run -d chrome"

echo.
echo Setup complete! You should see:
echo 1. A server window with the Ephemeral Chat server running
echo 2. A Flutter app with working join and share buttons
echo.
echo Happy chatting!
