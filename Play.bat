@echo off
cd /d "%~dp0"
set "REDLINE_GODOT=C:\Godot\godot.exe"
if not exist "%REDLINE_GODOT%" (
  where godot >nul 2>nul
  if errorlevel 1 goto missing
  set "REDLINE_GODOT=godot"
)
echo Preparing Redline assets...
start "" /wait "%REDLINE_GODOT%" --headless --editor --path "%~dp0." --quit --log-file "%~dp0import-launch.log"
start "" "%REDLINE_GODOT%" --path "%~dp0."
exit /b
:missing
echo Open project.godot with Godot 4.6 to play.
pause
