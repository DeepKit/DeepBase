@echo off
setlocal
call "d:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d D:\_Progs\02Business\UniBase
echo Cleaning DCU files...
del /q Tests\*.dcu 2>nul
del /q Tests\Win64\Debug\*.dcu 2>nul
echo.
echo Starting rebuild...
msbuild Tests\UniBaseTests.dproj /t:Rebuild /p:Config=Debug /p:Platform=Win64 /v:normal 2>&1
echo.
echo Exit code: %ERRORLEVEL%
endlocal
