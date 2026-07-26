$moduleName = "Terminal-Icons"

# Kiểm tra xem module đã tồn tại trên máy chưa
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "[-] Chưa tìm thấy $moduleName. Bắt đầu quá trình cài đặt..." -ForegroundColor Cyan
    
    try {
        # Thực hiện cài đặt an toàn không cần quyền Admin
        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "[+] Cài đặt $moduleName thành công!" -ForegroundColor Green
    }
    catch {
        Write-Host "[x] Lỗi khi cài đặt $moduleName: $_" -ForegroundColor Red
    }
} else {
    # Nếu đã cài đặt, do nothing (chỉ in log nhỏ, bạn có thể comment dòng Write-Host này lại nếu muốn hoàn toàn im lặng)
    # Write-Host "[*] $moduleName đã được cài đặt. Bỏ qua bước cài đặt." -ForegroundColor Yellow
}

# Tự động nạp module vào phiên làm việc hiện tại
Import-Module $moduleName
Invoke-Expression (&starship init powershell)
