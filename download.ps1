$files = @(
    "https://raw.githubusercontent.com/f5t71f01/down/refs/heads/main/1--install--cf.bat",
    "https://raw.githubusercontent.com/f5t71f01/down/refs/heads/main/2--block-public-rdp-only.bat",
    "https://raw.githubusercontent.com/f5t71f01/down/refs/heads/main/3--del-log.ps1",
    "https://raw.githubusercontent.com/f5t71f01/down/refs/heads/main/Disable-WindowsUpdate.ps1"
)

foreach ($url in $files) {
    $name = Split-Path $url -Leaf
    Write-Host "Downloading $name ..."
    Invoke-WebRequest -Uri $url -OutFile ".\$name"
}

Write-Host "Done."