@echo off
echo ========================================================
echo   ProGold ERP - Windows Desktop Release Build
echo ========================================================
node scripts\build_desktop.js
if %ERRORLEVEL% NEQ 0 (
  echo Build Failed with code %ERRORLEVEL%
  pause
  exit /b %ERRORLEVEL%
)
echo Build completed successfully!
pause
