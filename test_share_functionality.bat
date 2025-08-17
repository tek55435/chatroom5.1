@echo off
echo Share Button Functionality Test Script
echo ====================================

echo.
echo Step 1: Creating a test button
echo ----------------------------
echo This will add a test button to the page that will help diagnose share issues

echo var btn = document.createElement('button');> test_share_button.js
echo btn.textContent = 'Test Share Functions';>> test_share_button.js
echo btn.style.position = 'fixed';>> test_share_button.js
echo btn.style.bottom = '20px';>> test_share_button.js
echo btn.style.right = '20px';>> test_share_button.js
echo btn.style.zIndex = '9999';>> test_share_button.js
echo btn.style.backgroundColor = '#4CAF50';>> test_share_button.js
echo btn.style.color = 'white';>> test_share_button.js
echo btn.style.padding = '10px';>> test_share_button.js
echo btn.style.border = 'none';>> test_share_button.js
echo btn.style.cursor = 'pointer';>> test_share_button.js
echo btn.onclick = function() {>> test_share_button.js
echo     console.log('Test button clicked');>> test_share_button.js
echo     if (typeof ShareDebug === 'object') {>> test_share_button.js
echo         ShareDebug.testShareFunctions();>> test_share_button.js
echo         ShareDebug.testShare();>> test_share_button.js
echo     } else {>> test_share_button.js
echo         console.error('ShareDebug not found');>> test_share_button.js
echo         alert('ShareDebug not found - check console for details');>> test_share_button.js
echo     }>> test_share_button.js
echo };>> test_share_button.js
echo document.body.appendChild(btn);>> test_share_button.js
echo console.log('Test share button added to page');>> test_share_button.js

echo.
echo Step 2: Adding direct global share function
echo --------------------------------------
echo This guarantees the directChatShare function is available globally

echo window.directChatShare = function(url) {> direct_global_share.js
echo     console.log('DIRECT GLOBAL directChatShare called with URL:', url);>> direct_global_share.js
echo     alert('Share button clicked with URL: ' + url);>> direct_global_share.js
echo     try {>> direct_global_share.js
echo         if (navigator.clipboard) {>> direct_global_share.js
echo             navigator.clipboard.writeText(url);>> direct_global_share.js
echo             alert('Chat URL copied to clipboard: ' + url);>> direct_global_share.js
echo         } else {>> direct_global_share.js
echo             var textarea = document.createElement('textarea');>> direct_global_share.js
echo             textarea.value = url;>> direct_global_share.js
echo             document.body.appendChild(textarea);>> direct_global_share.js
echo             textarea.select();>> direct_global_share.js
echo             document.execCommand('copy');>> direct_global_share.js
echo             document.body.removeChild(textarea);>> direct_global_share.js
echo             alert('Chat URL copied to clipboard: ' + url);>> direct_global_share.js
echo         }>> direct_global_share.js
echo         return true;>> direct_global_share.js
echo     } catch(e) {>> direct_global_share.js
echo         alert('Please copy this URL manually: ' + url);>> direct_global_share.js
echo         return false;>> direct_global_share.js
echo     }>> direct_global_share.js
echo };>> direct_global_share.js
echo console.log('Direct Global Share function installed');>> direct_global_share.js

echo.
echo Step 3: Copying files to web directory
echo ---------------------------------
copy test_share_button.js c:\Dev\Chatroom5\flutter_client\web\
copy direct_global_share.js c:\Dev\Chatroom5\flutter_client\web\

echo.
echo Step 4: Adding script tags to index.html
echo -----------------------------------
echo Adding script tags to index.html...

powershell -Command "(Get-Content c:\Dev\Chatroom5\flutter_client\web\index.html) -replace '<!-- Debug tools for chat -->', '<!-- Debug tools for chat -->\n    <script src=\"test_share_button.js\" type=\"application/javascript\"></script>\n    <script src=\"direct_global_share.js\" type=\"application/javascript\"></script>' | Set-Content c:\Dev\Chatroom5\flutter_client\web\index.html"

echo.
echo Installation Complete!
echo ===================
echo.
echo Please run the Flutter application with:
echo.
echo   cd c:\Dev\Chatroom5\flutter_client
echo   flutter run -d chrome
echo.
echo Then check the console for share debugging information.
echo.

pause
