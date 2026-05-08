@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM  批量播种脚本 - 将模板数据库复制到各项目目录
REM  
REM  使用方法�?
REM  1. 先用 SeedTool.exe 播种一�?template.db
REM  2. 运行此脚本自动复制到所有项�?
REM ============================================================

set "TEMPLATE_DB=template.db"
set "BASE_DIR=D:\_Progs\02Business"

REM 检查模板数据库是否存在
if not exist "%TEMPLATE_DB%" (
    echo [错误] 模板数据�?%TEMPLATE_DB% 不存在！
    echo 请先�?SeedTool.exe 播种一�?template.db
    pause
    exit /b 1
)

echo ============================================================
echo  批量播种脚本
echo  模板: %TEMPLATE_DB%
echo  目标: %BASE_DIR%
echo ============================================================
echo.

REM 单机工具项目列表
set "PROJECTS=DeepMoveC TwoKeyRun DeepCharset DeepSVG EasyConfig DeepSync touch wyjx Chain2VFactory"

REM 对应的数据库文件�?
set "DB_DeepMoveC=DeepMoveCConfig.db"
set "DB_TwoKeyRun=TwoKeyRunConfig.db"
set "DB_DeepCharset=DeepCharsetConfig.db"
set "DB_DeepSVG=DeepSVGConfig.db"
set "DB_EasyConfig=EasyConfigConfig.db"
set "DB_DeepSync=DeepSyncConfig.db"
set "DB_touch=DeepCompareConfig.db"
set "DB_wyjx=wyjxConfig.db"
set "DB_Chain2VFactory=Chain2VConfig.db"

set SUCCESS_COUNT=0
set FAIL_COUNT=0

for %%P in (%PROJECTS%) do (
    set "TARGET_DIR=%BASE_DIR%\%%P"
    set "DB_NAME=!DB_%%P!"
    set "TARGET_FILE=!TARGET_DIR!\!DB_NAME!"
    
    if exist "!TARGET_DIR!" (
        echo [复制] %%P -^> !DB_NAME!
        copy /Y "%TEMPLATE_DB%" "!TARGET_FILE!" >nul 2>&1
        if !errorlevel! equ 0 (
            echo        �?成功
            set /a SUCCESS_COUNT+=1
        ) else (
            echo        × 失败
            set /a FAIL_COUNT+=1
        )
    ) else (
        echo [跳过] %%P - 目录不存�?
        set /a FAIL_COUNT+=1
    )
)

echo.
echo ============================================================
echo  完成！成�? %SUCCESS_COUNT%  失败: %FAIL_COUNT%
echo ============================================================
echo.
echo 注意：所有程序需要使用相同的加密配置�?
echo   EncryptionKey: DeepBase_Shared_Key_2025
echo   Salt: DeepBase_Shared_Salt_v1
echo   KdfIterations: 10000
echo   EnableHMAC: True
echo.
pause
