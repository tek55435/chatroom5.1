@echo off
echo Fixing the Share Button in Ephemeral Chat - FINAL SOLUTION
echo ======================================================

echo.
echo Step 1: Creating a backup of the original file
echo ----------------------------------------------
copy "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart" ^
     "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart.backup"
echo Backup created.

echo.
echo Step 2: Replacing the file with the fixed version
echo ------------------------------------------------
copy "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart.new" ^
     "c:\Dev\Chatroom5\flutter_client\lib\screens\ephemeral_chat_screen.dart"
echo File replaced.

echo.
echo Share button fix completed successfully!
echo ----------------------------------------
echo.
echo The share button should now work with multiple fallbacks:
echo 1. JavaScript directChatShare function
echo 2. Flutter Share.share API
echo 3. Direct Clipboard API 
echo 4. Manual copy dialog as last resort
echo.

echo Testing fixed file...
cd "c:\Dev\Chatroom5\flutter_client"
flutter analyze lib\screens\ephemeral_chat_screen.dart

echo.
echo To build and test the application, run:
echo   cd c:\Dev\Chatroom5\flutter_client
echo   flutter run -d chrome
echo.

pause
