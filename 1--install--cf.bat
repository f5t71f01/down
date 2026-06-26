
cloudflared service uninstall 这些这个就是卸载呀
19:50
对，cloudflared service uninstall 就是卸载 cloudflared 的 Windows 服务。

它不是删除 cloudflared.exe 文件本身，而是把 Windows 服务里的 cloudflared 服务移除。

也就是说：

cloudflared service uninstall
做的是：

删除 Windows Service: cloudflared
但通常不会删除：

cloudflared.exe
所以重新安装时可以继续用同一个命令：

cloudflared service install <token>
你这个场景里正确流程就是：

cloudflared service uninstall
cloudflared service install <token>
如果服务正在运行，最好先停一下：

sc stop cloudflared
cloudflared service uninstall
cloudflared service install <token>
我现在脚本就是这个思路：卸载旧服务，不删除 exe；然后用新 token 安装服务。

19:50
你的这个脚本 如果我直接输入干净的 token 是否也是OK的
19:52
可以，直接输入干净的 token 是 OK 的。

这个脚本支持两种：

eyJhIjoi...
也支持完整命令：

cloudflared.exe service install eyJhIjoi...
不过我提醒你一句：现在这个极简脚本用的是“取你输入内容里的最后一段”作为 token。也就是说：

输入干净 token：没问题
输入 cloudflared.exe service install eyJhIjoi...：也没问题
如果输入内容后面还多了别的词，可能会取错
所以最稳的是直接输入干净 token。

19:52
现在已经OK了
接下来 把3389 不呢通过IP来访问 的问题解决掉，你要考虑到 cloudflare 能访问
19:54

已处理 40s
可以。现在用这个单独脚本：

block-public-rdp-only-english.bat

它只做一件事：阻止公网 IP 访问 3389，但保留 localhost:3389 给 Cloudflare Tunnel 用。

它会先检查：

127.0.0.1:3389 是否可访问
cloudflared 服务是否 Running
然后要求你手动输入：
BLOCK
才会添加防火墙规则。

它添加的是这种规则：

LocalPort = 3389
LocalAddress = 你的公网IP
Action = Block
所以不会挡：

127.0.0.1:3389
Cloudflare 面板里的后端保持：

rdp://localhost:3389
如果要撤销，用这个：

undo-rdp-firewall-block-english.bat

或者管理员 PowerShell：

Get-NetFirewallRule -DisplayName "Block Public RDP 3389 -*" | Remove-NetFirewallRule

已编辑 block-public-rdp-only-english.bat
+109
-0
19:55
我不希望输入太多 能否改成输入数字1 就会屏蔽
19:56

已处理 19s
已改好，现在输入数字：

1
就会屏蔽公网 3389。

最新版：

block-public-rdp-only-english.bat

提示现在是：

Type 1 to continue, or press Enter to cancel:
按回车或输入其他内容都会取消，不会添加规则。


已编辑 block-public-rdp-only-english.bat
+8
-8
19:56
海外有什么不收集用户信息的 拼音输入法吗
20:01

已处理 21s
如果你的核心诉求是 尽量不收集用户信息，我会优先推荐：

1. RIME / 中州韵，小狼毫

适合：Windows / macOS / Linux
Windows 版叫 Weasel / 小狼毫。

优点：

开源
本地输入法引擎
不依赖云联想
可离线使用
没有搜狗、百度那类账号、云同步、广告生态
官网 / 项目：

RIME 官方
librime GitHub
Weasel 小狼毫 Windows
这是我最推荐的。

2. Fcitx5 + Pinyin / RIME

适合：Linux / BSD
如果你在海外用 Linux，Fcitx5 是很常见的选择。Fcitx5 本身是开源输入法框架，GitHub 写明是 LGPL-2.1+：fcitx5 GitHub。

可选：

fcitx5-pinyin
fcitx5-rime
3. 系统自带输入法

Windows/macOS 自带拼音输入法通常比搜狗、百度、QQ 这类第三方商业输入法少很多额外东西，但它属于微软/苹果生态，不能说“不收集”，只能说相对省心。

我不建议你用：

搜狗输入法
百度输入法
QQ 输入法
讯飞输入法
不是说一定有问题，而是它们通常有云联想、账号同步、热词、广告/推荐、皮肤生态，隐私面更大。

结论：

如果你是 Windows Server / Windows 电脑，选：

RIME 小狼毫
如果你是 Linux，选：

Fcitx5 + RIME
如果你要“尽可能不上传、不联网、不收集”，用 RIME，并关闭/不安装任何云词库、同步、在线配置插件。

20:01
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



这个要不修改下

我发现官方提供下载的是 msi文件

显示更多
20:27

已处理 58s
可以，已经给你改成 MSI 安装版 了：

simple-install-cloudflared-msi-english.bat

逻辑现在是：

先检查全局命令：
where cloudflared
如果已经有，就直接用：
cloudflared service uninstall
cloudflared service install <token>
如果没有，自动下载官方 MSI：

64 位：cloudflared-windows-amd64.msi
32 位：cloudflared-windows-386.msi
静默安装 MSI：

msiexec /i cloudflared-latest.msi /qn /norestart
然后安装服务。
这个脚本仍然不会屏蔽 3389。
先用它确保 Cloudflare Tunnel 正常。


已编辑 simple-install-cloudflared-msi-english.bat
+152
-0
20:28




输出
暂无产物

来源
new-chat
outputs
simple-install-cloudflared-msi-english.bat
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

筛选文件
