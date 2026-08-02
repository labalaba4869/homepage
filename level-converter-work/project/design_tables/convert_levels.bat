@echo off
setlocal
cd /d "%~dp0"
py -3 convert_levels.py
if errorlevel 1 (
  echo.
  echo Level conversion failed. Existing generated scenes were kept.
  echo Install dependencies with:
  echo py -3 -m pip install -r requirements.txt
  pause
  exit /b 1
)
echo.
echo Levels converted successfully.
pause
