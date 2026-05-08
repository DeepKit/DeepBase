@echo off
call "d:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
cd /d "D:\_Progs\02Business\DeepBase"
echo Starting build...
msbuild "Tests\DeepBaseTests.dproj" /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
echo Build finished with errorlevel %ERRORLEVEL%
