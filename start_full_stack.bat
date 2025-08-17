@echo off
echo Starting Chatroom5 Full Stack App...
echo.

REM Change to the root directory
cd /d C:\Dev\Chatroom5

REM Check for running servers and stop them
echo Checking for running servers...

REM Check if any process is using port 3000
netstat -ano | findstr :3000 >nul
if %ERRORLEVEL% EQU 0 (
    echo Port 3000 is already in use. Attempting to free it...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000') do (
        taskkill /F /PID %%a
        if %ERRORLEVEL% EQU 0 (
            echo Successfully terminated process using port 3000
        ) else (
            echo Warning: Could not terminate process using port 3000
        )
    )
) else (
    echo Port 3000 is free
)

REM Check if any process is using port 3001
netstat -ano | findstr :3001 >nul
if %ERRORLEVEL% EQU 0 (
    echo Port 3001 is already in use. Attempting to free it...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3001') do (
        taskkill /F /PID %%a
        if %ERRORLEVEL% EQU 0 (
            echo Successfully terminated process using port 3001
        ) else (
            echo Warning: Could not terminate process using port 3001
        )
    )
) else (
    echo Port 3001 is free
)

echo.
echo Starting Main Server on port 3000...
start cmd /k "title Main Server && cd /d C:\Dev\Chatroom5\server && node index.js"

timeout /t 2 /nobreak >nul

echo Starting Chat Server on port 3001...
start cmd /k "title Chat Server && cd /d C:\Dev\Chatroom5\server && node ephemeral-chat-server.cjs"

timeout /t 2 /nobreak >nul

echo.
echo Both servers started successfully!
echo  - Main Server: http://localhost:3000
echo  - Chat Server: ws://localhost:3001
echo.

echo Starting Flutter Web App...
start cmd /k "title Flutter Web App && cd /d C:\Dev\Chatroom5\flutter_client && flutter clean && flutter pub get && flutter run -d chrome"

echo.
echo Full stack started! Check the terminal windows for details.
echo.

pause
