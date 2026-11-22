@echo off
title Sunfall - Launching Game...
cd /d "%~dp0"
call "%~dp0tools\ensure_git.bat"

set "GODOT_EXE="

:: 1. Check current directory for already extracted Godot executable
for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
    if exist "%%~i" if not defined GODOT_EXE set "GODOT_EXE=%%~i"
)

:: 2. If not found, auto-extract bundled engine.zip (one-time setup)
if not defined GODOT_EXE if exist "%~dp0engine.zip" (
    echo ========================================================
    echo  First-Time Setup: Unpacking bundled Godot Engine...
    echo ========================================================
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%~dp0engine.zip', '%~dp0')"
    for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
        if exist "%%~i" if not defined GODOT_EXE set "GODOT_EXE=%%~i"
    )
)

:: 3. Check system PATH
if not defined GODOT_EXE (
    for /f "tokens=*" %%i in ('where godot 2^>nul') do (
        if not defined GODOT_EXE set "GODOT_EXE=%%~i"
    )
)

:: 4. Check fallback default install location
if not defined GODOT_EXE (
    if exist "D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
    ) else if exist "D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" (
        set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
    )
)

if not defined GODOT_EXE (
    echo [ERROR] Could not find Godot executable.
    echo Please make sure engine.zip is present or verify Godot installation.
    pause
    exit /b 1
)

:: Set Godot import binary (prefer console executable for headless import)
set "GODOT_IMPORT_EXE=%GODOT_EXE%"
for %%i in ("%~dp0*godot*console*.exe") do (
    if exist "%%~i" set "GODOT_IMPORT_EXE=%%~i"
)

:: 5. Ensure assets are imported into .godot/ before launching
set "NEED_IMPORT=0"
if not exist "%~dp0.godot\imported\" set "NEED_IMPORT=1"

for /f %%c in ('git -C "%~dp0." rev-parse HEAD 2^>nul') do set "CUR_COMMIT=%%c"
if exist "%~dp0.godot\last_import_commit.txt" set /p LAST_COMMIT=<"%~dp0.godot\last_import_commit.txt"
if defined CUR_COMMIT if not "%CUR_COMMIT%"=="%LAST_COMMIT%" set "NEED_IMPORT=1"

if "%NEED_IMPORT%"=="1" (
    echo ========================================================
    echo  Importing game assets...
    echo ========================================================
    "%GODOT_IMPORT_EXE%" --headless --path "%~dp0." --import
    if defined CUR_COMMIT if exist "%~dp0.godot\" >"%~dp0.godot\last_import_commit.txt" echo %CUR_COMMIT%
)

echo Starting Sunfall using: "%GODOT_EXE%"...
"%GODOT_EXE%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Game exited with error code %ERRORLEVEL%.
    pause
)
