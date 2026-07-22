@echo off
setlocal
title CARTER Atlantis Display Patch
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Apply-Current-Carter-Patch.ps1"
echo.
pause
