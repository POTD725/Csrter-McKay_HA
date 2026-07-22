@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo   MG PBX ATLANTIS COMMAND INTERFACE INSTALLER
echo ============================================================
echo.
echo This installer creates a backup before changing index.html.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-MG-PBX-Atlantis-Theme.ps1"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo.
    echo Installation did not complete. Error code: %EXITCODE%
    pause
)

exit /b %EXITCODE%
