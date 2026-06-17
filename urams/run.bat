@echo off
echo Checking for PHP...
php --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PHP is not installed or not in PATH.
    echo.
    echo Please install PHP first:
    echo 1. Download from https://windows.php.net/download/
    echo 2. Extract to C:\php
    echo 3. Add C:\php to your system PATH
    echo 4. Restart this command prompt
    echo.
    echo Or use XAMPP instead (includes PHP + MySQL).
    pause
    exit /b 1
)
echo Starting URAMS PHP server...
start cmd /k "php -S localhost:8000 -t ."
timeout /t 2 /nobreak > nul
start http://localhost:8000/login.php
echo Server started. Press any key to stop...
pause > nul
taskkill /f /im php.exe > nul 2>&1
echo Server stopped.