@echo off
echo.
echo Fixing share button functionality...
echo.

REM Create direct share function in HTML
echo Adding direct share functionality to index.html...
echo ^<script type="application/javascript"^> >> "web/index.html"
echo   window.shareChat = function(url) { >> "web/index.html"
echo     console.log('Share button clicked for URL: ' + url); >> "web/index.html"
echo     try { >> "web/index.html"
echo       if (navigator.clipboard) { >> "web/index.html"
echo         navigator.clipboard.writeText(url); >> "web/index.html"
echo         alert('Chat URL copied to clipboard: ' + url); >> "web/index.html"
echo       } else { >> "web/index.html"
echo         var textarea = document.createElement('textarea'); >> "web/index.html"
echo         textarea.value = url; >> "web/index.html"
echo         document.body.appendChild(textarea); >> "web/index.html"
echo         textarea.select(); >> "web/index.html"
echo         document.execCommand('copy'); >> "web/index.html"
echo         document.body.removeChild(textarea); >> "web/index.html"
echo         alert('Chat URL copied to clipboard: ' + url); >> "web/index.html"
echo       } >> "web/index.html"
echo       return true; >> "web/index.html"
echo     } catch(e) { >> "web/index.html"
echo       alert('Please copy this URL manually: ' + url); >> "web/index.html"
echo       return false; >> "web/index.html"
echo     } >> "web/index.html"
echo   }; >> "web/index.html"
echo   console.log('Direct share function ready'); >> "web/index.html"
echo ^</script^> >> "web/index.html"

echo.
echo Clean and rebuild the project...
call flutter clean
call flutter pub get

echo.
echo Running the app...
call flutter run -d chrome
echo.
echo Share button fix completed!
echo.
