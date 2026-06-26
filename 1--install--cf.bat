@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem Simple cloudflared service installer for Windows Server.
rem This script DOES NOT block RDP 3389.
rem
rem Logic:
rem 1. If cloudflared exists in PATH, use it directly.
rem 2. If not, download and install the official MSI.
rem 3. Uninstall old cloudflared service.
rem 4. Install cloudflared service with your Tunnel token.
rem ============================================================
set "TUNNEL_TOKEN="

set "MSI_FILE=%TEMP%\cloudflared-latest.msi"
set "MSI_URL="
set "CLOUDFLARED_CMD=cloudflared"

echo.
echo ============================================================
echo Simple cloudflared MSI installer
echo This script will NOT block RDP 3389.
echo ============================================================
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo [ERROR] Please run this BAT as Administrator.
  echo.
  pause
  exit /b 1
)

if "%TUNNEL_TOKEN%"=="" (
  echo [INFO] Paste the Tunnel token or the full install command.
  echo [INFO] Example: cloudflared.exe service install eyJhIjoi...
  set /p "RAW_INPUT=Input: "
  for %%A in (!RAW_INPUT!) do set "TUNNEL_TOKEN=%%~A"
)

if "%TUNNEL_TOKEN%"=="" (
  echo [ERROR] Empty token. Stopped.
  echo.
  pause
  exit /b 1
)

echo.
echo [1/5] Checking cloudflared command...
where cloudflared >nul 2>&1
if "%errorlevel%"=="0" (
  echo [OK] cloudflared is already available in PATH.
) else (
  echo [INFO] cloudflared was not found in PATH. Installing official MSI...
  if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "MSI_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi"
  ) else if /I "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
    set "MSI_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi"
  ) else (
    set "MSI_URL=https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-386.msi"
  )

  echo [INFO] Downloading: !MSI_URL!
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "Invoke-WebRequest -Uri '!MSI_URL!' -OutFile '%MSI_FILE%';"

  if not exist "%MSI_FILE%" (
    echo [ERROR] MSI download failed.
    echo.
    pause
    exit /b 1
  )

  echo [INFO] Installing MSI silently...
  msiexec /i "%MSI_FILE%" /qn /norestart
  if not "%errorlevel%"=="0" (
    echo [ERROR] MSI install failed. Error code: %errorlevel%
    echo.
    pause
    exit /b 1
  )

  del "%MSI_FILE%" >nul 2>&1

  echo [INFO] Re-checking cloudflared in PATH...
  where cloudflared >nul 2>&1
  if not "%errorlevel%"=="0" (
    echo [ERROR] MSI installed, but cloudflared is still not available in PATH.
    echo [INFO] Close and reopen CMD, or check the MSI installation path.
    echo.
    pause
    exit /b 1
  )
  echo [OK] cloudflared is now available in PATH.
)

echo.
echo [2/5] Checking local RDP 127.0.0.1:3389...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if (Test-NetConnection 127.0.0.1 -Port 3389 -InformationLevel Quiet) { exit 0 } else { exit 1 }"
if "%errorlevel%"=="0" (
  echo [OK] Local RDP is listening on 127.0.0.1:3389.
) else (
  echo [WARN] Local RDP is NOT listening on 127.0.0.1:3389.
  echo [WARN] cloudflared can still install, but RDP through Tunnel will not work until RDP is enabled.
)

echo.
echo [3/5] Removing old cloudflared service if it exists...
sc query cloudflared >nul 2>&1
if "%errorlevel%"=="0" (
  sc stop cloudflared >nul 2>&1
  timeout /t 3 /nobreak >nul
  cloudflared service uninstall
  timeout /t 5 /nobreak >nul
) else (
  echo [INFO] No old cloudflared service found.
)

echo.
echo [4/5] Installing cloudflared service...
cloudflared service install "%TUNNEL_TOKEN%"
if not "%errorlevel%"=="0" (
  echo [ERROR] cloudflared service install failed.
  echo.
  pause
  exit /b 1
)

echo.
echo [5/5] Starting and checking cloudflared service...
sc start cloudflared >nul 2>&1
timeout /t 5 /nobreak >nul
sc query cloudflared

echo.
echo ============================================================
echo Done.
echo.
echo IMPORTANT:
echo 1. This script did NOT block public RDP 3389.
echo 2. Go to Cloudflare Zero Trust and check Tunnel status is Healthy.
echo 3. Public hostname service should be: rdp://localhost:3389
echo 4. On your local PC, run:
echo    cloudflared access rdp --hostname YOUR_HOSTNAME --url rdp://localhost:13389
echo 5. Then open mstsc and connect to:
echo    localhost:13389
echo ============================================================
echo.
pause
