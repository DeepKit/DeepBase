@echo off
call "%~dp0..\..\..\scripts\env\delphi-13.1.bat"
echo Building TestSpeechHeadless...
%DCC64% -$O- -$W+ --no-config -Q -E.\bin -N.\dcu -U..\..\Features;..\..\Core;..\..\Persistence -I..\..\Features;..\..\Core -NSWinapi;System;System.Win;Data;FireDAC.Comp;FireDAC.Stan TestSpeechHeadless.dpr
if errorlevel 1 (
  echo BUILD FAILED
  pause
  exit /b 1
)
echo BUILD OK
echo.
echo Running tests...
bin\TestSpeechHeadless.exe --batch
echo.
echo Exit code: %ERRORLEVEL%
if %ERRORLEVEL% NEQ 0 (
  echo TESTS FAILED
  pause
) else (
  echo ALL TESTS PASSED
)
