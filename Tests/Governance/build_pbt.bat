@echo off
REM Build and run the ConfigRegistrar property-based tests.

call "D:\_Progs\02Business\scripts\env\delphi-13.1.bat"
cd /D "%~dp0"

set OUTDIR=%~dp0Win64
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

set PATHS=-U"..\..\Core"
set PATHS=%PATHS% -U"..\..\Governance"

echo [build] Compiling ConfigRegistrarPBT.dpr ...
dcc64 %PATHS% -E"%OUTDIR%" -NS"System;System.Win;Winapi;Data;Data.Win;Vcl;FireDAC;FireDAC.Phys;FireDAC.Stan;FireDAC.Comp;FireDAC.VCLUI;FireDAC.UI" ConfigRegistrarPBT.dpr
if errorlevel 1 (
  echo [build] COMPILE FAILED
  exit /b 1
)

echo.
echo [run] Executing ConfigRegistrarPBT.exe ...
"%OUTDIR%\ConfigRegistrarPBT.exe"
set RC=%ERRORLEVEL%
echo.
echo [run] Exit code: %RC%
exit /b %RC%
