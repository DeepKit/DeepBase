@echo off
call "D:\_Progs\02Business\scripts\env\delphi-13.1.bat"
cd /d D:\_Progs\02Business\DeepBase
echo Building AIErrorHandlerDemo...
msbuild Examples\AIErrorHandlerDemo\AIErrorHandlerDemo.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
set BUILD_EC=%ERRORLEVEL%
echo Exit code: %BUILD_EC%
exit /b %BUILD_EC%
