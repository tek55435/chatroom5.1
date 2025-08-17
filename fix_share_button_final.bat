@echo off
echo Fixing the Share Button in Ephemeral Chat...

echo.
echo Step 1: Creating a backup of the original file
echo ----------------------------------------------
copy "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart" ^
     "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart.bak"
echo Backup created.

echo.
echo Step 2: Replacing the file with the fixed version
echo ------------------------------------------------
copy "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart.fixed" ^
     "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart"
echo File replaced.

echo.
echo Step 3: Verifying that share_fix.js is included
echo ----------------------------------------------
type "c:\Dev\Chatroom5\flutter_client\web\index.html" | findstr "share_fix.js"
if %ERRORLEVEL% NEQ 0 (
  echo WARNING: share_fix.js is not included in the HTML file.
)

echo.
echo Step 4: Verifying that direct_share.js is included
echo ------------------------------------------------
type "c:\Dev\Chatroom5\flutter_client\web\index.html" | findstr "direct_share.js"
if %ERRORLEVEL% NEQ 0 (
  echo WARNING: direct_share.js is not included in the HTML file.
)

echo.
echo Step 5: Running Flutter build to verify the fix
echo ---------------------------------------------
cd "c:\Dev\Chatroom5\flutter_client"
flutter pub get
flutter build web --profile

echo.
echo Share button fix completed!
echo Try running the application to verify that sharing works.
echo.

pause
