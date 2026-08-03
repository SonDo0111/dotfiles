<#
04-link-dotfiles.ps1
Tao symlink tu vi tri config that (Windows) tro vao file trong repo dotfiles.
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Set-DotfileLink
{
    param(
        [Parameter(Mandatory)] [string]$LinkPath,
        [Parameter(Mandatory)] [string]$TargetPath
    )

    if (-not (Test-Path $TargetPath))
    {
        Write-Warning "Target khong ton tai, bo qua: $TargetPath"
        return
    }

    $parent = Split-Path $LinkPath -Parent
    if (-not (Test-Path $parent))
    {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path $LinkPath)
    {
        $existing = Get-Item $LinkPath -Force
        if ($existing.LinkType -eq "SymbolicLink")
        {
            if ($existing.Target -eq $TargetPath)
            {
                Write-Host "OK (da dung san): $LinkPath -> $TargetPath" -ForegroundColor DarkGray
                return
            }
            Remove-Item $LinkPath -Force
        } else
        {
            # FIX BUG RENAME-ITEM O DAY: Chi lay ten file (Leaf)
            $newName = (Split-Path $LinkPath -Leaf) + ".bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Rename-Item -Path $LinkPath -NewName $newName -Force
            Write-Host "Da backup file cu thanh: $newName" -ForegroundColor Yellow
        }
    }

    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -Force | Out-Null
    Write-Host "Linked: $LinkPath -> $TargetPath" -ForegroundColor Green
}

Write-Host "== [04] Git / PowerShell / Cargo ==" -ForegroundColor Cyan
Set-DotfileLink -LinkPath "$HOME\.gitconfig"        -TargetPath "$repoRoot\git\.gitconfig-windows"
Set-DotfileLink -LinkPath $PROFILE                   -TargetPath "$repoRoot\powershell\Microsoft.PowerShell_profile.ps1"
Set-DotfileLink -LinkPath "$HOME\.wslconfig"        -TargetPath "$repoRoot\WSL\.wslconfig"
# Set-DotfileLink -LinkPath "$HOME\.cargo\config.toml" -TargetPath "$repoRoot\cargo\config.toml"

Write-Host "== [04] Windows Terminal ==" -ForegroundColor Cyan
$wtStorePath    = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtPortablePath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
if (Test-Path (Split-Path $wtStorePath -Parent))
{
    Set-DotfileLink -LinkPath $wtStorePath -TargetPath "$repoRoot\windows-terminal\settings.json"
} elseif (Test-Path (Split-Path $wtPortablePath -Parent))
{
    Set-DotfileLink -LinkPath $wtPortablePath -TargetPath "$repoRoot\windows-terminal\settings.json"
} else
{
    Write-Warning "Khong tim thay thu muc Windows Terminal."
}

# Tam thoi chua co VSCodium tren may
# Write-Host "== [04] VSCodium ==" -ForegroundColor Cyan
# $vscodiumUserDir = "$env:APPDATA\VSCodium\User"
# Set-DotfileLink -LinkPath "$vscodiumUserDir\settings.json"    -TargetPath "$repoRoot\vscodium\settings.json"
# Set-DotfileLink -LinkPath "$vscodiumUserDir\keybindings.json" -TargetPath "$repoRoot\vscodium\keybindings.json"


Write-Host "== [04] Zed ==" -ForegroundColor Cyan
$zedUserDir = "$env:APPDATA\Zed"
Set-DotfileLink -LinkPath "$zedUserDir\settings.json"    -TargetPath "$repoRoot\zed\settings.json"
Set-DotfileLink -LinkPath "$zedUserDir\keymap.json" -TargetPath "$repoRoot\zed\keymap.json"

Write-Host "`n== [04] Xong. Tiep tuc: .\06-vscodium-extensions.ps1 sau do .\05-restore-data.ps1 ==" -ForegroundColor Green
