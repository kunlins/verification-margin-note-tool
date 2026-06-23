@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo Local Python environment was not found.
  echo Please run install_local_translator.bat first.
  pause
  exit /b 1
)

set /p SITE_URL=Enter website address:
if "%SITE_URL%"=="" (
  echo No website address was provided.
  pause
  exit /b 1
)

echo %SITE_URL% | findstr /b /i "http:// https://" >nul
if errorlevel 1 set SITE_URL=https://%SITE_URL%

".venv\Scripts\python.exe" "check_site_status.py" "%SITE_URL%"
if errorlevel 1 (
  pause
  exit /b 1
)

echo Starting local translation service...
echo Opening website: %SITE_URL%
start "" "%SITE_URL%"
".venv\Scripts\python.exe" "local_translation_server.py" --no-browser
exit /b 0
