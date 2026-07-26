<#
05-restore-data.ps1
Khoi phuc du lieu dung thu tu: danh tinh (SSH) truoc -> project code -> data ngoai Git -> Docker volume cuoi cung.
#>

$ErrorActionPreference = "Stop"

Write-Host "== [05] Kiem tra / tao SSH key ==" -ForegroundColor Cyan
$sshKey = "$env:USERPROFILE\.ssh\id_ed25519"
if (-not (Test-Path $sshKey)) {
    Write-Host "Chua co SSH key. Tao moi (ed25519):" -ForegroundColor Yellow
    $email = Read-Host "Nhap email dung cho SSH key"
    ssh-keygen -t ed25519 -C $email -f $sshKey
    Get-Service ssh-agent | Set-Service -StartupType Automatic
    Start-Service ssh-agent
    ssh-add $sshKey
    Write-Host "Add public key ben duoi vao GitHub/GitLab TRUOC KHI tiep tuc:" -ForegroundColor Yellow
    Get-Content "$sshKey.pub"
    Read-Host "Nhan Enter sau khi da add public key len GitHub"
} else {
    Write-Host "Da co SSH key san co." -ForegroundColor Green
}

Write-Host "== [05] Test ket noi SSH ==" -ForegroundColor Cyan
ssh -T git@github.com 2>&1 | Write-Host

Write-Host "== [05] Clone lai project code ==" -ForegroundColor Cyan
$projectsDir = "D:\Projects"
if (-not (Test-Path $projectsDir)) { New-Item -ItemType Directory -Path $projectsDir -Force | Out-Null }
Write-Host "Dieu chinh danh sach repo can clone trong chinh file script nay (bien `$repos` ben duoi)." -ForegroundColor Yellow
$repos = @(
    # "git@github.com:<you>/<repo>.git"
)
foreach ($repo in $repos) {
    $name = ($repo -split "/")[-1] -replace "\.git$", ""
    if (-not (Test-Path "$projectsDir\$name")) {
        git clone $repo "$projectsDir\$name"
    }
}

Write-Host "== [05] Restore data ngoai Git (dataset, secrets) ==" -ForegroundColor Yellow
Write-Host "Copy thu cong tu backup ngoai/cloud storage vao dung vi tri — chua co lenh tu dong o day vi du lieu khac nhau tuy nguoi dung."

Write-Host "== [05] Restore Docker volume (CHI chay SAU KHI Docker Desktop da chay on dinh) ==" -ForegroundColor Cyan
Write-Host 'Vi du: docker run --rm -v myvolume:/data -v D:\backup:/backup alpine tar xzf /backup/myvolume.tar.gz -C /data'

Write-Host "== [05] Xong. Chay Verification Checklist (SOP muc 12) ==" -ForegroundColor Green
