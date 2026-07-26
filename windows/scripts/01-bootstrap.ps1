<#
01-bootstrap.ps1
Muc dich: chuan bi package manager truoc khi cai bat ky app nao.
Chay: PowerShell thuong (khong bat buoc Admin).
#>

$ErrorActionPreference = "Stop"

Write-Host "== [01] Kiem tra winget ==" -ForegroundColor Cyan
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget khong co san. Cai 'App Installer' tu Microsoft Store, hoac tai .msixbundle tu github.com/microsoft/winget-cli/releases roi chay lai script nay."
    exit 1
}
winget --version

Write-Host "== [01] Cai Scoop (khong can Admin) ==" -ForegroundColor Cyan
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
} else {
    Write-Host "Scoop da cai san, bo qua."
}

Write-Host "== [01] Them Scoop bucket 'extras' va 'nerd-fonts' ==" -ForegroundColor Cyan
scoop bucket add extras 2>$null
scoop bucket add nerd-fonts 2>$null

Write-Host "== [01] Kiem tra Developer Mode (can cho buoc 04 - symlink khong dung Admin) ==" -ForegroundColor Cyan
$devMode = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
    Write-Warning "Developer Mode chua bat. Script 03-configure-windows.ps1 se tu bat no (can chay Admin + restart)."
} else {
    Write-Host "Developer Mode da bat. OK." -ForegroundColor Green
}

Write-Host "== [01] Xong. Tiep tuc: .\02-install-apps.ps1 ==" -ForegroundColor Green
