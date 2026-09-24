@echo off
REM DeepBase test entry (WO-20260924-DEEPBASE-AUDIT-A-D9 seg3 / ext DB-007)
REM Position-independent: uses this script's folder as repo root; callable from any cwd.
REM Real test logic + case filtering lives in Scripts\run_tests.ps1. This bat only does
REM toolchain precheck + delegation + result-dir echo. Kept ASCII-only so the if-block
REM below cannot be broken by a non-UTF8 console codepage (e.g. cp936).
REM Cases are excluded by Category group (run_tests.ps1 excludes DBEnv category by default;
REM   set DEEPBASE_RUN_DB_INTEGRATION=1 to include). No hand-maintained fixture whitelist.
setlocal
cd /d "%~dp0"

if not defined BDS set "BDS=D:\Program Files (x86)\Embarcadero\Studio\37.0"
if not exist "%BDS%\bin\dcc64.exe" (
  echo [run_tests.bat] ERROR: compiler not found at "%BDS%\bin\dcc64.exe". Set BDS to the Delphi install root, then retry.
  exit /b 2
)
echo [run_tests.bat] BDS=%BDS%

REM Default: run unit tests (compile + run). Extra args pass through to run_tests.ps1
REM (e.g. -Type All, -Module ...).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Scripts\run_tests.ps1" -Type Unit %*
set "RC=%ERRORLEVEL%"

echo.
echo [run_tests.bat] exit=%RC%  result dir: %~dp0TestResults
exit /b %RC%
