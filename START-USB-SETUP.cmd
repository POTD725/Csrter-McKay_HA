@echo off
setlocal
title Atlantis USB Setup From Scratch
cd /d "%~dp0"
if not exist "%~dp0docs\USB-SETUP-FROM-SCRATCH.md" (
  echo The USB setup guide was not found.
  echo Update or re-download the Carter-McKay_HA repository.
  echo.
  pause
  exit /b 1
)
start "" notepad.exe "%~dp0docs\USB-SETUP-FROM-SCRATCH.md"
exit /b 0
