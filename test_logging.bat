@echo off
chcp 65001
REM 日志系统测试脚本
REM 用于在生产环境下测试日志输出功能

echo ========================================
echo 日志系统测试脚本
echo ========================================
echo.

REM 检查可执行文件是否存在
if not exist "owo_flight_assistant.exe" (
    echo 错误: 找不到 owo_flight_assistant.exe
    echo 请确保在 build\windows\x64\runner\Release 目录下运行此脚本
    pause
    exit /b 1
)

echo 1. 启动应用并重定向 stderr 到 error.log
echo    这将捕获所有诊断信息
echo.

REM 启动应用并重定向 stderr
start "OwO Flight Assistant" cmd /c "owo_flight_assistant.exe 2> error.log"

echo 2. 应用已启动，请执行以下操作：
echo    a. 在应用中启用文件日志
echo    b. 执行一些操作以生成日志
echo    c. 关闭应用
echo.
echo 3. 关闭应用后，按任意键继续检查结果...
pause > nul

echo.
echo ========================================
echo 检查诊断信息 (error.log)
echo ========================================
if exist "error.log" (
    type error.log
    echo.
) else (
    echo 未找到 error.log 文件
)

echo.
echo ========================================
echo 检查日志文件
echo ========================================

REM 检查可能的日志位置
set FOUND=0

if exist "data\logs\app.log" (
    echo 找到日志文件: data\logs\app.log
    echo 文件大小:
    dir "data\logs\app.log" | find "app.log"
    set FOUND=1
)

if exist "logs\app.log" (
    echo 找到日志文件: logs\app.log
    echo 文件大小:
    dir "logs\app.log" | find "app.log"
    set FOUND=1
)

if %FOUND%==0 (
    echo 警告: 未找到日志文件
    echo 请检查 error.log 中的诊断信息
)

echo.
echo ========================================
echo 测试完成
echo ========================================
echo.
echo 如果日志文件为空或不存在，请查看 error.log 中的错误信息
echo.
pause
