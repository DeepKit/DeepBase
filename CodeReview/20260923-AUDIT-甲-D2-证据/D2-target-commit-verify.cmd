@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
call "D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
set R=%~dpf1
cd /d %R%
set SP=%R%\Core;%R%\Tests;D:\ProgramData\delphi\DUnitX\Source;.
if not exist bld_d2\dcu mkdir bld_d2\dcu
if not exist bld_d2\bpl mkdir bld_d2\bpl
if not exist TestResults mkdir TestResults

echo ===== D2 TARGET-COMMIT VERIFICATION =====
git rev-parse HEAD
git status --porcelain
echo COMMITTED_FIXTURE_BYTES:
for %%F in (Tests\Regression\R7P4Probe.bpl) do echo %%~zF
certutil -hashfile Tests\Regression\R7P4Probe.bpl SHA256 | findstr /v "hash SHA"

echo.
echo === [A] RUN AGAINST THE COMMITTED .bPL (shipped artifact) ===
dcc64 -B -Q -U"%SP%" -I"%SP%" -N0bld_d2\dcu -Ebld_d2 Tests\TestBplR7P4.dpr
echo RUNNER_BUILD_EXIT_A=!ERRORLEVEL!
bld_d2\TestBplR7P4.exe
echo TEST_RUN_EXIT_A=!ERRORLEVEL!
if exist TestResults\R7-P4-bpl.xml copy /y TestResults\R7-P4-bpl.xml TestResults\D2-A-committedfixture-nunit.xml >nul

echo.
echo === [B] REBUILD FIXTURE FROM COMMITTED SOURCES ===
dcc64 -B -Q -N0bld_d2\dcu -LEbld_d2\bpl -U"bld_d2\dcu;Core" Tests\Regression\R7P4Probe.dpk
echo FIXTURE_BUILD_EXIT_B=!ERRORLEVEL!
for %%F in (bld_d2\bpl\R7P4Probe.bpl) do echo REBUILT_FIXTURE_BYTES=%%~zF
certutil -hashfile bld_d2\bpl\R7P4Probe.bpl SHA256 | findstr /v "hash SHA"
copy /y bld_d2\bpl\R7P4Probe.bpl Tests\Regression\R7P4Probe.bpl >nul
echo FIXTURE_INSTALL_EXIT_B=!ERRORLEVEL!

echo.
echo === [C] RUN AGAINST THE REBUILT .bPL (source-^>binary chain is live) ===
bld_d2\TestBplR7P4.exe
echo TEST_RUN_EXIT_C=!ERRORLEVEL!
if exist TestResults\R7-P4-bpl.xml copy /y TestResults\R7-P4-bpl.xml TestResults\D2-C-rebuiltfixture-nunit.xml >nul

echo.
echo === [D] RESTORE WORKTREE TO COMMITTED STATE ===
git checkout -- Tests/Regression/R7P4Probe.bpl
echo RESTORE_EXIT=!ERRORLEVEL!
git status --porcelain

echo.
echo === [E] GATES @ TARGET COMMIT ===
node "09_工程脚本\encoding-gate\check_pas_encoding.js" --root "%R%"
echo ENCODING_GATE_EXIT=!ERRORLEVEL!
node "09_工程脚本\eol-gate\check_eol.js" --root "%R%"
echo EOL_GATE_EXIT=!ERRORLEVEL!
node "09_工程脚本\evidence-encoding-gate\check_evidence_encoding.js" --root "%R%"
echo EVIDENCE_GATE_EXIT=!ERRORLEVEL!
endlocal
