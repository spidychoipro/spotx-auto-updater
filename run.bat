@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0spotx-autoupdate.ps1" %*
echo.
pause
