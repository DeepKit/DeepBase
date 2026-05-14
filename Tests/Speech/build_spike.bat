@echo off
call "%~dp0..\..\..\scripts\env\delphi-13.1.bat"
%DCC64% -$O- -$W+ --no-config -Q -E.\bin -N.\dcu -U..\..\Features;..\..\Core;..\..\Persistence -I..\..\Features;..\..\Core -NSWinapi;System;System.Win SpeechSpike.dpr
if errorlevel 1 (
  echo BUILD FAILED
  pause
) else (
  echo BUILD OK
  echo Run: bin\SpeechSpike.exe
)
