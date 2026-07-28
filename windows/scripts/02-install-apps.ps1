<#
02-install-apps.ps1
Cai phan mem theo dung thu tu dependency.
- Catch-and-Repair: Tu dong bo qua app loi trong Winget.
- Context-Aware: Kiem tra trang thai WSL/VMP truoc khi cai Docker.
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$wingetList = Join-Path $repoRoot "windows\packages\winget.json"
$scoopList  = Join-Path $repoRoot "windows\packages\scoop-apps.txt"

# ---------------------------------------------------------
# 1. WINGET (GUI Apps)
# ---------------------------------------------------------
Write-Host "== [02] Cai app qua Winget ==" -ForegroundColor Cyan
if (Test-Path $wingetList) {
    Write-Host "  [Repair] Tim thay $wingetList. Dang import..." -ForegroundColor Yellow
    # Catch-and-Repair: Them cờ --ignore-unavailable. 
    # Neu 1 app trong file JSON bi xoa khoi repo Microsoft, script van chay tiep thay vi chet.
    winget import -i $wingetList --ignore-unavailable --accept-package-agreements --accept-source-agreements
} else {
    Write-Warning "  Chua co $wingetList -> Cai dat fallback."
    $apps = @("Brave.Brave", "Git.Git", "Microsoft.PowerShell", "Microsoft.WindowsTerminal", "7zip.7zip")
    foreach ($app in $apps) {
        Write-Host "  - Cai $app..." -ForegroundColor Yellow
        winget install --id $app -e --accept-package-agreements --accept-source-agreements | Out-Null
    }
}

# ---------------------------------------------------------
# 2. SCOOP (CLI Tools)
# ---------------------------------------------------------
Write-Host "`n== [02] Cai app qua Scoop ==" -ForegroundColor Cyan
if (Test-Path $scoopList) {
    # Catch-and-Repair: Dung .Trim() de xoa khoang trang/CRLF thua trong file txt
    $scoopApps = Get-Content $scoopList | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
    
    foreach ($app in $scoopApps) {
        if (Test-Path "$env:USERPROFILE\scoop\apps\$app") {
            Write-Host "  [Skip] $app da cai san." -ForegroundColor DarkGray
        } else {
            Write-Host "  [Install] Cai dat $app..." -ForegroundColor Yellow
            scoop install $app
        }
    }
} else {
    Write-Warning "  Chua co $scoopList -> Bo qua."
}

# ---------------------------------------------------------
# 3. WSL2 & DISTRO
# ---------------------------------------------------------
Write-Host "`n== [02] WSL2 + Distro ==" -ForegroundColor Cyan
$distroName = "Debian"
$distroDir = "D:\Linux\02_VHDX\$distroName"
$installedDistros = wsl -l -q 2>$null | Out-String

# Cờ (Flag) để giao tiếp với bước cài Docker bên dưới
$wslFailed = $false 

if ($installedDistros -match $distroName) {
    Write-Host "  [Skip] WSL Distro '$distroName' da ton tai." -ForegroundColor DarkGray
} else {
    Write-Host "  [Install] Dang cai dat WSL Distro '$distroName'..." -ForegroundColor Yellow
    
    # Chạy lệnh cài đặt (Không có cờ --location)
    wsl --install -d $distroName --no-launch
    
    # Bắt lỗi: wsl.exe là file ngoài, nó không trigger ErrorAction Stop mà trả về ExitCode
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [Error] Cài đặt WSL thất bại (Mã lỗi: $LASTEXITCODE)." -ForegroundColor Red
        $wslFailed = $true
    } else {
        Write-Host "  [OK] Cài đặt thành công vào ổ C:." -ForegroundColor Green
        
        # Tự động dời VHDX sang ổ D:
        Write-Host "  [Move] Dang di chuyen WSL sang $distroDir..." -ForegroundColor Yellow
        if (-not (Test-Path $distroDir)) { New-Item -ItemType Directory -Path $distroDir -Force | Out-Null }
        
        wsl --manage $distroName --move $distroDir
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [Warning] Di chuyển WSL thất bại, nhưng distro vẫn hoạt động trên ổ C:." -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] Đã di chuyển WSL sang ổ D: thành công." -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------
# 4. DOCKER DESKTOP (CONTEXT-AWARE)
# ---------------------------------------------------------
Write-Host "`n== [02] Docker Desktop ==" -ForegroundColor Cyan

# Fail-fast: Kiểm tra cờ lỗi từ bước 3
if ($wslFailed) {
    Write-Warning "  [Hoãn cài đặt] Bỏ qua cài đặt Docker Desktop do bước cài WSL trước đó bị lỗi."
    Write-Host "  -> Vui lòng kiểm tra lại lỗi WSL, sau đó chạy lại script này." -ForegroundColor Red
} 
elseif (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    
    # Kiem tra xem VirtualMachinePlatform da duoc bat va hoat dong chua
    $vmpState = (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -ErrorAction SilentlyContinue).State
    
    if ($vmpState -eq "Enabled") {
        Write-Host "  [Install] VMP da bat. Dang cai Docker Desktop..." -ForegroundColor Yellow
        winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
    } else {
        Write-Warning "  [Hoãn cài đặt] VirtualMachinePlatform chua duoc bat hoac dang cho Restart."
        Write-Warning "  Docker Desktop se bi loi neu cai bay gio."
        Write-Host "  -> Vui long chay tiep script 03, RESTART may, sau do chay lai script 02 nay de cai Docker." -ForegroundColor Red
    }
} else {
    Write-Host "  [Skip] Docker Desktop da duoc cai dat." -ForegroundColor DarkGray
}

Write-Host "`n== [02] XONG. ==" -ForegroundColor Green
Write-Host "Neu ban chua chay script 03, hay tiep tuc: .\03-configure-windows.ps1" -ForegroundColor Yellow