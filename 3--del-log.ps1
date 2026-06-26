# =============================================
# Official Microsoft SDelete + Full Cleanup
# 使用微软官方下载地址 + 多方法下载
# Run as Administrator
# =============================================

Write-Host "Starting cleanup process..." -ForegroundColor Cyan

$tempDir = "C:\Windows\Temp\SDelete"
$zipPath = "$tempDir\SDelete.zip"
$sdeleteExe = "$tempDir\sdelete64.exe"

# 清理旧目录
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$downloadUrl = "https://download.sysinternals.com/files/SDelete.zip"

Write-Host "Downloading SDelete from Microsoft official..." -ForegroundColor Yellow

$downloadSuccess = $false

# 方法1：WebClient
try {
    Write-Host "Trying WebClient..." -ForegroundColor Gray
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($downloadUrl, $zipPath)
    $downloadSuccess = $true
    Write-Host "WebClient succeeded." -ForegroundColor Green
} catch { Write-Host "WebClient failed." -ForegroundColor DarkYellow }

# 方法2：BITS Transfer
if (-not $downloadSuccess) {
    try {
        Write-Host "Trying BITS Transfer..." -ForegroundColor Gray
        Start-BitsTransfer -Source $downloadUrl -Destination $zipPath -ErrorAction Stop
        $downloadSuccess = $true
        Write-Host "BITS succeeded." -ForegroundColor Green
    } catch { Write-Host "BITS failed." -ForegroundColor DarkYellow }
}

# 方法3：certutil
if (-not $downloadSuccess) {
    try {
        Write-Host "Trying certutil..." -ForegroundColor Gray
        certutil -urlcache -split -f $downloadUrl $zipPath
        if (Test-Path $zipPath) { 
            $downloadSuccess = $true 
            Write-Host "certutil succeeded." -ForegroundColor Green 
        }
    } catch { Write-Host "certutil failed." -ForegroundColor DarkYellow }
}

if (-not $downloadSuccess) {
    Write-Host "All download methods failed." -ForegroundColor Red
    Write-Host "Please try manual download: https://download.sysinternals.com/files/SDelete.zip" -ForegroundColor Red
    pause
    exit
}

# 解压
Write-Host "Extracting SDelete..." -ForegroundColor Yellow
Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

# 查找执行文件
if (Test-Path "$tempDir\sdelete64.exe") {
    $sdeleteExe = "$tempDir\sdelete64.exe"
} elseif (Test-Path "$tempDir\sdelete.exe") {
    $sdeleteExe = "$tempDir\sdelete.exe"
} else {
    Write-Host "Cannot find sdelete executable!" -ForegroundColor Red
    pause
    exit
}

Write-Host "SDelete ready." -ForegroundColor Green

# ==================== 日志清理 ====================
Write-Host "Clearing all possible event logs..." -ForegroundColor Yellow

wevtutil el | ForEach-Object { try { wevtutil cl "$_" } catch {} }

$extraLogs = @(
    "Security","System","Application","Setup","ForwardedEvents",
    "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational",
    "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational",
    "Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational",
    "Microsoft-Windows-WinRM/Operational",
    "Microsoft-Windows-Security-Auditing"
)

foreach ($log in $extraLogs) { try { wevtutil cl $log } catch {} }

Write-Host "Log cleanup completed." -ForegroundColor Green

# 额外清理
Write-Host "Cleaning Temp, Prefetch, Recent..." -ForegroundColor Yellow
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue

# ==================== 执行 SDelete ====================
Write-Host "Starting SDelete 3-pass free space wipe on C:\ ..." -ForegroundColor Red
Write-Host "This may take a long time. Do NOT shutdown or close window!" -ForegroundColor Red

& $sdeleteExe -p 3 -c C:\ -accepteula

Write-Host "`nAll operations completed." -ForegroundColor Green
Write-Host "Strongly recommend restarting your computer now." -ForegroundColor Cyan

Start-Sleep -Seconds 10
exit