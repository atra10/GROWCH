@echo off
rem Double-click to start Transcribe. The first run sets everything up (needs internet, takes a few minutes).
cd /d "%~dp0"
if exist ".venv\Scripts\python.exe" goto run

echo First run: setting up Transcribe. This needs internet and takes a few minutes...
set "PY=python"
where py >nul 2>nul && set "PY=py -3"
%PY% -m venv .venv
if errorlevel 1 goto nopython
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 (
  echo.
  echo Installing failed. Check your internet connection and run this file again.
  rmdir /s /q .venv
  pause
  exit /b 1
)

:run
".venv\Scripts\python.exe" app.py
if errorlevel 1 pause
exit /b 0

:nopython
echo.
echo Python wasn't found. Install Python 3.12 from https://www.python.org/downloads/
echo and tick "Add python.exe to PATH" in the installer. Then run this file again.
pause
exit /b 1
