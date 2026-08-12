@echo off
REM ============================================================================
REM Build and run the 77a ADR acceptance harness (plugin lifecycle tests).
REM Compiles the TestPlugin77 fixture DLL and PluginLifecycleHarness.exe,
REM then runs the harness. Exit code = number of failed checks (0 = green).
REM ============================================================================

call "D:\_Progs\02Business\scripts\env\delphi-13.1.bat"
cd /D "%~dp0"

set OUTDIR=%~dp0Win64
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

set NS=-NS"System;System.Win;Winapi;Data;Data.Win;Vcl"

echo [build] Compiling fixture DLL TestPlugin77.dpr ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% "Fixture\TestPlugin77.dpr"
if errorlevel 1 (
  echo [build] FIXTURE DLL COMPILE FAILED
  exit /b 1
)

echo [build] Compiling PluginLifecycleHarness.dpr ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% PluginLifecycleHarness.dpr
if errorlevel 1 (
  echo [build] HARNESS COMPILE FAILED
  exit /b 1
)

echo.
echo [run] Executing PluginLifecycleHarness.exe ...
"%OUTDIR%\PluginLifecycleHarness.exe"
set RC=%ERRORLEVEL%
echo.
echo [run] Exit code: %RC%
exit /b %RC%
