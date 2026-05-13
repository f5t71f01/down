@echo off
title Custom RDP Port Changer
color 0A

:: =========================
:: 只需要修改这里
:: =========================

set RDP_PORT=7796

:: =========================
:: 开始
:: =========================

echo.
echo =====================================
echo        Custom RDP Port Changer
echo =====================================
echo.

echo Target Port: %RDP_PORT%
echo.

:: =========================
:: 修改注册表
:: =========================

echo [1/5] Modifying RDP port...

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" ^
/v PortNumber ^
/t REG_DWORD ^
/d %RDP_PORT% ^
/f

if %errorlevel% neq 0 (
    echo.
    echo Failed to modify registry.
    pause
    exit
)

:: =========================
:: 删除旧3389规则
:: =========================

echo.
echo [2/5] Removing old firewall rules...

netsh advfirewall firewall delete rule name=all protocol=TCP localport=3389 >nul 2>nul

:: =========================
:: 删除旧自定义规则
:: =========================

netsh advfirewall firewall delete rule name="RDP_CUSTOM_PORT" >nul 2>nul

:: =========================
:: 添加新规则
:: =========================

echo.
echo [3/5] Adding firewall rule...

netsh advfirewall firewall add rule ^
name="RDP_CUSTOM_PORT" ^
dir=in ^
action=allow ^
protocol=TCP ^
localport=%RDP_PORT%

:: =========================
:: 重启远程桌面服务
:: =========================

echo.
echo [4/5] Restarting Remote Desktop Service...

net stop termservice /y
timeout /t 2 >nul
net start termservice

:: =========================
:: 显示结果
:: =========================

echo.
echo [5/5] Completed.
echo.

echo =====================================
echo              SUCCESS
echo =====================================
echo.

echo New RDP Port:
echo %RDP_PORT%
echo.

echo Connect Example:
echo YOUR_IP:%RDP_PORT%
echo.

echo Example:
echo 1.2.3.4:%RDP_PORT%
echo.

pause