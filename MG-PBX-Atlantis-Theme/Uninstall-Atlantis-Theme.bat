@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo   MG PBX ATLANTIS COMMAND INTERFACE ROLLBACK
echo ============================================================
echo.
echo This restores the newest installer backup.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-MG-PBX-Atlantis-Theme.ps1"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo.
    echo Rollback did not complete. Error code: %EXITCODE%
    pause
)

exit /b %EXITCODE%
