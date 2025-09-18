@echo off
REM Scripts/Test-On-Different-System.bat
REM Simple batch file to test FlexApp Update Manager on different systems

echo ========================================
echo FlexApp Update Manager - System Test
echo ========================================
echo.

echo Checking PowerShell availability...
powershell -Command "Write-Host 'PowerShell Version:' $PSVersionTable.PSVersion" 2>nul
if %errorlevel% neq 0 (
    echo ERROR: PowerShell not available or not working
    pause
    exit /b 1
)

echo.
echo Running system test...
powershell -ExecutionPolicy Bypass -File "%~dp0Test-FlexAppUpdateManager-System.ps1"

echo.
echo Test completed. Check the output above for any issues.
echo.
echo To start the application, run:
echo   powershell -ExecutionPolicy Bypass -Command "Import-Module .\FlexAppUpdateManager.psm1 -Force; Show-FlexAppUpdateManager"
echo.
pause
