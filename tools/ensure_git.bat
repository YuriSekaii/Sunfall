@echo off
:: Ensures git is on PATH (extracts bundled git.zip if needed) and the game folder is a git repo.
:: No setlocal on purpose: PATH must persist to the caller.
for %%r in ("%~dp0..") do set "SF_ROOT=%%~fr"

where git >nul 2>&1
if not errorlevel 1 goto :have_git
if exist "%SF_ROOT%\git_portable\cmd\git.exe" goto :set_path
if not exist "%SF_ROOT%\git.zip" goto :set_path
echo ===================================================
echo  First-Time Setup: Unpacking bundled Git...
echo  (This only happens once, please wait)
echo ===================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%SF_ROOT%\git.zip', '%SF_ROOT%\git_portable')"
:set_path
if not exist "%SF_ROOT%\git_portable\cmd\git.exe" goto :have_git
set "PATH=%SF_ROOT%\git_portable\cmd;%PATH%"

:have_git
if exist "%SF_ROOT%\.git\" goto :eof
where git >nul 2>&1
if errorlevel 1 goto :eof
echo ===================================================
echo  First-Time Setup: Linking game to GitHub for updates...
echo ===================================================
git -C "%SF_ROOT%" init -q -b main
git -C "%SF_ROOT%" remote add origin https://github.com/YuriSekaii/Sunfall.git
git -C "%SF_ROOT%" fetch origin main
if errorlevel 1 goto :init_failed
git -C "%SF_ROOT%" reset -q --hard origin/main
git -C "%SF_ROOT%" branch -q -u origin/main main
goto :eof

:init_failed
rmdir /s /q "%SF_ROOT%\.git"
echo WARNING: Could not reach GitHub. Updates are disabled until you are online (next launch retries).
goto :eof
