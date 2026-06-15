@echo off
set SCRIPT_DIR=%~dp0
pwsh -ExecutionPolicy Bypass -File "%SCRIPT_DIR%autofix-cli.ps1" %*
exit /b %ERRORLEVEL%
