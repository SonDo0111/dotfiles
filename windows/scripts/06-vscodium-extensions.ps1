<#
06-vscodium-extensions.ps1
Quan ly extension VSCodium bang danh sach tuong minh, vi VSCodium khong ho tro Settings Sync
va marketplace mac dinh la Open VSX (khac Microsoft Marketplace cua VS Code goc).

Cach dung:
  .\06-vscodium-extensions.ps1            # cai extension theo danh sach co san trong repo
  .\06-vscodium-extensions.ps1 -Export    # xuat danh sach dang cai hien tai ra file, de commit len repo
#>

param(
    [switch]$Export
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$extListPath = Join-Path $repoRoot "vscodium\extensions.txt"

if (-not (Get-Command codium -ErrorAction SilentlyContinue)) {
    Write-Error "Khong tim thay lenh 'codium' trong PATH. Cai VSCodium truoc (buoc 02), hoac mo lai PowerShell moi de PATH cap nhat."
    exit 1
}

if ($Export) {
    Write-Host "== Xuat danh sach extension dang cai ra $extListPath ==" -ForegroundColor Cyan
    codium --list-extensions | Out-File -FilePath $extListPath -Encoding utf8
    Write-Host "Xong. Nho commit + push file nay len repo dotfiles de dung cho may sau." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $extListPath)) {
    Write-Warning "Chua co $extListPath. Cai extension thu cong truoc, roi chay '.\06-vscodium-extensions.ps1 -Export' de tao file nay."
    exit 0
}

Write-Host "== Cai extension tu $extListPath (nguon: Open VSX Registry) ==" -ForegroundColor Cyan
Get-Content $extListPath | ForEach-Object {
    $id = $_.Trim()
    if ($id -and -not $id.StartsWith("#")) {
        Write-Host "-- $id --" -ForegroundColor Yellow
        codium --install-extension $id
    }
}

Write-Host ""
Write-Host "== Luu y: extension doc quyen Microsoft KHONG co tren Open VSX ==" -ForegroundColor Red
Write-Host "Vi du bi anh huong: ms-vscode.cpptools (C/C++), C# Dev Kit, Live Share."
Write-Host "Khuyen nghi cho C/C++: dung 'llvm-vs-code-extensions.vscode-clangd' (clangd) thay the."
Write-Host "Neu bat buoc can extension doc quyen: tai file .vsix tu Marketplace/GitHub release, cai qua:"
Write-Host "  codium --install-extension `"C:\path\to\extension.vsix`""
