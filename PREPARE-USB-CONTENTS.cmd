@echo off
setlocal
title Atlantis USB Content Preparation
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Prepare-USB-Contents.ps1"
echo.
pause
