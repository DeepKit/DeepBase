@echo off
chcp 65001 >nul
echo ========================================
echo    UniBase 可视化验收测试工具
echo ========================================
echo.

REM 检查是否存在编译后的可执行文件
if exist "UniBaseAcceptanceTest.exe" (
    echo 启动验收测试工具...
    echo.
    start "" "UniBaseAcceptanceTest.exe"
) else (
    echo 可执行文件不存在，请先编译项目
    echo.
    echo 编译方法:
    echo   1. 使用 Delphi IDE 打开 UniBaseAcceptanceTest.dpr
    echo   2. 按 F9 编译运行
    echo.
    echo 或使用命令行:
    echo   dcc32 -B -Q UniBaseAcceptanceTest.dpr
    echo.
    pause
    exit /b 1
)

echo.
echo 使用说明:
echo 1. 选择左侧的测试阶段
echo 2. 点击"运行当前阶段"执行自动测试
echo 3. 对于手动测试项，请人工验证后标记结果
echo 4. 完成后点击"生成报告"导出验收报告
echo.
