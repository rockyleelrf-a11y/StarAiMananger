@echo off
REM Build script for Windows EXE
REM Run on a Windows machine with Python installed
REM Deps: pip install pyinstaller pystray pillow psutil

echo =^> Installing Python deps...
pip install --quiet pyinstaller pystray pillow psutil

echo =^> Building Windows EXE with PyInstaller...
pyinstaller ^
  --onefile ^
  --noconsole ^
  --name "StarAiManager" ^
  --icon "..\Resources\AppIcon.ico" ^
  --add-data "..\logo.png;." ^
  main_windows.py

echo =^> EXE at: dist\StarAiManager.exe
echo Done!
pause
