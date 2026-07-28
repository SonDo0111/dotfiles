<#
03-configure-windows.ps1
Cau hinh Windows: bat WSL feature, Long Path, Developer Mode, tat Advertising ID.
PHAI CHAY VOI QUYEN ADMINISTRATOR.
#>

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Script nay can chay voi quyen Administrator. Mo lai PowerShell bang 'Run as Administrator' roi chay lai."
    exit 1
}

Write-Host "== [03] Bat WSL2 + Virtual Machine Platform ==" -ForegroundColor Cyan
$features = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
foreach ($f in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $f).State
    if ($state -ne "Enabled") {
        Write-Host "Dang bat feature: $f..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart | Out-Null
    } else {
        Write-Host "Feature $f da duoc bat. Bo qua." -ForegroundColor DarkGray
    }
}

# Bat verbose cho logout
#Write-Host "== Bat Verbose Status Message =="
#$systemPolicy = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
#if (-not (Test-Path $systemPolicy)) { New-Item -Path $systemPolicy -Force | Out-Null }
#New-ItemProperty -Path $systemPolicy `
#    -Name "verbosestatus" `-Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "== [03] Dong bo UTC ==" -ForegroundColor Cyan
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" `
    -Name "RealtimeIsUniversal" -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "== [03] Bat Long Path ==" -ForegroundColor Cyan
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "== [03] Bat Developer Mode (can cho buoc 04 - symlink khong dung Admin) ==" -ForegroundColor Cyan
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
    -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "== [03] Tat Advertising ID ==" -ForegroundColor Cyan
if (-not (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) {
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Force | Out-Null
}
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
    -Name "Enabled" -Value 0 -PropertyType DWORD -Force | Out-Null


Write-Host ""
Write-Host "== [03] XONG. Can RESTART truoc khi chay 04-link-dotfiles.ps1 ==" -ForegroundColor Green
Write-Host "(WSL feature va Developer Mode chi co hieu luc day du sau restart)" -ForegroundColor Yellow
Write-Host "Sau restart: bat BitLocker THU CONG qua Settings va luu Recovery Key TRUOC (SOP muc 1 & 6, luu y PCR7/Secure Boot)." -ForegroundColor Yellow
