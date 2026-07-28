# Kiểm tra xem module đã tồn tại trên máy chưa
if (!(Get-Module -ListAvailable -Name 'Terminal-Icons')) {
    Write-Host "[-] Terminal-Icons Not Found. Installing..." -ForegroundColor Cyan
    
    try {
        # Thực hiện cài đặt an toàn không cần quyền Admin
        Install-Module -Name 'Terminal-Icons' -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "[+] Succesfullly Installed 'Terminal-Icons'!" -ForegroundColor Green
    }
    catch {
        Write-Host "[x] Error installing: $_" -ForegroundColor Red
    }
} else {
    # Nếu đã cài đặt, do nothing (chỉ in log nhỏ, bạn có thể comment dòng Write-Host này lại nếu muốn hoàn toàn im lặng)
    # Write-Host "[*] $moduleName đã được cài đặt. Bỏ qua bước cài đặt." -ForegroundColor Yellow
}

# Tự động nạp module vào phiên làm việc hiện tại
Import-Module 'Terminal-Icons'
Invoke-Expression (&starship init powershell)
