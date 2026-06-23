@echo off
setlocal
cd /d "%~dp0"

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

%PYTHON_CMD% -m venv ".venv"
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install --upgrade certifi
".venv\Scripts\python.exe" -m pip install -r "requirements_local.txt"
".venv\Scripts\python.exe" "local_translation_server.py" --install-model --source en --target zh

echo.
echo Installation is complete.
echo You can now double-click start_tool.bat to open the tool.
pause
