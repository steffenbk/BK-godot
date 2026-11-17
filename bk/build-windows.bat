@echo off
rem Double-click or run from cmd/PowerShell: builds the editor using Git Bash.
rem Pass a variant to build something else, e.g.  bk\build-windows.bat editor-double
setlocal
set "VARIANT=%~1"
if "%VARIANT%"=="" set "VARIANT=editor"

set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%BASH%" (
  echo Git Bash not found at "%BASH%". Install Git for Windows: https://git-scm.com/download/win
  pause
  exit /b 1
)

rem Run from the repo root (this file lives in bk\).
cd /d "%~dp0.."
rem Keep Git Bash in this folder instead of jumping to the home directory.
set "CHERE_INVOKING=1"
"%BASH%" -lc "bk/build.sh %VARIANT%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo BUILD FAILED (exit code %RC%)
if "%RC%"=="0" echo Done. Editor is in bin\
pause
exit /b %RC%
