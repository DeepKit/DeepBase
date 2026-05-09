@echo off
setlocal
call "%~dp0..\scripts\env\delphi-13.1.bat"
cd /d D:\_Progs\02Business\DeepBase
echo Cleaning DCU files...
del /q Tests\*.dcu 2>nul
del /q Tests\Win64\Debug\*.dcu 2>nul
echo.
echo Starting rebuild...
msbuild Tests\DeepBaseTests.dproj /t:Rebuild /p:Config=Debug /p:Platform=Win64 /v:normal 2>&1
echo.
echo Exit code: %ERRORLEVEL%
endlocal
