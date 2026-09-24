@echo off
REM DeepBase build entry (WO-20260924-DEEPBASE-AUDIT-A-D9 seg3 / ext DB-007)
REM Position-independent: uses this script's folder as repo root; callable from any cwd.
REM Real build logic lives in Scripts\build_packages_win64.ps1. This bat only does
REM toolchain precheck + delegation + artifact-path echo. Kept ASCII-only so the
REM if-block below cannot be broken by a non-UTF8 console codepage (e.g. cp936).
setlocal
cd /d "%~dp0"

REM Resolve BDS (Delphi install root). Fall back to default 13.1 Florence path.
if not defined BDS set "BDS=D:\Program Files (x86)\Embarcadero\Studio\37.0"
if not exist "%BDS%\bin\dcc64.exe" (
  echo [build.bat] ERROR: compiler not found at "%BDS%\bin\dcc64.exe".
  echo             Set environment variable BDS to the Delphi install root, then retry.
  exit /b 2
)
echo [build.bat] BDS=%BDS%

REM Delegate to the existing ps1; extra args pass through as-is (default Runtime).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Scripts\build_packages_win64.ps1" %*
set "RC=%ERRORLEVEL%"

REM Echo the real artifact dirs (match build_packages_win64.ps1 output root).
echo.
echo [build.bat] exit=%RC%
echo [build.bat] artifact dirs:
echo   BPL  %~dp0TestResults\bpl64
echo   DCP  %~dp0TestResults\dcp64
echo   DCU  %~dp0TestResults\dcu64
exit /b %RC%
