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

Write-Host "`n== [01] Kiem tra va Cap nhat Winget ==" -ForegroundColor Cyan

$wingetNeedsStoreUpdate = $false

# 1. Kiem tra Winget co ton tai khong
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "  [Warning] Winget chua duoc cai dat."
    $wingetNeedsStoreUpdate = $true
} else {
    # 2. Kiem tra xem Winget co bi loi Source (0x8a15000f) khong
    Write-Host "  [Check] Dang kiem tra ket noi cua Winget Source..." -ForegroundColor DarkGray
    $sourceUpdate = winget source update 2>&1
    
    if ($LASTEXITCODE -ne 0 -or $sourceUpdate -match "Failed|error|0x8a15000f") {
        Write-Warning "  [Warning] Winget co ton tai nhung Source bi loi (Can update App Installer)."
        $wingetNeedsStoreUpdate = $true
    } else {
        Write-Host "  [OK] Winget Source hoat dong binh thuong." -ForegroundColor Green
    }
}

# 3. Catch-and-Repair: Mo Microsoft Store neu can thiet
if ($wingetNeedsStoreUpdate) {
    Write-Host "  [Repair] Dang mo Microsoft Store de cap nhat App Installer..." -ForegroundColor Yellow
    
    # Mo thang trang "Downloads and updates" (Thu vien) cua Microsoft Store
    Start-Process "ms-windows-store://downloadsandupdates"
    
    Write-Host "`n  =======================================================" -ForegroundColor Cyan
    Write-Host "  VUI LONG THUC HIEN THU CONG:" -ForegroundColor White
    Write-Host "  1. Trong cua so Store vua mo, bam 'Get updates' (Lay ban cap nhat)."
    Write-Host "  2. Cho den khi 'App Installer' (Trinh cai dat ung dung) cap nhat xong."
    Write-Host "  3. Quay lai cua so nay va nhan Enter de tiep tuc."
    Write-Host "  =======================================================" -ForegroundColor Cyan
    
    Read-Host "`n  [Nhan Enter khi ban da update xong tren Store]"
    
    # Reset lai source sau khi Store da update xong dependency
    Write-Host "  [Repair] Dang lam moi database cua Winget..." -ForegroundColor Yellow
    winget source reset --force 2>$null | Out-Null
    winget source update 2>$null | Out-Null
}

# 4. Xac nhan ket qua cuoi cung
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetVer = (winget --version)
    Write-Host "  [OK] Winget san sang (Version: $wingetVer)" -ForegroundColor Green
} else {
    Write-Error "  [Fatal] Winget van chua hoat dong. Vui long kiem tra lai Windows."
    exit 1
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
    scoop install git | Out-Null
    
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