@echo off
setlocal
call "d:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d D:\_Progs\02Business\DeepBase
del /q Tests\*.dcu 2>nul
del /q Tests\Win64\Debug\*.dcu 2>nul
msbuild Tests\DeepBaseTests.dproj /t:Rebuild /p:Config=Debug /p:Platform=Win64 /v:minimal
echo Exit code: %ERRORLEVEL%
endlocal
