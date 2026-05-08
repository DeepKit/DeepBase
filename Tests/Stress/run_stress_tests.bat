@echo off
REM DeepBase Stress Test Runner - Batch Script
REM
REM Usage:
REM   run_stress_tests.bat quick
REM   run_stress_tests.bat all
REM   run_stress_tests.bat memory48h
REM   run_stress_tests.bat eventbus
REM   run_stress_tests.bat concurrency
REM   run_stress_tests.bat connectionpool
REM   run_stress_tests.bat stability

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..\..\
set TEST_EXE=%SCRIPT_DIR%DeepBaseStressTests.exe
if not exist "%TEST_EXE%" set TEST_EXE=%PROJECT_ROOT%Tests\Win64\Debug\DeepBaseStressTests.exe
if not exist "%TEST_EXE%" set TEST_EXE=%PROJECT_ROOT%Tests\Stress\Win64\Debug\DeepBaseStressTests.exe
set RESULTS_DIR=%PROJECT_ROOT%StressTestResults
set TIMESTAMP=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

REM Default parameters
set TEST_TYPE=quick
set DURATION_SEC=60
set THREAD_COUNT=8

REM Parse command line arguments
if not "%1"=="" set TEST_TYPE=%1
if not "%2"=="" set DURATION_SEC=%2
if not "%3"=="" set THREAD_COUNT=%3

echo.
echo ========================================
echo   DeepBase Stress Test Runner
echo ========================================
echo.

REM Create results directory
if not exist "%RESULTS_DIR%" mkdir "%RESULTS_DIR%"

REM Check if test executable exists
if not exist "%TEST_EXE%" (
    echo [ERROR] Test executable not found: %TEST_EXE%
    echo [INFO] Please build the test project first:
    echo        cd Tests\Stress
    echo        dcc64 -B -U..\..\Core;..\..\Persistence;..\..\ThirdParty\Payment;..\..\ThirdParty\DB DeepBaseStressTests.dpr
    exit /b 1
)

set RESULT_FILE=%RESULTS_DIR%\stress_test_%TIMESTAMP%.json

echo [INFO] Test Type: %TEST_TYPE%
echo [INFO] Duration: %DURATION_SEC% seconds
echo [INFO] Threads: %THREAD_COUNT%
echo [INFO] Output: %RESULT_FILE%
echo.

REM Handle 48-hour test specially
if "%TEST_TYPE%"=="memory48h" (
    echo [WARN] This test will run for 48 hours!
    set DURATION_SEC=172800
    choice /C YN /M "Do you want to continue?"
    if errorlevel 2 (
        echo [INFO] Test cancelled.
        exit /b 0
    )
)

echo [INFO] Starting stress test...
echo.

"%TEST_EXE%" -suite=%TEST_TYPE% -duration=%DURATION_SEC% -threads=%THREAD_COUNT% -output="%RESULT_FILE%" -format=json

if %ERRORLEVEL%==0 (
    echo.
    echo [OK] All stress tests completed successfully!
    echo [INFO] Results saved to: %RESULT_FILE%
) else (
    echo.
    echo [ERROR] Some stress tests failed! Exit code: %ERRORLEVEL%
)

echo.
pause
