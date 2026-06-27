# Disable-WindowsUpdate.ps1
# 需要管理员权限运行

Write-Host "正在关闭 Windows 自动更新..." -ForegroundColor Yellow

# 停止 Windows Update 相关服务
$services = @(
    "wuauserv",      # Windows Update
    "bits",          # Background Intelligent Transfer Service
    "dosvc",         # Delivery Optimization
    "UsoSvc",        # Update Orchestrator Service
    "WaaSMedicSvc"   # Windows Update Medic Service，部分系统可能拒绝修改
)

foreach ($svc in $services) {
    try {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "已禁用服务: $svc"
    } catch {
        Write-Host "无法禁用服务: $svc，可能被系统保护" -ForegroundColor DarkYellow
    }
}

# 通过注册表策略关闭自动更新
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$auPath = "$wuPath\AU"

New-Item -Path $wuPath -Force | Out-Null
New-Item -Path $auPath -Force | Out-Null

Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -Type DWord
Set-ItemProperty -Path $auPath -Name "AUOptions" -Value 2 -Type DWord

# 禁用自动更新重启提示
Set-ItemProperty -Path $auPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord

Write-Host ""
Write-Host "Windows 自动更新已尽量关闭。" -ForegroundColor Green
Write-Host "建议重启电脑后生效。"