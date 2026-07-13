@echo off
setlocal EnableExtensions

rem ============================================================
rem Windows Server 2022
rem Block RDP 3389 on all non-loopback local IP addresses.
rem Keep 127.0.0.1:3389 and ::1:3389 for Cloudflare Tunnel.
rem This script does not install or configure cloudflared.
rem ============================================================

title Block external RDP 3389

echo.
echo ============================================================
echo Block external RDP 3389
echo Keep Cloudflare localhost RDP access
echo ============================================================
echo.

rem Check Administrator privileges.
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [ERROR] Please run this BAT as Administrator.
    echo.
    pause
    exit /b 1
)

echo [OK] Administrator privileges confirmed.
echo.

rem ============================================================
rem Step 1: Read firewall status only. Do not change anything yet.
rem ============================================================

echo [1/4] Checking Windows Defender Firewall profiles...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Get-NetFirewallProfile -PolicyStore ActiveStore | ForEach-Object {" ^
  "  Write-Host ('[INFO] ' + $_.Name + ' firewall enabled: ' + $_.Enabled);" ^
  "};"

if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] Could not read Windows Firewall status.
    echo [SAFE STOP] No RDP block rule was added.
    echo.
    pause
    exit /b 1
)

rem ============================================================
rem Step 2: Check local RDP and cloudflared.
rem ============================================================

echo.
echo [2/4] Checking local RDP on 127.0.0.1:3389...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "if (Test-NetConnection 127.0.0.1 -Port 3389 -InformationLevel Quiet -WarningAction SilentlyContinue) { exit 0 } else { exit 1 }"

if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] 127.0.0.1:3389 is not reachable.
    echo [SAFE STOP] No RDP block rule was added.
    echo.
    echo Check Remote Desktop Services with:
    echo sc query TermService
    echo.
    pause
    exit /b 1
)

echo [OK] 127.0.0.1:3389 is reachable.
echo.
echo Checking cloudflared service...

sc query cloudflared | findstr /I "RUNNING" >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] The cloudflared service is not RUNNING.
    echo [SAFE STOP] No RDP block rule was added.
    echo.
    echo Check it with:
    echo sc query cloudflared
    echo.
    pause
    exit /b 1
)

echo [OK] cloudflared service is RUNNING.

rem ============================================================
rem Confirmation.
rem ============================================================

echo.
echo ============================================================
echo WARNING
echo ============================================================
echo.
echo This will block TCP and UDP 3389 on every non-loopback
echo IP address assigned to this server.
echo.
echo Blocked:
echo   Public-IP:3389
echo   Private-IP:3389
echo   LAN-IP:3389
echo   IPv6-IP:3389
echo.
echo Kept available locally:
echo   127.0.0.1:3389
echo   ::1:3389
echo.
echo Cloudflare should use:
echo   service: rdp://127.0.0.1:3389
echo.
echo Make sure Cloudflare Tunnel works before continuing.
echo Keep your cloud provider console available if possible.
echo No firewall setting has been changed at this point.
echo.
set /p "CONFIRM=Type 1 to continue, or press Enter to cancel: "

if not "%CONFIRM%"=="1" (
    echo.
    echo [CANCELLED] No RDP block rule was added.
    echo.
    pause
    exit /b 0
)

rem ============================================================
rem Step 3: Create block rules for all non-loopback addresses.
rem ============================================================

echo.
echo [3/4] Staging and activating external RDP block rules...
echo [INFO] No more keyboard input will be required after this point.
echo [INFO] Direct RDP may disconnect during the final activation step.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$prefix='Block External RDP 3389 -';" ^
  "$oldPrefix='Block Public RDP 3389 -';" ^
  "$originalProfiles = @(Get-NetFirewallProfile | Select-Object Name,Enabled);" ^
  "try {" ^
  "  Write-Host '[INFO] Removing older rules created by this script...';" ^
  "  Get-NetFirewallRule -DisplayName ($prefix + '*') -ErrorAction SilentlyContinue | Remove-NetFirewallRule;" ^
  "  Get-NetFirewallRule -DisplayName ($oldPrefix + '*') -ErrorAction SilentlyContinue | Remove-NetFirewallRule;" ^
  "  $addresses = @(Get-NetIPAddress -ErrorAction Stop | Where-Object {" ^
  "    $_.IPAddress -notlike '127.*' -and" ^
  "    $_.IPAddress -ne '::1' -and" ^
  "    $_.IPAddress -notlike 'fe80:*' -and" ^
  "    $_.IPAddress -ne '0.0.0.0' -and" ^
  "    $_.IPAddress -ne '::' -and" ^
  "    $_.AddressState -ne 'Duplicate'" ^
  "  } | Select-Object -ExpandProperty IPAddress -Unique);" ^
  "  if ($addresses.Count -eq 0) { throw 'No non-loopback IP addresses were found.'; }" ^
  "  Write-Host '[INFO] Rules will cover these local addresses:';" ^
  "  $addresses | ForEach-Object { Write-Host ('  ' + $_ + ':3389') };" ^
  "  Write-Host '[INFO] Creating rules in DISABLED state...';" ^
  "  New-NetFirewallRule -DisplayName ($prefix + 'TCP') -Description 'Block TCP RDP on non-loopback addresses; keep localhost for Cloudflare Tunnel.' -Direction Inbound -Protocol TCP -LocalPort 3389 -LocalAddress $addresses -Action Block -Profile Any -Enabled False | Out-Null;" ^
  "  New-NetFirewallRule -DisplayName ($prefix + 'UDP') -Description 'Block UDP RDP on non-loopback addresses; keep localhost for Cloudflare Tunnel.' -Direction Inbound -Protocol UDP -LocalPort 3389 -LocalAddress $addresses -Action Block -Profile Any -Enabled False | Out-Null;" ^
  "  $staged = @(Get-NetFirewallRule -DisplayName ($prefix + '*') -ErrorAction Stop);" ^
  "  if ($staged.Count -ne 2) { throw 'The staged firewall rules could not be verified.'; }" ^
  "  if (@($staged | Where-Object { $_.Enabled -ne 'False' }).Count -gt 0) { throw 'A staged rule became active too early.'; }" ^
  "  Write-Host '[OK] Rules staged and verified; they are not active yet.';" ^
  "  Write-Host '[FINAL] Activating Windows Firewall and RDP block rules now...' -ForegroundColor Yellow;" ^
  "  Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True;" ^
  "  $staged | Set-NetFirewallRule -Enabled True;" ^
  "  $disabled = @(Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { -not $_.Enabled });" ^
  "  if ($disabled.Count -gt 0) { throw 'One or more firewall profiles could not be enabled.'; }" ^
  "  if (-not (Test-NetConnection 127.0.0.1 -Port 3389 -InformationLevel Quiet -WarningAction SilentlyContinue)) { throw 'localhost RDP failed after activation.'; }" ^
  "  Write-Host '[OK] Final activation completed.' -ForegroundColor Green;" ^
  "} catch {" ^
  "  Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red;" ^
  "  Write-Host '[ROLLBACK] Removing new rules and restoring original firewall profile states...';" ^
  "  Get-NetFirewallRule -DisplayName ($prefix + '*') -ErrorAction SilentlyContinue | Remove-NetFirewallRule;" ^
  "  foreach ($profile in $originalProfiles) { Set-NetFirewallProfile -Profile $profile.Name -Enabled $profile.Enabled -ErrorAction SilentlyContinue; }" ^
  "  throw;" ^
  "}"

if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] Activation failed and rollback was attempted.
    echo.
    exit /b 1
)

rem ============================================================
rem Step 4: Verify the rules and localhost access.
rem ============================================================

echo.
echo [4/4] Verifying firewall rules...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$rules = @(Get-NetFirewallRule -DisplayName 'Block External RDP 3389 -*' -ErrorAction Stop);" ^
  "if ($rules.Count -lt 2) { throw 'Expected firewall rules were not found.'; }" ^
  "$rules | Select-Object DisplayName,Enabled,Profile,Direction,Action | Format-Table -AutoSize;" ^
  "Write-Host '';" ^
  "Write-Host 'Protected local addresses:';" ^
  "$rules | Get-NetFirewallAddressFilter | Select-Object -ExpandProperty LocalAddress -Unique;" ^
  "Write-Host '';" ^
  "Write-Host 'Protected ports and protocols:';" ^
  "$rules | Get-NetFirewallPortFilter | Select-Object Protocol,LocalPort | Format-Table -AutoSize;"

if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] Firewall rule verification failed.
    echo.
    exit /b 1
)

echo [OK] Rules are active and localhost RDP passed the activation check.

echo.
echo ============================================================
echo COMPLETED
echo ============================================================
echo.
echo Direct RDP access to TCP and UDP 3389 is blocked on all
echo non-loopback addresses currently assigned to this server.
echo.
echo Cloudflare Tunnel can continue using:
echo   rdp://127.0.0.1:3389
echo.
echo Test the public IP from a different external network.
echo Do not use an already established RDP session as the test.
echo.
echo Show the rules:
echo powershell.exe -Command "Get-NetFirewallRule -DisplayName 'Block External RDP 3389 -*'"
echo.
echo Remove the rules:
echo powershell.exe -Command "Get-NetFirewallRule -DisplayName 'Block External RDP 3389 -*' ^| Remove-NetFirewallRule"
echo.
echo ============================================================
echo.

endlocal
exit /b 0
