<#
02-install-apps.ps1
Cai phan mem theo dung thu tu dependency (SOP muc 8).
Uu tien winget import neu da co file packages/winget.json tu lan cai truoc.
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # windows\scripts -> windows -> repo root
$wingetList = Join-Path $repoRoot "windows\packages\winget.json"
$scoopList  = Join-Path $repoRoot "windows\packages\scoop-apps.txt"

# ---------------------------------------------------------
# 1. WINGET (GUI Apps)
# ---------------------------------------------------------
Write-Host "== [02] Cai app qua Winget ==" -ForegroundColor Cyan
if (Test-Path $wingetList) {
    Write-Host "Da tim thay $wingetList -> import toan bo." -ForegroundColor Green
    winget import -i $wingetList --accept-package-agreements --accept-source-agreements
} else {
    Write-Warning "Chua co $wingetList (lan cai dau tien) -> cai theo danh sach thu cong ben duoi."
    $apps = @(
        "Brave.Brave",
        "Git.Git",
        "Microsoft.PowerShell",
        "Microsoft.WindowsTerminal",
        "7zip.7zip"
    )
    foreach ($app in $apps) {
        Write-Host "-- Cai $app --" -ForegroundColor Yellow
        winget install --id $app -e --accept-package-agreements --accept-source-agreements
    }
}

# ---------------------------------------------------------
# 2. SCOOP (CLI Tools)
# ---------------------------------------------------------
Write-Host "== [02] Cai app qua Scoop ==" -ForegroundColor Cyan
if (Test-Path $scoopList) {
    Write-Host "Da tim thay $scoopList -> tien hanh cai dat." -ForegroundColor Green
    $scoopApps = Get-Content $scoopList | Where-Object { $_ -match '\S' }
    
    foreach ($app in $scoopApps) {
        # Kiem tra luy dang (nhanh): Check thu muc app thay vi goi 'scoop list'
        if (Test-Path "$env:USERPROFILE\scoop\apps\$app") {
            Write-Host "  - $app da cai san, bo qua." -ForegroundColor DarkGray
        } else {
            Write-Host "  - Cai dat $app..." -ForegroundColor Yellow
            scoop install $app
        }
    }
} else {
    Write-Warning "Chua co $scoopList -> bo qua buoc Scoop."
}

# ---------------------------------------------------------
# 3. WSL2 & DISTRO
# ---------------------------------------------------------
Write-Host "== [02] WSL2 + distro (yeu cau: da bat Virtualization VT-x/AMD-V trong BIOS) ==" -ForegroundColor Cyan
$distroName = "Debian"
$installedDistros = wsl -l -q 2>$null | Out-String

if ($installedDistros -match $distroName) {
    Write-Host "WSL Distro '$distroName' da ton tai. Bo qua." -ForegroundColor DarkGray
} else {
    Write-Host "Dang cai dat WSL Distro '$distroName'..." -ForegroundColor Yellow
    # BAT BUOC co --no-launch de script khong bi treo
    wsl --install -d $distroName --no-launch
    Write-Host "Cai dat xong. Ban can mo Debian thu cong sau de tao User/Pass." -ForegroundColor Green
}

# ---------------------------------------------------------
# 4. DOCKER DESKTOP
# ---------------------------------------------------------
Write-Host "== [02] Docker Desktop (BAT BUOC chay SAU khi WSL2 da co) ==" -ForegroundColor Cyan
# Kiem tra luy dang cho Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "Docker Desktop da duoc cai dat. Bo qua." -ForegroundColor DarkGray
}

Write-Host "== [02] Xong. Sau khi cai them app moi, nho export lai danh sach cho lan sau: ==" -ForegroundColor Green
Write-Host "  winget export -o `"$wingetList`""
Write-Host "  scoop export > `"$scoopList`""
Write-Host "== Tiep tuc: .\03-configure-windows.ps1 ==" -ForegroundColor Green
