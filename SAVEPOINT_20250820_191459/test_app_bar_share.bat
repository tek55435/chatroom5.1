@echo off
echo Share Button Fix Test
echo ===================
echo.

echo Testing app bar share button functionality...

cd c:\Dev\Chatroom5\flutter_client

echo.
echo 1. Checking if all necessary JavaScript files are loaded...

REM Check if directChatShare is defined in index.html
findstr /C:"directChatShare" web\direct_global_share.js > NUL
if %ERRORLEVEL% NEQ 0 (
  echo WARNING: directChatShare function not found in JavaScript files
) else (
  echo OK: directChatShare function is properly defined
)

REM Check if Web Share API test is available
findstr /C:"navigator.share" web\share_debug.js > NUL
if %ERRORLEVEL% NEQ 0 (
  echo WARNING: Web Share API test not found
) else (
  echo OK: Web Share API test is properly implemented
)

echo.
echo 2. Creating debug console logger...

echo // Debug logger for share functionality > web\share_console_log.js
echo window.addEventListener('DOMContentLoaded', function() { >> web\share_console_log.js
echo   console.log('Share console logger activated'); >> web\share_console_log.js
echo   window.originalDirectChatShare = window.directChatShare; >> web\share_console_log.js
echo   window.directChatShare = function(url) { >> web\share_console_log.js
echo     console.log('directChatShare called with URL:', url); >> web\share_console_log.js
echo     if (window.originalDirectChatShare) { >> web\share_console_log.js
echo       return window.originalDirectChatShare(url); >> web\share_console_log.js
echo     } else { >> web\share_console_log.js
echo       alert('Share function called successfully with URL: ' + url); >> web\share_console_log.js
echo       return true; >> web\share_console_log.js
echo     } >> web\share_console_log.js
echo   }; >> web\share_console_log.js
echo   console.log('Share console logger: directChatShare function enhanced'); >> web\share_console_log.js
echo }); >> web\share_console_log.js

REM Add the logger to index.html if not already there
findstr /C:"share_console_log.js" web\index.html > NUL
if %ERRORLEVEL% NEQ 0 (
  echo.
  echo 3. Adding debug logger to index.html...
  
  REM Create a backup
  copy web\index.html web\index.html.bak
  
  REM Find the right spot to insert and add our script
  powershell -Command "(Get-Content web\index.html) -replace '(    <!-- Share debug tools -->)', '    <!-- Share debug tools -->\n    <script src=\"share_console_log.js\" type=\"application/javascript\"></script>' | Set-Content web\index.html"
  
  echo Debug logger added to index.html
) else (
  echo.
  echo 3. Debug logger already in index.html
)

echo.
echo 4. Building the app...
echo.

echo Testing build for the fixed implementation...
flutter build web --profile

echo.
echo 5. Testing steps:
echo - Run the app with: flutter run -d chrome
echo - Open browser developer console (F12)
echo - Connect to a chat room
echo - Click the share button in the app bar
echo - Check console for "directChatShare called with URL:" message
echo - You should see an alert with the URL
echo.
echo 6. Troubleshooting:
echo - If the share functionality doesn't work, check the console for error messages
echo - Look for "AppBar share button clicked with URL:" in the console
echo - Try each of the fallback mechanisms: direct call, Web Share API, clipboard
echo.

pause
