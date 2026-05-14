@echo off
setlocal enabledelayedexpansion

title Generate ED25519 SSH Key (Custom Name)

echo =======================================
echo ED25519 SSH Key Generator
echo =======================================
echo.

set /p KEY_NAME=请输入Key名称（例如: myserver1）:

if "%KEY_NAME%"=="" (
    echo 名称不能为空
    pause
    exit /b
)

set KEY_DIR=%USERPROFILE%\.ssh
set KEY_PATH=%KEY_DIR%\%KEY_NAME%

if not exist "%KEY_DIR%" (
    mkdir "%KEY_DIR%"
)

echo.
echo 正在生成密钥: %KEY_PATH%
echo.

ssh-keygen -t ed25519 -C "%KEY_NAME%" -f "%KEY_PATH%" -N ""

echo.
echo =======================================
echo 生成完成
echo =======================================
echo.

echo 私钥路径:
echo %KEY_PATH%
echo.

echo 公钥路径:
echo %KEY_PATH%.pub
echo.

echo =======================================
echo 公钥内容如下（复制到服务器）:
echo =======================================
type "%KEY_PATH%.pub"

echo.
pause