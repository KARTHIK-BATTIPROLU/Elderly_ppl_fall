@echo off
echo ========================================
echo Adding Windows Firewall Rule
echo ========================================
echo.
echo This will allow your mobile phone to connect to the backend on port 8002
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running as Administrator... Good!
    echo.
) else (
    echo ERROR: This script must be run as Administrator!
    echo.
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Adding firewall rule...
netsh advfirewall firewall add rule name="FastAPI Backend - Fall Prevention" dir=in action=allow protocol=TCP localport=8002

if %errorLevel% == 0 (
    echo.
    echo ========================================
    echo SUCCESS! Firewall rule added.
    echo ========================================
    echo.
    echo Your mobile phone can now connect to:
    echo http://192.168.0.10:8002
    echo.
    echo Next steps:
    echo 1. Restart the app on your phone
    echo 2. Or pull down and tap "Refresh"
    echo.
) else (
    echo.
    echo ERROR: Failed to add firewall rule
    echo.
)

pause
