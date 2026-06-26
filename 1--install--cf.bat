@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem Simple cloudflared service installer for Windows Server.
rem This script DOES NOT block RDP 3389.
rem
rem Optional: paste your token here.
rem If empty, the script will ask you to paste token or full command.
rem Example:
rem set "TUNNEL_TOKEN=eyJhIjoi..."
rem ============================================================
set "TUNNEL_TOKEN="

set "CLOUDFLARED_DIR=%ProgramFiles%\Cloudflare"
set "CLOUDFLARED_EXE=cloudflared"
set "DOWNLOAD_CLOUDFLARED_EXE=%CLOUDFLARED_DIR%\cloudflared.exe"

echo.
echo ============================================================
echo Simple cloudflared installer
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
echo [1/5] Preparing cloudflared.exe...

echo [INFO] Looking for existing cloudflared.exe in PATH...
where cloudflared >nul 2>&1
if "%errorlevel%"=="0" (
  echo [OK] cloudflared is available in PATH. The script will run: cloudflared
) else (
  echo [INFO] cloudflared was not found in PATH. Downloading to Program Files...
  if not exist "%CLOUDFLARED_DIR%" mkdir "%CLOUDFLARED_DIR%" >nul 2>&1
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$url = if ([Environment]::Is64BitOperatingSystem) { 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' } else { 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-386.exe' };" ^
    "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "Invoke-WebRequest -Uri $url -OutFile '%DOWNLOAD_CLOUDFLARED_EXE%';"

  if not exist "%DOWNLOAD_CLOUDFLARED_EXE%" (
    echo [ERROR] Download failed.
    echo.
    pause
    exit /b 1
  )
  set "CLOUDFLARED_EXE=%DOWNLOAD_CLOUDFLARED_EXE%"
  echo [OK] Downloaded: !CLOUDFLARED_EXE!
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
  "%CLOUDFLARED_EXE%" service uninstall
  timeout /t 5 /nobreak >nul
) else (
  echo [INFO] No old cloudflared service found.
)

echo.
echo [4/5] Installing cloudflared service...
"%CLOUDFLARED_EXE%" service install "%TUNNEL_TOKEN%"
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
echo.
echo If this works, only then consider blocking public 3389.
echo ============================================================
echo.
pause
