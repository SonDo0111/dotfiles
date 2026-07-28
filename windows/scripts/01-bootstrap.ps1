<#
01-bootstrap.ps1
Muc dich: Chuan bi Package Managers (Winget, Scoop) va cac dependency loi (Git).
Chay: PowerShell thuong (khong bat buoc Admin).
#>

$ErrorActionPreference = "Stop"

Write-Host "== [01] Kiem tra va Sua chua Execution Policy ==" -ForegroundColor Cyan
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -notin @("RemoteSigned", "Unrestricted", "Bypass")) {
    Write-Host "  [Repair] Dang set ExecutionPolicy thanh RemoteSigned..." -ForegroundColor Yellow
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} else {
    Write-Host "  [Skip] ExecutionPolicy da hop le ($currentPolicy)." -ForegroundColor DarkGray
}

Write-Host "`n== [01] Kiem tra Winget ==" -ForegroundColor Cyan
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    # Catch & Repair: Thu goi App Installer URI de ep Windows Store mo trang cai dat
    Write-Warning "Winget khong ton tai. Dang mo Microsoft Store de ban cai dat 'App Installer'..."
    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    Write-Error "Vui long cai dat App Installer tu Store, sau do chay lai script nay."
    exit 1
} else {
    $wingetVer = (winget --version)
    Write-Host "  [OK] Winget dang chay (Version: $wingetVer)" -ForegroundColor Green
}

Write-Host "`n== [01] Kiem tra va Cai dat Scoop ==" -ForegroundColor Cyan
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "  [Repair] Dang cai dat Scoop..." -ForegroundColor Yellow
    Invoke-RestMethod -Uri get.scoop.sh | Invoke-Expression
} else {
    Write-Host "  [Skip] Scoop da duoc cai dat." -ForegroundColor DarkGray
}

Write-Host "`n== [01] Kiem tra Dependency (Git) cho Scoop Buckets ==" -ForegroundColor Cyan
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  [Repair] Scoop can Git de add bucket. Dang cai Git qua Winget..." -ForegroundColor Yellow
    winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements | Out-Null
    
    # Repair Path: Load lai bien moi truong PATH ngay trong phien hien tai de Scoop thay Git
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  [OK] Da cai Git va cap nhat PATH." -ForegroundColor Green
} else {
    Write-Host "  [Skip] Git da san sang." -ForegroundColor DarkGray
}

Write-Host "`n== [01] Kiem tra va Them Scoop Buckets ==" -ForegroundColor Cyan
# Catch & Repair: Thay vi 2>$null, ta doc danh sach bucket hien tai
$existingBuckets = scoop bucket list 2>$null | Out-String
$requiredBuckets = @("extras", "nerd-fonts")

foreach ($bucket in $requiredBuckets) {
    if ($existingBuckets -match $bucket) {
        Write-Host "  [Skip] Bucket '$bucket' da ton tai." -ForegroundColor DarkGray
    } else {
        Write-Host "  [Repair] Dang them bucket '$bucket'..." -ForegroundColor Yellow
        scoop bucket add $bucket
    }
}

Write-Host "`n== [01] Kiem tra Developer Mode ==" -ForegroundColor Cyan
$devMode = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devMode -ne 1) {
    Write-Host "  [Warning] Developer Mode chua bat. Script 03 se tu dong bat (Can Admin)." -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Developer Mode da bat." -ForegroundColor Green
}

Write-Host "`n== [01] XONG. Tiep tuc: .\02-install-apps.ps1 ==" -ForegroundColor Green