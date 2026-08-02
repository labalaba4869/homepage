@echo off
setlocal
cd /d "%~dp0"
py -3 import_tables.py
if errorlevel 1 (
  echo.
  echo Conversion failed. Install dependencies with:
  echo py -3 -m pip install -r requirements.txt
  pause
  exit /b 1
)
echo.
echo Tables converted successfully.
pause
