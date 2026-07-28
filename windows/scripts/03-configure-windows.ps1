<#
03-configure-windows.ps1
Cau hinh Windows: bat WSL feature, Long Path, Developer Mode, tat Advertising ID, va cac QoL Tweaks.
PHAI CHAY VOI QUYEN ADMINISTRATOR.
#>

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------
# 0. KIEM TRA QUYEN ADMIN
# ---------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Script nay can chay voi quyen Administrator. Mo lai PowerShell bang 'Run as Administrator' roi chay lai."
    exit 1
}

# ---------------------------------------------------------
# HÀM HELPER: ĐẢM BẢO TÍNH LŨY ĐẲNG CHO REGISTRY
# ---------------------------------------------------------
function Ensure-RegistryValue {
    param (
        [Parameter(Mandatory=$true)] [string]$Path,
        [Parameter(Mandatory=$true)] [string]$Name,
        [Parameter(Mandatory=$true)] $Value,
        [Parameter(Mandatory=$true)] [string]$PropertyType
    )

    # Tao Key (Thu muc) neu chua ton tai
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # Doc gia tri hien tai
    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    
    # So sanh va ap dung
    if ($currentValue -ne $Value) {
        Write-Host "  [Update] $Name -> $Value" -ForegroundColor Yellow
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
    } else {
        Write-Host "  [Skip] $Name da dung ($Value)" -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------
# 1. WINDOWS FEATURES (WSL & VMP)
# ---------------------------------------------------------
Write-Host "`n== [03] Bat WSL2 + Virtual Machine Platform ==" -ForegroundColor Cyan
$features = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
foreach ($f in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $f).State
    if ($state -ne "Enabled") {
        Write-Host "  Dang bat feature: $f..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart | Out-Null
    } else {
        Write-Host "  [Skip] Feature $f da duoc bat." -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------
# 2. SYSTEM & HARDWARE REGISTRY
# ---------------------------------------------------------
Write-Host "`n== [03] Cau hinh System & Hardware ==" -ForegroundColor Cyan

# Bat Verbose Status Message (Hien thi chi tiet luc boot/shutdown)
Ensure-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "verbosestatus" -Value 1 -PropertyType "DWORD"

# Dong bo UTC cho Hardware Clock (Tot cho Dual-boot Linux)
Ensure-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealtimeIsUniversal" -Value 1 -PropertyType "DWORD"

# Bat Long Path (Ho tro duong dan > 260 ky tu)
Ensure-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType "DWORD"

# Bat Developer Mode (Cho phep tao Symlink khong can Admin)
Ensure-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -PropertyType "DWORD"

# Tat Lock Screen (Vao thang man hinh nhap PIN)
Ensure-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -Value 1 -PropertyType "DWORD"


# ---------------------------------------------------------
# 3. PRIVACY & UI TWEAKS (QoL)
# ---------------------------------------------------------
Write-Host "`n== [03] Cau hinh Privacy & UI (QoL Tweaks) ==" -ForegroundColor Cyan

# Tat Advertising ID
Ensure-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -PropertyType "DWORD"

# Tat Bing Search trong Start Menu (Go tim kiem cuc nhanh, khong lag)
Ensure-RegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -PropertyType "DWORD"

# Tat man hinh quang cao "Let's finish setting up your device" sau khi update
Ensure-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -PropertyType "DWORD"

# Bat Compact Mode cho File Explorer (Mat do hien thi day dac nhu Win 10, tot cho Dev)
Ensure-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "UseCompactMode" -Value 1 -PropertyType "DWORD"

# Tu dong mo rong thu muc hien tai o Navigation Pane (Thanh ben trai Explorer)
Ensure-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "NavPaneExpandToCurrentFolder" -Value 1 -PropertyType "DWORD"


# ---------------------------------------------------------
# 4. HOÀN TẤT
# ---------------------------------------------------------
Write-Host "`n== [03] XONG. Can RESTART truoc khi chay 04-link-dotfiles.ps1 ==" -ForegroundColor Green
Write-Host "(WSL feature va Developer Mode chi co hieu luc day du sau restart)" -ForegroundColor Yellow
Write-Host "Sau restart: bat BitLocker THU CONG qua Settings va luu Recovery Key TRUOC (SOP muc 1 & 6, luu y PCR7/Secure Boot)." -ForegroundColor Yellow