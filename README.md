# SOP: Reproducible Dev Workstation Provisioning (Windows + Linux/WSL)

> v2 — Cập nhật kiến trúc 2-repo (tách OS-specific khỏi toolchain dùng chung nhiều máy/OS), bổ sung **các bước thực hiện chi tiết** và **lỗi thường gặp** cho từng phần.

**Nguyên tắc xuyên suốt:** Windows install = "provisioning", không phải "cài thủ công". Config nào có thể mô tả bằng text đều đưa vào Git. Config nào chỉ đúng cho 1 máy Windows cụ thể tách riêng khỏi config dùng chung trên mọi OS.

---

## 0. Kiến trúc tổng thể (v3 — symlink thuần, không dùng công cụ ngoài)

> **Sửa so với bản trước**: bản v2 dùng chezmoi — không phù hợp với chủ đích của bạn (không muốn thêm công cụ ngoài). v3 dùng lại đúng những gì Windows/Git/Cargo... đã hỗ trợ sẵn: **symlink** để đồng bộ file, và **cơ chế điều kiện native của từng tool** (Git `includeIf`, Cargo `cfg(windows)/cfg(unix)`) cho phần nội dung cần khác nhau giữa Windows và Linux/WSL.

### Mục tiêu
Một repo Git duy nhất, chứa file cấu hình thật; symlink từ vị trí gốc (`$PROFILE`, `~/.gitconfig`...) trỏ vào file trong repo. Sửa ở đâu cũng có hiệu lực ngay, không cần lệnh "apply" trung gian.

### Tại sao không cần 2 repo / không cần chezmoi
- Phần "khác nhau theo OS" thực ra rất ít (path, credential helper, autocrlf) — Git và Cargo tự xử lý được bằng cấu hình điều kiện native, không cần một templating engine riêng.
- Phần Windows-only thật sự (registry, winget list, driver) tách bằng cách để trong thư mục riêng `windows/` ngay trong cùng repo, thay vì tách hẳn 2 repo — đơn giản hơn khi chỉ có 1 máy Windows.

### Cấu trúc (1 repo duy nhất)

```
dotfiles/                       (1 Git repo, ngoài phạm vi OneDrive sync)
├── git/
│   ├── .gitconfig              # phần chung: alias, user.name/email
│   ├── .gitconfig-windows      # phần riêng Windows: autocrlf, credential helper path
│   └── .gitconfig-linux        # phần riêng Linux/WSL
├── cargo/
│   └── config.toml             # 1 file dùng chung, có sẵn [target.'cfg(windows)'] / [target.'cfg(unix)']
├── powershell/
│   └── Microsoft.PowerShell_profile.ps1
├── bash/
│   └── .bashrc                 # cho WSL/Linux — không cố ép chung file với PowerShell
├── windows-terminal/
│   └── settings.json
├── vscodium/
│   ├── settings.json
│   ├── keybindings.json
│   └── extensions.txt            # danh sach extension, quan ly qua 06-vscodium-extensions.ps1
├── windows/                     # phần chỉ Windows: registry, driver list, không symlink, chạy 1 lần
│   ├── packages/winget.json
│   └── scripts/
│       ├── 01-bootstrap.ps1
│       ├── 02-install-apps.ps1
│       ├── 03-configure-windows.ps1
│       ├── 04-link-dotfiles.ps1   # script tạo symlink — xem mục 9
│       ├── 05-restore-data.ps1
│       └── 06-vscodium-extensions.ps1
└── link.sh                       # script tạo symlink phía Linux/WSL
```

### Thứ tự bootstrap máy mới (tổng quan)
1. Cài Windows xong → cài Git trước tiên (mục 8).
2. Clone repo `dotfiles` về `C:\dotfiles` (**không** đặt trong Documents/Desktop nếu chúng bị OneDrive redirect — xem cảnh báo mục 1 và mục 9).
3. Chạy `windows\scripts\01-bootstrap.ps1` → `04-link-dotfiles.ps1` (tạo toàn bộ symlink) → `05-restore-data.ps1`.
4. Bên WSL/Linux: `bash link.sh` để symlink phần `.bashrc`, `.gitconfig-linux`.

### Lỗi thường gặp
- ⚠️ Đặt repo `dotfiles` bên trong `Documents` hoặc `Desktop` đã bị OneDrive Known Folder Move redirect → OneDrive cố sync cả symlink lẫn file thật, gây trùng lặp hoặc lỗi "can't sync" liên tục. Đặt repo ở path độc lập như `C:\dotfiles`.
- ⚠️ Trộn lẫn file Windows-only (registry script, danh sách driver) chung với file cấu hình cá nhân rồi lỡ tay để repo public — vô tình lộ thông tin máy.

---

## 1. Backup trước khi cài

### Mục tiêu
Không mất danh tính (SSH/GPG) và dữ liệu; không backup thứ có thể tái tạo bằng script.

### Các bước thực hiện chi tiết

1. **SSH keys — chỉ áp dụng nếu bạn đã có key đang dùng ở nhiều nơi (deploy key, CI, server riêng)**
   ```powershell
   # Windows
   Copy-Item -Recurse $env:USERPROFILE\.ssh D:\backup\ssh
   ```
   ```bash
   # WSL/Linux
   cp -r ~/.ssh /mnt/d/backup/ssh
   ```
   > Nếu bạn **chưa có SSH key** (trường hợp phổ biến với máy cá nhân mới bắt đầu dùng Git nghiêm túc): bỏ qua bước này hoàn toàn. Đừng backup một thư mục rỗng/gần rỗng cho có — tạo key mới ngay trên máy mới ở mục 9 rẻ hơn và sạch hơn nhiều so với việc duy trì quy trình backup cho một thứ chưa tồn tại.
2. **GPG keys + trust database — chỉ áp dụng nếu bạn đang ký commit (`commit.gpgsign`)**
   ```bash
   gpg --list-secret-keys --keyid-format long   # lấy KEY_ID
   gpg --export-secret-keys --armor <KEY_ID> > private.asc
   gpg --export --armor <KEY_ID> > public.asc
   gpg --export-ownertrust > ownertrust.txt
   ```
   Copy 3 file này ra ổ ngoài, **không** để `private.asc` trên cloud không mã hoá — nếu cần, nén 7z có mật khẩu trước khi upload.
   > Nếu bạn **không dùng GPG** hiện tại: bỏ qua toàn bộ mục này. Đừng setup GPG "phòng khi sau này cần" trong lúc provisioning — nó chỉ tạo thêm bề mặt cần bảo trì (backup key, ownertrust, hết hạn key) cho một tính năng chưa dùng đến. Muốn ký commit thì tạo key lúc thật sự cần.
3. **BitLocker Recovery Key**
   ```powershell
   manage-bde -protectors -get C:
   ```
   Ghi lại "Numerical Password" (48 số), lưu vào Microsoft Account **và** password manager cá nhân.
4. **Certificates cá nhân (nếu có)**: `certmgr.msc` → chuột phải cert → All Tasks → Export → chọn "Yes, export the private key" → đặt mật khẩu cho file `.pfx`.
5. **WSL distro** (chỉ nếu có state không nằm trong Git):
   ```powershell
   wsl --export Debian D:\backup\debian-backup.tar
   ```
6. **Scheduled Tasks tự tạo**:
   ```powershell
   Get-ScheduledTask | Where-Object {$_.TaskPath -notlike "\Microsoft*"}
   Export-ScheduledTask -TaskName "TenTask" | Out-File D:\backup\TenTask.xml
   ```
7. **Data cá nhân/project chưa push Git**: rsync/robocopy ra ổ ngoài.
8. **VSCodium & Browser**: Browser dùng Sync tài khoản có sẵn (không cần export thủ công) — **trừ Brave**: Brave dùng cơ chế **Sync Chain** (passphrase 24 từ, không có tài khoản), passphrase này **không lưu trên server** nên đóng vai trò như BitLocker Recovery Key — bắt buộc copy ra ngoài (`Settings → Sync → View Sync Code`) **trước khi** cài lại Windows, mất nó = không join lại được chain cũ. VSCodium thì khác VS Code — không có Settings Sync dùng được (xem mục 9), nên `settings.json`/`keybindings.json` cần đưa vào dotfiles repo + symlink, và danh sách extension cần export ra file text (mục 9) thay vì dựa vào sync tài khoản.

### Lỗi thường gặp
- ⚠️ Quên rằng **Credential Manager không migrate được** giữa 2 máy (bind theo DPAPI + machine key) — nhiều người cố `cmdkey /list` rồi copy sang máy mới, kết quả bị lỗi hoặc credential không giải mã được. Cách đúng: đăng nhập lại từng dịch vụ sau khi cài xong Git Credential Manager.
- ⚠️ Backup GPG chỉ export **public key**, quên `--export-secret-keys` → sang máy mới không sign commit được, phải tạo key mới, mất luôn trust chain cũ.
- ⚠️ Quên `--export-ownertrust` → import lại private key thành công nhưng GPG vẫn báo "unknown trust" mỗi lần dùng.
- ⚠️ Backup nguyên registry rồi kỳ vọng "restore" trên máy cài mới — Windows mới có driver/service khác, import registry cũ dễ gây blue screen hoặc app không mở được. Chỉ export các key cụ thể bạn tự chỉnh.
- ⚠️ Quên BitLocker recovery key, sau đó khi thay mainboard/update BIOS TPM reset → ổ bị khoá, **không có cách nào phục hồi dữ liệu** nếu không có key.

### Source of Truth
- Microsoft Learn – "BitLocker recovery guide"; "Data Protection API (DPAPI)"
- GnuPG official manual (`gnupg.org/documentation`)
- Microsoft Learn – "Back up and restore WSL distributions"; "Export-ScheduledTask"

---

## 2. Chuẩn bị USB cài Windows

### Các bước thực hiện chi tiết

1. Tải ISO Windows từ Microsoft Software Download Center (chọn đúng edition: Home/Pro).
2. Nếu dùng **Rufus**: cắm USB (≥8GB) → mở Rufus → chọn ISO → Partition scheme: **GPT** → Target system: **UEFI (non CSM)** → File system: NTFS hoặc FAT32 tuỳ ISO size → Start.
3. Nếu dùng **MCT**: chạy `MediaCreationTool.exe` → "Create installation media for another PC" → chọn USB → tool tự làm phần còn lại.
4. Nếu dùng **Ventoy**: cài Ventoy vào USB 1 lần (`Ventoy2Disk.exe` → Install), sau đó chỉ cần copy file `.iso` vào USB — không cần format lại mỗi lần đổi ISO.
5. Trước khi cài: vào BIOS/UEFI kiểm tra **Secure Boot: Enabled**, **Boot mode: UEFI**, **TPM: Enabled** (thường gọi PTT trên Intel hoặc fTPM trên AMD), **và Virtualization Technology (Intel VT-x hoặc AMD-V/SVM): Enabled**.

> ⚠️ **Bổ sung — lỗi bị thiếu ở bản trước**: mục cuối (Virtualization VT-x/AMD-V) **bắt buộc phải bật** để WSL2 và Hyper-V hoạt động. Đây là nguyên nhân phổ biến nhất gây lỗi `WslRegisterDistribution failed with error 0x80370102` (thường ghi là "Hypervisor không chạy") ở mục 8 — và nếu bỏ qua, bạn sẽ phải quay lại vào BIOS lúc đang cài Docker/WSL, mất công khởi động lại giữa chừng.

### Lỗi thường gặp
- ⚠️ Trong Rufus chọn nhầm Partition scheme **MBR** cho máy UEFI → USB boot được nhưng cài xong máy không nhận đúng chuẩn GPT, hoặc không boot được sau khi cài.
- ⚠️ Dùng Rufus để "bypass" TPM/Secure Boot check cho máy **đủ chuẩn** chỉ vì lười vào BIOS bật — dẫn đến cài xong thiếu tính năng bảo mật quan trọng mà không hay biết.
- ⚠️ Copy nhiều ISO trực tiếp vào USB thường (không qua Ventoy) rồi thắc mắc sao không boot — USB thường chỉ boot được 1 ISO đã "burn" đúng cách, không phải USB lưu trữ file thường.
- ⚠️ Quên rằng Windows 11 cần ổ đích ≥ 64GB và RAM đủ — cài trên máy ảo/máy cũ thiếu RAM sẽ dừng giữa chừng.

### Source of Truth
- Microsoft Learn – "Create installation media for Windows"; "Windows 11 requirements"
- Rufus official documentation (`rufus.ie`)
- Ventoy official GitHub (`github.com/ventoy/Ventoy`)

---

## 3. Cài Windows (Phân vùng)

### Các bước thực hiện chi tiết

1. Boot từ USB → tại màn hình "Where do you want to install Windows", nhấn **Shift+F10** để mở Command Prompt (tuỳ chọn, nếu muốn tự tạo phân vùng Data trước).
2. Nếu để Windows Setup tự động: chọn ổ trống → Windows tự tạo EFI + MSR + Recovery + 1 phân vùng OS chiếm hết dung lượng còn lại.
3. Nếu muốn tách sẵn phân vùng Data: dùng `diskpart` trong Shift+F10:
   ```
   diskpart
   list disk
   select disk 0
   clean
   convert gpt
   create partition efi size=260
   format quick fs=fat32 label="System"
   create partition msr size=16
   create partition primary size=122880   (~120GB cho C:, đơn vị MB)
   format quick fs=ntfs label="Windows"
   create partition primary                (phần còn lại cho D:)
   format quick fs=ntfs label="Data"
   assign
   exit
   ```
4. Quay lại Setup, chọn đúng phân vùng "Windows" vừa tạo để cài OS, phân vùng "Data" để trống, dùng sau khi cài xong.

> ⚠️ **Riêng cho máy dual-boot Windows + Linux (đúng trường hợp máy Acer Nitro của bạn)**:
> - Ở bước `diskpart`, **chừa lại một vùng "unallocated"** (không `create partition`, không `format`) cho Linux tự phân vùng sau — Debian installer sẽ tự tạo `/`, `swap`, v.v. trong vùng trống đó.
> - **Cài Windows trước, Linux sau.** Windows installer luôn ghi đè bootloader (EFI System Partition) mà không hỏi, xoá mất GRUB nếu cài sau. GRUB thì biết cách tự thêm entry "chain-load" Windows Boot Manager, nên làm Linux sau sẽ ra 1 menu boot chọn được cả 2.
> - **Đồng hồ lệch giờ giữa 2 OS** là lỗi rất hay gặp: Windows mặc định đọc RTC (hardware clock) theo giờ **local**, còn hầu hết bản Linux mặc định đọc RTC theo **UTC**. Mỗi lần đổi OS, đồng hồ lệch đúng bằng số giờ timezone của bạn. Fix bằng cách cho Windows đọc RTC theo UTC (đưa Windows về cùng chuẩn UTC như Linux), thêm vào `03-configure-windows.ps1`:
>   ```powershell
>   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" `
>       -Name "RealTimeIsUniversal" -Value 1 -PropertyType DWORD -Force
>   ```
>   (cần restart để có hiệu lực; ⚠️ chỉ áp dụng khi máy **không** dùng chung với hệ thống Windows-only khác kỳ vọng RTC local giờ).

### WSL2 VHDX và Docker data root — dời khỏi C: (bổ sung cách fix cụ thể cho rủi ro đã nêu ở "Lỗi thường gặp")
Sau khi cài xong WSL2 (mục 8), tạo file `%USERPROFILE%\.wslconfig` để giới hạn RAM và tránh VHDX phình to chiếm hết C: theo thời gian:
```ini
[wsl2]
memory=8GB
swap=2GB
```
Muốn dời hẳn vị trí lưu VHDX của từng distro sang D:, dùng `wsl --export` rồi `wsl --import` lại vào path D: (Microsoft Learn có hướng dẫn chi tiết "Move a WSL 2 distro"). Với Docker Desktop, đổi qua **Settings → Resources → Advanced → Disk image location** sang D: trước khi có nhiều image/volume tích luỹ, vì đổi sau khi đã có data cần thao tác migrate thủ công phức tạp hơn.

### Lỗi thường gặp
- ⚠️ Tự ý xoá/định dạng lại phân vùng **MSR** hoặc **Recovery** vì tưởng nó thừa → gây lỗi khi Windows Update lớn (feature update) cần dùng Recovery partition để rollback.
- ⚠️ Chia C: quá nhỏ (dưới 100GB) — Docker Desktop + WSL2 VHDX + Windows Update cache dễ làm đầy ổ trong vài tháng.
- ⚠️ Không xoá partition table cũ (`clean` trong diskpart) khi cài trên ổ đã dùng trước đó → Setup báo lỗi hoặc tạo layout GPT/MBR lẫn lộn.

### Source of Truth
- Microsoft Learn – "Windows and GPT FAQ"; "Recovery options in Windows"

---

## 4. Việc phải làm ngay sau khi vào Desktop lần đầu

### Các bước thực hiện chi tiết (đúng thứ tự)

1. Kết nối WiFi/LAN.
2. Settings → Windows Update → Check for updates → lặp lại "Check for updates" + restart cho đến khi hiện "You're up to date" (thường 2-4 vòng).
3. Vào trang OEM (Acer Support) → nhập đúng model máy → tải bản BIOS mới nhất **nếu** có ghi chú fix bảo mật/tương thích quan trọng; nếu không có lý do cụ thể, **có thể bỏ qua bước này ở lần đầu** và làm sau khi máy đã ổn định.
4. Settings → Time & Language → xác nhận đúng múi giờ/khu vực.
5. Settings → Accounts → Windows Update → Activation: xác nhận "Windows is activated".
6. Settings → System → Power & battery → chọn Power mode phù hợp (Balanced cho dev máy chạy Docker nền).
7. Kiểm tra Windows Security → Virus & threat protection: để mặc định bật, chưa thêm exclusion vội (thêm sau khi cài xong dev tools ở mục 6).

### Lỗi thường gặp
- ⚠️ Cài driver GPU/chipset từ OEM **trước** khi chạy hết vòng Windows Update — dễ bị Windows Update ghi đè hoặc conflict driver version, phải gỡ cài lại.
- ⚠️ Update BIOS ngay lần đầu dù không có lý do cụ thể, rồi mất điện/tắt máy giữa chừng — nguy cơ brick máy hoàn toàn.
- ⚠️ Tắt Windows Defender toàn bộ ngay từ đầu "cho máy nhẹ" — mất lớp bảo vệ cơ bản trước khi kịp cài AV khác.
- ⚠️ Quên đổi Region/Time trước khi cài các dev tool có phụ thuộc locale (một số tool build lỗi với locale sai, đặc biệt liên quan định dạng số thập phân).

### Source of Truth
- Microsoft Learn – "Windows Update: FAQ"; "Power plans (plan settings) documentation"

---

## 5. Driver

### Các bước thực hiện chi tiết

1. Mở **Device Manager** (`devmgmt.msc`) → kiểm tra xem có thiết bị nào có dấu chấm than vàng.
2. Vào trang Acer Support → nhập serial number/model → tải theo đúng thứ tự dependency:
   - Chipset → Intel ME → Storage (AHCI/NVMe) → GPU (NVIDIA qua Acer trước) → LAN → WiFi → Bluetooth → Audio → Touchpad → Camera.
3. Cài từng cái, **restart sau mỗi driver quan trọng** (chipset, GPU) trước khi cài driver tiếp theo.
4. Sau khi cài hết theo Acer, vào NVIDIA Driver Downloads kiểm tra có bản mới hơn không — nếu có và cần tính năng mới (CUDA version mới cho dev AI/ML chẳng hạn), cân nhắc cài đè, theo dõi kỹ Optimus/hybrid graphics có hoạt động bình thường không sau đó.
5. Quay lại Device Manager xác nhận hết dấu chấm than vàng.

### Lỗi thường gặp
- ⚠️ Cài GPU driver **trước** chipset driver → driver GPU không nhận đúng PCIe lane config, hiệu năng thấp bất thường mà không rõ nguyên nhân.
- ⚠️ Tải driver GPU "generic" từ NVIDIA thẳng cho laptop có Optimus (switchable graphics) → mất tính năng chuyển đổi GPU tích hợp/rời tự động, tốn pin nhanh hơn hẳn.
- ⚠️ Bỏ qua Intel ME driver vì tưởng "không quan trọng" → một số tính năng quản lý điện năng/bảo mật cấp thấp không hoạt động đúng, laptop nóng/hao pin hơn bình thường.
- ⚠️ Không restart giữa các bước cài driver lớn (chipset, GPU) → driver cài chồng lên nhau trong cùng 1 phiên, dễ conflict ngầm dù Device Manager không báo lỗi ngay.

### Source of Truth
- Acer Support Driver Download (theo model máy cụ thể)
- Intel Download Center; NVIDIA Driver Downloads (chính thức)
- Microsoft Learn – "Driver installation guidance"

---

## 6. Cấu hình Windows

### Các bước thực hiện chi tiết (script hoá được, khuyến nghị gộp vào `03-configure-windows.ps1`)

```powershell
# Bật WSL2 + Virtual Machine Platform
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux, VirtualMachinePlatform -All -NoRestart

# Bật Long Path
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force

# Tắt Advertising ID
New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" `
  -Name "Enabled" -Value 0 -PropertyType DWORD -Force

# Loại trừ project folder khỏi Windows Search Indexing (làm qua UI:
# Settings > Search > Searching Windows > Excluded paths — chưa có cmdlet chính thức ổn định)

# Bật Developer Mode
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
  -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -PropertyType DWORD -Force
```

Sau khi restart:
- Bật BitLocker: Settings → Privacy & Security → Device encryption (hoặc `manage-bde -on C:` qua PowerShell Admin) → lưu recovery key ngay (mục 1).

> ⚠️ **Chi tiết kỹ thuật quan trọng — sửa lại phần mô tả mơ hồ ở bản trước**: khi BitLocker dùng TPM protector, key được seal vào một tập các **PCR (Platform Configuration Register)** đo firmware/bootloader lúc khởi động. Cụ thể, **PCR7 đo nội dung Secure Boot (bao gồm biến `db`/`dbx`/`KEK`)**. Nếu bạn ghi lại `db` bằng KeyTool.efi hoặc chỉnh Secure Boot key (đúng việc bạn đang làm để xử lý vấn đề Insyde H2O) **sau khi** đã bật BitLocker, giá trị PCR7 đo được ở lần boot kế tiếp sẽ khác với giá trị lúc seal → Windows **không tự unlock được, bắt buộc phải nhập Recovery Key** (48 số đã lưu ở mục 1). Đây không phải lỗi hỏng ổ, chỉ là cơ chế bảo vệ hoạt động đúng như thiết kế — nhưng nếu không biết trước, dễ hoảng khi thấy màn hình xanh đòi recovery key sau khi thao tác Secure Boot.
- Cấu hình Storage Sense: Settings → System → Storage → bật, đặt lịch dọn hàng tháng.
- Cấu hình Windows Defender exclusion **sau khi** cài xong Docker/WSL (mục 8): Settings → Privacy & Security → Virus & threat protection → Exclusions → thêm đường dẫn `\\wsl$`, thư mục `node_modules`, thư mục chứa Docker data.

### Lỗi thường gặp
- ⚠️ Thêm Defender exclusion cho **toàn bộ ổ D:** thay vì chỉ thư mục cụ thể — mở lỗ hổng bảo mật lớn không cần thiết.
- ⚠️ Bật BitLocker **trước khi** đã lưu xong recovery key ở nơi an toàn — nếu máy crash giữa chừng lúc encrypt, rủi ro mất dữ liệu.
- ⚠️ Sửa registry Long Path nhưng quên rằng một số ứng dụng (không phải mọi ứng dụng) vẫn cần cấu hình riêng (`git config --system core.longpaths true`) mới thật sự hỗ trợ đường dẫn dài.
- ⚠️ Bật Hyper-V thủ công song song với việc dùng VirtualBox/VMware — 2 hypervisor có thể xung đột, VM cũ chạy VirtualBox tự nhiên bị chậm hẳn hoặc không khởi động được sau khi bật WSL2/Hyper-V.

### Source of Truth
- Microsoft Learn – "Enable-WindowsOptionalFeature"; "Maximum Path Length Limitation"; "BitLocker overview"; "Windows privacy settings"

---

## 7. Package Manager

### Các bước thực hiện chi tiết

1. Kiểm tra winget đã có sẵn (Windows 11 có sẵn qua App Installer): `winget --version`.
2. Nếu chưa có: cài từ Microsoft Store "App Installer" hoặc tải `.msixbundle` từ GitHub `microsoft/winget-cli` release chính thức.
3. Cài Scoop (không cần admin):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   Invoke-RestMethod get.scoop.sh | Invoke-Expression
   ```
4. Sau khi cài xong app cần thiết (mục 8), export danh sách để tái sử dụng:
   ```powershell
   winget export -o packages\winget.json
   scoop export > packages\scoop-apps.txt
   ```
5. Trên máy mới, import lại:
   ```powershell
   winget import -i packages\winget.json --accept-package-agreements
   ```

### Lỗi thường gặp
- ⚠️ Cài cùng 1 phần mềm qua cả winget **và** Scoop **và** installer thủ công → 3 bản trùng, PATH rối, `where <tool>` trả về nhiều kết quả gây nhầm version đang chạy.
- ⚠️ Set `Set-ExecutionPolicy Unrestricted` (thay vì `RemoteSigned`) để "cho tiện" — mở toang khả năng chạy script độc hại không dấu.
- ⚠️ Quên chạy `winget export` sau khi cài thêm app mới → file JSON export cũ dần lệch khỏi thực tế, lần cài máy mới thiếu phần mềm mà không biết.

### Source of Truth
- Microsoft Learn – "winget command line reference"
- Scoop official documentation (`scoop.sh`)

---

## 8. Cài phần mềm (thứ tự & dependency)

### Các bước thực hiện chi tiết

```powershell
# 1. Browser (nếu chưa có Edge — Edge có sẵn, có thể cài thêm Chrome/Firefox)
winget install Google.Chrome

# 2. Git
winget install Git.Git

# 3. PowerShell 7+
winget install Microsoft.PowerShell

# 4. Windows Terminal
winget install Microsoft.WindowsTerminal

# 5. 7-Zip
winget install 7zip.7zip

# 6. VSCodium (khong dung VS Code chinh thuc - xem SOP muc 9 ve khac biet Settings Sync/marketplace)
winget install VSCodium.VSCodium

# 7. Bật WSL2 (đã làm ở mục 6) rồi cài distro
wsl --install -d Debian

# 8. Docker Desktop (SAU khi WSL2 đã bật và có distro)
winget install Docker.DockerDesktop

# 9. Toolchain qua version manager, không cài trực tiếp bản global
winget install Rustlang.Rustup
# Node: dùng nvm-windows thay vì cài Node trực tiếp
winget install CoreyButler.NVMforWindows
# Python: dùng pyenv-win
```

### Lỗi thường gặp
- ⚠️ Cài Docker Desktop **trước khi** bật WSL2 → báo lỗi "WSL2 installation is incomplete", phải gỡ cài lại từ đầu.
- ⚠️ Cài Node.js/Python bản cài đặt trực tiếp (installer .msi) thay vì qua nvm/pyenv → sau này cần đổi version cho project khác phải gỡ cài lại thủ công, không switch nhanh được.
- ⚠️ Cài Git nhưng không tick "Enable symbolic links" trong installer (tuỳ chọn ẩn trong Git for Windows setup) → sau này `git checkout` trên repo có symlink không tạo đúng link, chỉ tạo ra file text chứa đường dẫn.
- ⚠️ Cài WSL nhưng dùng distro Ubuntu mặc định qua Microsoft Store rồi thấy version cũ — nên chỉ định rõ `wsl --install -d Debian` (hoặc distro version cụ thể) thay vì để mặc định.

### Source of Truth
- Docker official documentation – "Install Docker Desktop on Windows"
- Microsoft Learn – "Install WSL"
- rustup.rs; nvm-windows GitHub (`coreybutler/nvm-windows`)

---

## 9. Setup Development Environment (symlink thuần — không dùng chezmoi)

### Mục tiêu
File cấu hình thật nằm trong repo Git; vị trí Windows/Linux mong đợi (`$PROFILE`, `~/.gitconfig`...) chỉ là **symlink trỏ vào đó**. Sửa ở vị trí thật hay vị trí symlink đều là sửa cùng 1 file — không có bước "apply" trung gian, không có khái niệm nguồn/đích lệch nhau.

### Điều kiện tiên quyết trên Windows (đọc trước khi làm, tránh lỗi phổ biến nhất)
Tạo symlink trên Windows (`New-Item -ItemType SymbolicLink`) mặc định **cần quyền Administrator**, trừ khi bạn bật:
```
Settings → Privacy & Security → For developers → Developer Mode: On
```
Bật Developer Mode cấp cho user hiện tại quyền tạo symlink **không cần chạy PowerShell as Admin** (`SeCreateSymbolicLinkPrivilege`). Nếu không bật, mọi lệnh symlink dưới đây sẽ báo lỗi `A required privilege is not held by the client`.

### Các bước thực hiện chi tiết — Windows

1. Clone repo về path độc lập, **ngoài** phạm vi OneDrive:
   ```powershell
   git clone https://github.com/<you>/dotfiles.git C:\dotfiles
   ```
2. **Danh tính Git — tạo mới, không phục hồi** (áp dụng cho trường hợp chưa có SSH/GPG key sẵn):
   ```powershell
   ssh-keygen -t ed25519 -C "email@cua-ban.com"
   # Windows: đảm bảo service ssh-agent chạy để không phải gõ passphrase mỗi lần
   Get-Service ssh-agent | Set-Service -StartupType Automatic
   Start-Service ssh-agent
   ssh-add $env:USERPROFILE\.ssh\id_ed25519
   ```
   Thêm public key (`id_ed25519.pub`) vào GitHub/GitLab ngay. Nếu có dùng WSL song song, tạo **thêm 1 key riêng bên WSL** (không symlink dùng chung — permission model NTFS vs ext4 khác nhau, OpenSSH sẽ từ chối key có permission "quá mở" khi mount qua `/mnt/c`), rồi add cả 2 public key vào GitHub.
   GPG: **bỏ qua bước này** trừ khi bạn thật sự sign commit — nếu cần sau này, tạo key lúc đó (`gpg --full-generate-key`), không cần chuẩn bị trước.
3. Chạy script tạo symlink `windows\scripts\04-link-dotfiles.ps1`:
   ```powershell
   $links = @{
     "$HOME\.gitconfig"                              = "C:\dotfiles\git\.gitconfig-windows"
     "$PROFILE"                                       = "C:\dotfiles\powershell\Microsoft.PowerShell_profile.ps1"
     "$HOME\.cargo\config.toml"                       = "C:\dotfiles\cargo\config.toml"
   }

   foreach ($item in $links.GetEnumerator()) {
       $linkPath = $item.Key
       $targetPath = $item.Value

       if (-not (Test-Path $targetPath)) {
           Write-Warning "Target không tồn tại, bỏ qua: $targetPath"
           continue
       }
       # Đảm bảo thư mục cha của linkPath tồn tại (vd $PROFILE cần thư mục WindowsPowerShell)
       $parent = Split-Path $linkPath -Parent
       if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

       if (Test-Path $linkPath) {
           # Idempotent: nếu đã là symlink đúng target thì bỏ qua, nếu là file thật thì backup trước khi ghi đè
           $existing = Get-Item $linkPath -Force
           if ($existing.LinkType -eq "SymbolicLink") {
               Remove-Item $linkPath -Force
           } else {
               Rename-Item $linkPath "$linkPath.bak-$(Get-Date -Format yyyyMMdd)" -Force
           }
       }
       New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -Force | Out-Null
       Write-Host "Linked: $linkPath -> $targetPath"
   }
   ```
4. Windows Terminal — **kiểm tra đúng path trước khi symlink**, vì path khác nhau tuỳ cách cài (xem "Lỗi thường gặp" bên dưới):
   ```powershell
   # Nếu cài qua Microsoft Store / winget (bản packaged, phổ biến nhất):
   $wtPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
   Remove-Item $wtPath -Force -ErrorAction SilentlyContinue
   New-Item -ItemType SymbolicLink -Path $wtPath -Target "C:\dotfiles\windows-terminal\settings.json"
   ```
5. Xác nhận symlink tạo đúng (đừng chỉ tin là nó chạy không lỗi):
   ```powershell
   Get-Item $PROFILE | Select-Object LinkType, Target
   ```

### Các bước thực hiện chi tiết — WSL/Linux (`link.sh`)
```bash
#!/usr/bin/env bash
set -euo pipefail
DOTFILES="$HOME/dotfiles"   # hoặc /mnt/c/dotfiles nếu share cùng repo qua Windows

declare -A links=(
  ["$HOME/.gitconfig"]="$DOTFILES/git/.gitconfig-linux"
  ["$HOME/.bashrc"]="$DOTFILES/bash/.bashrc"
  ["$HOME/.cargo/config.toml"]="$DOTFILES/cargo/config.toml"
)

for link in "${!links[@]}"; do
  target="${links[$link]}"
  mkdir -p "$(dirname "$link")"
  if [ -L "$link" ]; then rm "$link"; elif [ -e "$link" ]; then mv "$link" "$link.bak-$(date +%Y%m%d)"; fi
  ln -s "$target" "$link"
  echo "Linked: $link -> $target"
done
```

### Phần nội dung khác nhau theo OS — dùng cơ chế native, không dùng file riêng cho mọi thứ
`~/.cargo/config.toml` là **1 file duy nhất, symlink giống hệt trên cả 2 OS** vì Cargo tự chọn section theo target:
```toml
[target.'cfg(windows)']
rustflags = ["-C", "target-feature=+crt-static"]
[target.'cfg(unix)']
linker = "clang"
```
Còn `.gitconfig` thì tách 2 file `-windows`/`-linux` (như script trên) vì phần khác nhau (credential helper path, `core.autocrlf`) là 2 giá trị khác hẳn nhau, không gộp bằng `cfg()` được — dùng `include.path` trỏ vào 1 file `.gitconfig-shared` (alias, user.name/email) để không lặp lại phần chung.

### VSCodium & Browser
Browser vẫn dùng Sync tài khoản có sẵn (Chrome/Edge — đăng nhập, bật Sync, không cần thao tác gì thêm).

**VSCodium thì khác VS Code — không đi theo hướng "Settings Sync"**: bản Settings Sync built-in của Microsoft **không hoạt động trên VSCodium** (gắn với backend/tài khoản riêng của Microsoft mà bản build VSCodium không có). Vì vậy quay lại đúng mô hình symlink của cả SOP này:

- `settings.json` và `keybindings.json` là file JSON thuần, tương thích 100% giữa VS Code và VSCodium → symlink bình thường như mọi config khác (xem script `04-link-dotfiles.ps1`), path đúng là:
  - Windows: `%APPDATA%\VSCodium\User\settings.json`
  - WSL/Linux: `~/.config/VSCodium/User/settings.json`
- **Extension thì không symlink được** (mỗi extension là 1 thư mục riêng, không phải 1 file cấu hình) → quản lý bằng **danh sách tường minh** (`vscodium/extensions.txt` trong repo) + script cài lại (`06-vscodium-extensions.ps1`), tương tự cách `winget export/import` quản lý app.
- ⚠️ **VSCodium mặc định dùng Open VSX Registry, không phải Microsoft Marketplace** — một số extension độc quyền của Microsoft (đặc biệt **C/C++ — `ms-vscode.cpptools`**, C# Dev Kit, Live Share) bị khoá theo license, không cài được trên VSCodium dù chỉnh `product.json`. Với công việc systems/embedded của bạn, khuyến nghị dùng **`llvm-vs-code-extensions.vscode-clangd`** thay cho C/C++ extension của Microsoft.

### Lỗi thường gặp (rất dễ dính, dựa trên các gotcha thực tế của cơ chế symlink Windows)
- ⚠️ Quên bật Developer Mode và không chạy PowerShell as Admin → toàn bộ script trên fail ngay từ dòng đầu với lỗi privilege, dễ tưởng nhầm là do path sai.
- ⚠️ **Windows Terminal path không cố định**: bản cài qua Microsoft Store/winget dùng path `Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`; bản Portable/Preview hoặc dev build lại dùng `%LOCALAPPDATA%\Microsoft\Windows Terminal\settings.json`. Symlink nhầm path (do copy hardcode từ hướng dẫn khác) khiến bạn sửa `settings.json` mà Windows Terminal không đọc, tưởng config "không lưu được".
- ⚠️ Symlink trỏ vào repo đặt trong `Documents`/`Desktop` bị OneDrive KFM redirect → OneDrive có thể sync nhầm symlink thành file rỗng hoặc báo lỗi liên tục — đã cảnh báo ở mục 1/0, nhắc lại vì đây là lỗi hay bị bỏ qua nhất.
- ⚠️ Xoá nhầm **file thật trong repo** thay vì symlink khi dọn dẹp (`Remove-Item` không phân biệt rõ symlink hay file thật nếu không check `LinkType` trước) — luôn `Get-Item ... | Select LinkType` trước khi xoá.
- ⚠️ Đổi tên/di chuyển thư mục `C:\dotfiles` sau này (vd đổi ổ đĩa) → toàn bộ symlink cũ trỏ vào path không còn tồn tại, ứng dụng âm thầm dùng lại config mặc định (không báo lỗi rõ ràng) — nếu đổi vị trí repo, phải chạy lại script link.
- ⚠️ Symlink do Git tạo (nếu bạn để symlink **bên trong** chính repo Git, khác với symlink chúng ta tạo ở đây trỏ *vào* repo) yêu cầu bật `git config --global core.symlinks true` **trước khi** clone — nếu bật sau, các symlink cũ trong repo đã bị checkout thành file text chứa đường dẫn, phải clone lại từ đầu.
- ⚠️ Không set đúng permission cho SSH private key trên Windows (OpenSSH yêu cầu ACL chỉ user hiện tại đọc được) → lỗi `UNPROTECTED PRIVATE KEY FILE` khi `ssh -T git@github.com`:
  ```powershell
  icacls "$env:USERPROFILE\.ssh\id_ed25519" /inheritance:r /grant:r "$($env:USERNAME):(R)"
  ```
- ⚠️ Truy cập symlink Windows từ phía WSL qua `/mnt/c/...` đôi khi không resolve đúng như symlink thật (tuỳ version WSL và cấu hình `/etc/wsl.conf`) — nếu cần dùng chung 1 file thật giữa Windows và WSL, ưu tiên đặt file gốc trong `$HOME` của WSL (ext4, native) rồi mount ngược sang Windows qua `\\wsl$\`, thay vì ngược lại.

### Source of Truth
- Microsoft Learn – "Create and manage symbolic links" (`mklink`, `New-Item -ItemType SymbolicLink` behavior & privilege requirement)
- Microsoft Learn – "Enable your device for development" (Developer Mode & `SeCreateSymbolicLinkPrivilege`)
- Git official documentation – `git-config` manual, mục `includeIf` và `core.symlinks`
- The Cargo Book (official) – "Configuration", target-specific config qua `cfg()`
- Microsoft Learn – "Get started with OpenSSH for Windows" (permissions cho private key)
- Microsoft Learn – "OneDrive Known Folder Move" documentation

---

## 10. Restore Data

### Các bước thực hiện chi tiết

1. Chạy script symlink (mục 9) → có ngay Git/PowerShell/Cargo config đúng chỗ.
2. Tạo SSH key mới (mục 9) và add vào GitHub — nếu bạn có key cũ cần dùng lại (case hiếm), import từ backup thay vì tạo mới.
3. Test kết nối trước khi làm gì khác:
   ```bash
   ssh -T git@github.com
   ```
4. Clone lại project code từ remote (không copy file cũ từ backup — clone sạch hơn, tránh mang theo rác `.git` hỏng).
5. Restore data không nằm trong Git (dataset lớn, secrets) từ ổ ngoài/cloud.
6. Restore Docker volumes cuối cùng, sau khi Docker Desktop chạy ổn định:
   ```powershell
   docker run --rm -v myvolume:/data -v D:\backup:/backup alpine tar xzf /backup/myvolume.tar.gz -C /data
   ```

### Lỗi thường gặp
- ⚠️ Copy trực tiếp thư mục `.git` từ ổ backup sang máy mới thay vì clone lại — nếu backup bị lỗi giữa chừng (mất điện lúc copy), repo có thể bị corrupt mà không phát hiện ngay.
- ⚠️ Restore Docker volume trước khi Docker Desktop backend WSL2 đã khởi động ổn định → lệnh restore chạy nhưng container không thấy data, tưởng nhầm là mất data.
- ⚠️ Quên kiểm tra `ssh -T git@github.com` trước, đến lúc `git clone` mới phát hiện key lỗi — mất thời gian debug giữa chừng việc khác.

### Source of Truth
- GitHub Docs – "Testing your SSH connection"
- Docker official documentation – "Back up, restore, or migrate data volumes"

---

## 11. Automation

### Các bước thực hiện chi tiết (toàn bộ pipeline từ đầu đến cuối)

```powershell
# Trên máy Windows mới, sau khi cài Windows xong:

# Bước 1: Cài Git thủ công 1 lần (chưa automation hoá được vì chưa có gì để chạy script)
winget install Git.Git

# Bước 2: Clone repo dotfiles (đặt ngoài OneDrive, xem mục 0/9)
git clone https://github.com/<you>/dotfiles.git C:\dotfiles
cd C:\dotfiles

# Bước 3: Chạy bootstrap — cài winget packages, scoop
.\windows\scripts\01-bootstrap.ps1

# Bước 4: Cấu hình Windows-specific (registry, features, privacy — cần trước khi symlink vì bật Developer Mode)
.\windows\scripts\03-configure-windows.ps1

# Bước 5: Tạo symlink cho toàn bộ config (Git, PowerShell, Cargo, Windows Terminal)
.\windows\scripts\04-link-dotfiles.ps1

# Bước 6: Restore data
.\windows\scripts\05-restore-data.ps1
```

### Mức độ tự động hoá thực tế đạt được
Bước 1 (cài Git) và OOBE ban đầu vẫn cần tay. Từ bước 2 trở đi gần như 1 lệnh/1 script mỗi bước — riêng bước 4 (symlink) cần Developer Mode đã bật ở bước 4 trước đó, nên thứ tự 3 → 4 không được đảo ngược.

### Lỗi thường gặp
- ⚠️ Viết script không **idempotent** (chạy lại bị lỗi vì tài nguyên đã tồn tại) — ví dụ `New-Item -ItemType SymbolicLink` báo lỗi nếu link đã có sẵn từ lần chạy trước. Luôn kiểm tra tồn tại trước khi tạo (`Test-Path`).
- ⚠️ Script `winget import` không thêm cờ `--accept-package-agreements --accept-source-agreements` → script dừng lại chờ xác nhận tay giữa chừng, mất hết ý nghĩa tự động hoá.
- ⚠️ Đưa cả các bước cần tương tác 2FA (đăng nhập GitHub, Docker Hub) vào script và kỳ vọng "chạy xong hết" — các bước này về bản chất không thể tự động hoá hoàn toàn.

### Source of Truth
- chezmoi official documentation
- Microsoft Learn – "winget import"

---

## 12. Verification Checklist

- [ ] `winver` đúng build, Windows Update "up to date"
- [ ] Device Manager không có dấu chấm than vàng
- [ ] Settings > Activation: "Windows is activated"
- [ ] `manage-bde -status C:` → "Protection On", recovery key đã lưu 2 nơi
- [ ] `docker run hello-world` chạy thành công
- [ ] `wsl -l -v` hiển thị distro version 2
- [ ] `Get-Item $PROFILE, $HOME\.gitconfig | Select LinkType,Target` → xác nhận đúng `SymbolicLink` trỏ về `C:\dotfiles`, không phải file rời rạc
- [ ] `ssh -T git@github.com` xác thực OK
- [ ] `git commit -S` + `git log --show-signature` xác nhận GPG sign hoạt động
- [ ] `$PSVersionTable` đúng PowerShell 7+
- [ ] Font Nerd Font hiển thị icon đúng trong Windows Terminal (không bị "tofu")
- [ ] `fsutil behavior query DisableDeleteNotify` = 0 (TRIM đang bật)
- [ ] Đã tạo 1 System Restore Point ngay sau khi setup xong

### Lỗi thường gặp
- ⚠️ Không kiểm tra `LinkType` sau khi chạy script link — script chạy "thành công" không có nghĩa symlink trỏ đúng chỗ; nếu target không tồn tại lúc chạy, script (viết đúng như mục 9) sẽ bỏ qua và cảnh báo, nhưng dễ bị lướt qua nếu không đọc kỹ output.
- ⚠️ Quên tạo Restore Point sau khi setup xong — nếu 1 tuần sau có thay đổi làm hỏng máy, không có mốc "known good" gần nhất để quay lại.

### Source of Truth
- Microsoft Learn – "manage-bde command-line tool reference"; "fsutil behavior reference"; "Create and manage symbolic links"

---

## 13. Maintenance

| Tần suất | Nên làm | Không nên làm |
|---|---|---|
| Hàng tuần | `winget upgrade --all`, `docker system df` | Update driver/BIOS không có lý do cụ thể |
| Hàng tháng | `scoop update *`, review scheduled tasks, `docker system prune` | — |
| Hàng quý | Kiểm tra SMART, review lại repo `dotfiles` xem còn config lỗi thời, kiểm tra symlink còn trỏ đúng chỗ sau các lần update Windows Terminal/app | — |
| Hàng năm | Đánh giá lại toàn bộ SOP; nếu có dùng SSH/GPG key, test lại còn hoạt động (nếu không dùng thì bỏ qua mục này) | — |

### Lỗi thường gặp
- ⚠️ `docker system prune -a` không kiểm tra trước, xoá luôn image đang cần build lại từ đầu tốn thời gian.
- ⚠️ Để repo `dotfiles` "đóng băng" cả năm không review — khi thật sự cần cài lại máy mới thì phát hiện nhiều phần đã lỗi thời so với setup thực tế đang dùng, hoặc symlink Windows Terminal trỏ vào path đã đổi do app update từ packaged sang unpackaged.

### Source of Truth
- Microsoft Learn – "Windows Update for Business — best practices"
- Docker official documentation – "Prune unused Docker objects"

---

## Tổng kết luồng cài lại máy

1. Backup (mục 1) → 2. Tạo USB (mục 2, nhớ bật Virtualization trong BIOS) → 3. Cài Windows (mục 3) → 4. Bước đầu tiên trên Desktop (mục 4) → 5. Driver (mục 5) → 6. Cấu hình Windows + bật Developer Mode (mục 6) → 7. Package manager (mục 7) → 8. Cài phần mềm (mục 8) → 9. Chạy script symlink cho toolchain (mục 9) → 10. Restore data (mục 10) → 11. Chạy script tổng automation (mục 11) → 12. Verification checklist, kiểm tra `LinkType` (mục 12) → 13. Thiết lập lịch maintenance (mục 13).

Repo `dotfiles/README.md` nên là bản rút gọn (chỉ checklist + lệnh) của tài liệu này để dùng lúc thao tác thực tế; file này giữ vai trò tài liệu tham chiếu đầy đủ lý do/rủi ro.

### Đổi mới so với bản trước (changelog tự kiểm tra)
- Bỏ hoàn toàn chezmoi (mục 0, 9, 10, 11, 12, 13) — thay bằng symlink thuần + cơ chế điều kiện native của Git/Cargo, đúng yêu cầu không dùng công cụ ngoài.
- Bổ sung bước bật **Virtualization (VT-x/AMD-V)** trong BIOS ở mục 2 — thiếu ở bản trước, là nguyên nhân phổ biến gây lỗi WSL2.
- Sửa mô tả BitLocker + Secure Boot ở mục 6 thành chi tiết kỹ thuật chính xác (cơ chế PCR7) thay vì câu mơ hồ "có thể ảnh hưởng" — liên quan trực tiếp đến việc bạn đang chỉnh Secure Boot `db` trên máy Acer Nitro.
- Bổ sung cảnh báo OneDrive Known Folder Move ảnh hưởng đến symlink — gotcha đặc thù Windows dễ bị bỏ qua.
- Bổ sung cảnh báo path Windows Terminal `settings.json` khác nhau tuỳ cách cài (Store/winget vs Portable).
