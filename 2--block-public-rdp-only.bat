@echo off
setlocal EnableExtensions

rem ============================================================
rem Block direct public IP access to TCP 3389.
rem This keeps localhost:3389 available for Cloudflare Tunnel.
rem It does NOT install or modify cloudflared.
rem ============================================================

echo.
echo ============================================================
echo Block public RDP 3389, keep Cloudflare localhost access
echo ============================================================
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo [ERROR] Please run this BAT as Administrator.
  echo.
  pause
  exit /b 1
)

echo [1/4] Checking local RDP on 127.0.0.1:3389...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if (Test-NetConnection 127.0.0.1 -Port 3389 -InformationLevel Quiet) { exit 0 } else { exit 1 }"
if not "%errorlevel%"=="0" (
  echo [ERROR] 127.0.0.1:3389 is not listening.
  echo [SAFE STOP] No firewall rule was added.
  echo.
  pause
  exit /b 1
)
echo [OK] localhost:3389 is reachable.

echo.
echo [2/4] Checking cloudflared service...
sc query cloudflared | findstr /I "RUNNING" >nul 2>&1
if not "%errorlevel%"=="0" (
  echo [ERROR] cloudflared service is not RUNNING.
  echo [SAFE STOP] No firewall rule was added.
  echo.
  pause
  exit /b 1
)
echo [OK] cloudflared service is RUNNING.

echo.
echo [IMPORTANT] This script will block direct public IP access to TCP 3389.
echo [IMPORTANT] Cloudflare Tunnel should still work if its backend is rdp://localhost:3389.
echo.
set /p "CONFIRM=Type 1 to continue, or press Enter to cancel: "
if not "%CONFIRM%"=="1" (
  echo [CANCELLED] No firewall rule was added.
  echo.
  pause
  exit /b 0
)

echo.
echo [3/4] Adding firewall block rules for public IP addresses only...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$prefix='Block Public RDP 3389 -';" ^
  "Get-NetFirewallRule -DisplayName ($prefix + '*') -ErrorAction SilentlyContinue | Remove-NetFirewallRule;" ^
  "$ipv4s = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object {" ^
  "  $_.IPAddress -notlike '127.*' -and" ^
  "  $_.IPAddress -notlike '10.*' -and" ^
  "  $_.IPAddress -notlike '192.168.*' -and" ^
  "  -not ($_.IPAddress -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.') -and" ^
  "  $_.IPAddress -notlike '169.254.*' -and" ^
  "  $_.IPAddress -ne '0.0.0.0'" ^
  "} | Select-Object -ExpandProperty IPAddress -Unique;" ^
  "$ipv6s = Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue | Where-Object {" ^
  "  $_.IPAddress -ne '::1' -and" ^
  "  $_.IPAddress -notlike 'fe80:*' -and" ^
  "  $_.IPAddress -notlike 'fc*' -and" ^
  "  $_.IPAddress -notlike 'fd*'" ^
  "} | Select-Object -ExpandProperty IPAddress -Unique;" ^
  "$all = @($ipv4s) + @($ipv6s);" ^
  "if (-not $all -or $all.Count -eq 0) { throw 'No public IP addresses found.' }" ^
  "foreach ($ip in $all) {" ^
  "  $rule = $prefix + $ip;" ^
  "  Write-Host ('[INFO] Blocking ' + $ip + ':3389');" ^
  "  New-NetFirewallRule -DisplayName $rule -Direction Inbound -Protocol TCP -LocalPort 3389 -LocalAddress $ip -Action Block -Profile Any | Out-Null;" ^
  "}" ^
  "Write-Host '[OK] Firewall rules created.';"

if not "%errorlevel%"=="0" (
  echo [ERROR] Failed to add firewall rules.
  echo.
  pause
  exit /b 1
)

echo.
echo [4/4] Showing created rules...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-NetFirewallRule -DisplayName 'Block Public RDP 3389 -*' -ErrorAction SilentlyContinue | Select-Object DisplayName, Enabled, Action"

echo.
echo ============================================================
echo Done.
echo Direct public IP access to TCP 3389 should now be blocked.
echo Cloudflare Tunnel can still use localhost:3389.
echo.
echo To undo:
echo Get-NetFirewallRule -DisplayName "Block Public RDP 3389 -*" ^| Remove-NetFirewallRule
echo ============================================================
echo.
pause
