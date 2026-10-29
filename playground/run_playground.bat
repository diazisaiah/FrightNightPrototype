@echo off
rem Syncs the game into the Playground project and runs it.
rem   run_playground.bat        play it
rem   run_playground.bat -e     open it in the Godot editor
rem Set GODOT to your Godot folder's console exe if it lives somewhere else.
rem Set PLAYGROUND_PYTHON to python.exe if "python" is not on PATH.
setlocal
if "%GODOT%"=="" set "GODOT=%USERPROFILE%\Desktop\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
if "%PLAYGROUND_PYTHON%"=="" set "PLAYGROUND_PYTHON=python"
"%PLAYGROUND_PYTHON%" "%~dp0sync.py" || goto :error
"%GODOT%" --headless --path "%~dp0project" --import >nul 2>&1
"%GODOT%" --path "%~dp0project" %*
goto :eof
:error
echo Sync failed.
pause
