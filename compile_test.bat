@echo off
call "%~dp0..\scripts\env\delphi-13.1.bat"
cd /d D:\_Progs\02Business\DeepBase
echo Starting build...
msbuild Tests\DeepBaseTests.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal > compile_output.txt 2>&1
echo Exit code: %ERRORLEVEL% >> compile_output.txt
