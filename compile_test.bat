@echo off
call "%~dp0..\scripts\env\delphi-13.1.bat"
cd /d D:\_Progs\02Business\DeepBase
echo Starting build...
msbuild Tests\DeepBaseTests.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal > compile_output.txt 2>&1
set BUILD_EC=%ERRORLEVEL%
echo Exit code: %BUILD_EC% >> compile_output.txt
echo Exit code: %BUILD_EC%
exit /b %BUILD_EC%
