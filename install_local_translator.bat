@echo off
setlocal
cd /d "%~dp0"

set "RUNTIME_DIR=%LOCALAPPDATA%\Prospectus Local Translator"
set "VENV_DIR=%RUNTIME_DIR%\venv"
set "TASK_NAME=Prospectus Local Translator"

where py >nul 2>nul
if %errorlevel%==0 (
  set PYTHON_CMD=py -3
) else (
  where python >nul 2>nul
  if %errorlevel%==0 (
    set PYTHON_CMD=python
  ) else (
    echo Python 3 was not found. Please install Python 3 first.
    pause
    exit /b 1
  )
)

if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"
copy /Y "local_translation_server.py" "%RUNTIME_DIR%\local_translation_server.py" >nul
copy /Y "check_site_status.py" "%RUNTIME_DIR%\check_site_status.py" >nul
copy /Y "requirements_local.txt" "%RUNTIME_DIR%\requirements_local.txt" >nul

%PYTHON_CMD% -m venv "%VENV_DIR%"
"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip
"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade certifi
"%VENV_DIR%\Scripts\python.exe" -m pip install -r "%RUNTIME_DIR%\requirements_local.txt"
"%VENV_DIR%\Scripts\python.exe" "%RUNTIME_DIR%\local_translation_server.py" --install-model --source en --target zh

schtasks /Create /TN "%TASK_NAME%" /TR "\"%VENV_DIR%\Scripts\pythonw.exe\" \"%RUNTIME_DIR%\local_translation_server.py\" --no-browser" /SC ONLOGON /F >nul
schtasks /Run /TN "%TASK_NAME%" >nul 2>nul
start "" "%VENV_DIR%\Scripts\pythonw.exe" "%RUNTIME_DIR%\local_translation_server.py" --no-browser

echo.
echo Installation is complete.
echo You can now open the website directly in your browser:
echo https://kunlins.github.io/verification-margin-note-tool/
pause
