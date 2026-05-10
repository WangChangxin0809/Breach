@echo off
setlocal

set "ROOT_DIR=%~dp0.."

if not "%GODOT_BIN%"=="" (
	set "GODOT=%GODOT_BIN%"
	goto run
)

where godot >nul 2>nul
if %ERRORLEVEL%==0 (
	set "GODOT=godot"
	goto run
)

where godot4 >nul 2>nul
if %ERRORLEVEL%==0 (
	set "GODOT=godot4"
	goto run
)

if exist "%ProgramFiles%\Godot\Godot.exe" (
	set "GODOT=%ProgramFiles%\Godot\Godot.exe"
	goto run
)

if exist "%LocalAppData%\Programs\Godot\Godot.exe" (
	set "GODOT=%LocalAppData%\Programs\Godot\Godot.exe"
	goto run
)

echo Godot executable not found. Set GODOT_BIN to your Godot executable path.
exit /b 1

:run
"%GODOT%" --path "%ROOT_DIR%\client" %*
