@echo off
chcp 65001 >nul
setlocal
call "D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
set R=%~dpf1
cd /d %R%
set SP=%R%\Core;%R%\Tests;D:\ProgramData\delphi\DUnitX\Source;.
if not exist bld_d2\dcu mkdir bld_d2\dcu
if not exist bld_d2\bpl mkdir bld_d2\bpl

echo === [1/3] BUILD fixture package R7P4Probe.dpk (real dcc64 BPL chain) ===
dcc64 -B -Q -N0bld_d2\dcu -LEbld_d2\bpl -U"bld_d2\dcu;Core" Tests\Regression\R7P4Probe.dpk
echo FIXTURE_BUILD_EXIT=%ERRORLEVEL%
echo --- committed fixture BEFORE ---
dir Tests\Regression\R7P4Probe.bpl
copy /y bld_d2\bpl\R7P4Probe.bpl Tests\Regression\R7P4Probe.bpl >nul
echo COPY_EXIT=%ERRORLEVEL%
echo --- freshly built fixture (repo root = %R%) ---
dir bld_d2\bpl\R7P4Probe.bpl
echo --- committed fixture AFTER refresh ---
dir Tests\Regression\R7P4Probe.bpl

echo.
echo === [2/3] BUILD narrow runner TestBplR7P4.dpr ===
dcc64 -B -Q -U"%SP%" -I"%SP%" -N0bld_d2\dcu -Ebld_d2 Tests\TestBplR7P4.dpr
echo RUNNER_BUILD_EXIT=%ERRORLEVEL%

echo.
echo === [3/3] RUN (CWD = repo root, fixture resolved under Tests\Regression) ===
bld_d2\TestBplR7P4.exe
echo TEST_RUN_EXIT=%ERRORLEVEL%
endlocal
