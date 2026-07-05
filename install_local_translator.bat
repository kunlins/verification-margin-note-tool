@echo off
setlocal
cd /d "%~dp0"

set "RUNTIME_DIR=%LOCALAPPDATA%\Prospectus Local Translator"
set "VENV_DIR=%RUNTIME_DIR%\venv"
set "TASK_NAME=Prospectus Local Translator"
set "PYTHON_DOWNLOAD_URL=https://www.python.org/downloads/windows/"
set "PYTHON_WINGET_ID=Python.Python.3.11"

call :find_python
if defined PYTHON_CMD goto python_found

echo Python 3 was not found.
echo This local translator needs Python 3.10 or 3.11.
echo.
where winget >nul 2>nul
if errorlevel 1 goto manual_python_install

echo Windows Package Manager was found.
set /p INSTALL_PYTHON=Install Python 3.11 automatically now? [Y/N]: 
if /I not "%INSTALL_PYTHON%"=="Y" goto manual_python_install

winget install -e --id %PYTHON_WINGET_ID% --scope user --accept-package-agreements --accept-source-agreements
call :find_python
if defined PYTHON_CMD goto python_found

echo.
echo Automatic Python installation did not finish successfully.
goto manual_python_install

:manual_python_install
echo.
echo Please install Python 3.11 manually, then run this installer again.
echo Important: during installation, tick "Add python.exe to PATH".
echo Download page: %PYTHON_DOWNLOAD_URL%
start "" "%PYTHON_DOWNLOAD_URL%"
pause
exit /b 1

:find_python
set "PYTHON_CMD="
where py >nul 2>nul
if not errorlevel 1 (
  set "PYTHON_CMD=py -3"
  exit /b 0
)
where python >nul 2>nul
if not errorlevel 1 (
  set "PYTHON_CMD=python"
  exit /b 0
)
if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" (
  set "PYTHON_CMD="%LOCALAPPDATA%\Programs\Python\Python311\python.exe""
  exit /b 0
)
if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" (
  set "PYTHON_CMD="%LOCALAPPDATA%\Programs\Python\Python310\python.exe""
  exit /b 0
)
exit /b 0

:python_found
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
