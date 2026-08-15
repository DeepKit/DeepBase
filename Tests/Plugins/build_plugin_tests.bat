@echo off
REM ============================================================================
REM Build and run the 77a ADR acceptance harness (plugin lifecycle tests).
REM Compiles the TestPlugin77 fixture DLL and PluginLifecycleHarness.exe,
REM then runs the harness. Exit code = number of failed checks (0 = green).
REM ============================================================================

call "D:\_Progs\02Business\scripts\env\delphi-13.1.bat" || exit /b 1
cd /D "%~dp0"

set OUTDIR=%~dp0Win64
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

set NS=-NS"System;System.Win;Winapi;Data;Data.Win;Vcl"

echo [build] Compiling fixture DLL TestPlugin77.dpr ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% "Fixture\TestPlugin77.dpr" 2>&1
if errorlevel 1 (
  echo [build] FIXTURE DLL COMPILE FAILED
  exit /b 1
)

echo [build] Compiling fixture DLL TestPluginABI10.dpr (task#11 ABI 1.0) ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% "Fixture\TestPluginABI10.dpr" 2>&1
if errorlevel 1 (
  echo [build] TESTPLUGINABI10 COMPILE FAILED
  exit /b 1
)

echo [build] Compiling fixture DLL TestPlugin11NoInvoke.dpr (task#11 1.1 no-invoke) ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% "Fixture\TestPlugin11NoInvoke.dpr" 2>&1
if errorlevel 1 (
  echo [build] TESTPLUGIN11NOINVOKE COMPILE FAILED
  exit /b 1
)

echo [build] Compiling fixture DLL TestPlugin11NoHealth.dpr (task#11 1.1 no-health) ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% "Fixture\TestPlugin11NoHealth.dpr" 2>&1
if errorlevel 1 (
  echo [build] TESTPLUGIN11NOHEALTH COMPILE FAILED
  exit /b 1
)

echo [build] Compiling PluginLifecycleHarness.dpr ...
dcc64 -LUrtl -LUvcl -U"..\..\Core" -E"%OUTDIR%" %NS% PluginLifecycleHarness.dpr 2>&1
if errorlevel 1 (
  echo [build] HARNESS COMPILE FAILED
  exit /b 1
)

echo.
echo [run] Executing PluginLifecycleHarness.exe ...
"%OUTDIR%\PluginLifecycleHarness.exe" 2>&1
set RC=%ERRORLEVEL%
echo.
echo [run] Exit code: %RC%
exit /b %RC%