@echo off
setlocal
cd /D "%~dp0"
set OUTDIR=%~dp0Win64
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

set DCC="d:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe"
set PATHS=-U"..\..\Features" -U"..\..\Core" -U"..\..\Persistence"
set NS=-NS"System;System.Win;Winapi;Data;Data.Win;Vcl"

echo [build] Compiling SpeechSpike.dpr ...
%DCC% %PATHS% -E"%OUTDIR%" %NS% SpeechSpike.dpr
if errorlevel 1 ( echo [build] COMPILE FAILED & exit /b 1 )
echo.
echo [build] Running SpeechSpike.exe ...
"%OUTDIR%\SpeechSpike.exe"
echo Exit: %ERRORLEVEL%
exit /b %ERRORLEVEL%
