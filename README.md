# Hệ thống Quản lý Đội xe (Fleet Management System)

- **Môn học**: Triển khai và Quản trị Hệ thống Phần mềm
- **Sinh viên thực hiện**: Nguyễn Quang Vinh
- **Mã số sinh viên (MSSV)**: DTC245180115
- **Tên repository**: DTC245180115-fleet-devops

---

## 1. Giới thiệu dự án
Hệ thống Quản lý Đội xe là giải pháp phần mềm chuyên biệt phục vụ các đơn vị vận tải và doanh nghiệp có đội xe thương mại. 
Hệ thống cung cấp:
- Quản lý hồ sơ xe và danh sách tài xế.
- Điều phối chuyến xe, phân công tài xế, quản lý trạng thái chuyến theo luồng khép kín (chống Race Condition bằng `SELECT ... FOR UPDATE`).
- Theo dõi số km công tơ mét, lịch sử tiêu thụ nhiên liệu và chi phí bảo dưỡng phương tiện.
- Cảnh báo trực quan các phương tiện sắp đến hạn đăng kiểm, bảo dưỡng định kỳ, hạn bảo hiểm và giấy phép lái xe của tài xế.
- Báo cáo thống kê chỉ số hiệu suất (KPI) và chi phí vận hành cho cấp quản trị.
- In phiếu lệnh điều xe kèm mã QR Code tạo động từ máy chủ.

---

## 2. Phân quyền người dùng (RBAC)
- **Driver (Tài xế)**: Xem các chuyến xe được phân công, bắt đầu/kết thúc chuyến, nhập chỉ số công tơ mét, ghi nhận lịch sử đổ nhiên liệu.
- **Dispatcher (Điều phối viên)**: Quản lý hồ sơ tài xế, tạo và điều phối chuyến xe, ghi nhận bảo dưỡng/sửa chữa và nhiên liệu, theo dõi hạn đăng kiểm, in phiếu lệnh điều xe.
- **Admin (Quản trị viên)**: Toàn quyền quản trị hệ thống, quản lý danh mục xe & loại xe (upload ảnh phương tiện), thanh lý xe, quản lý tài khoản người dùng, xem báo cáo tổng hợp KPI.

---

## 3. Kiến trúc hệ thống
Hệ thống được đóng gói và vận hành qua Docker Compose với kiến trúc nhiều lớp bảo mật:
- `nginx`: Reverse Proxy HTTPS (cổng 80 chuyển hướng 301 sang 443), hỗ trợ TLSv1.2/TLSv1.3, nén Gzip, Stub Status nội bộ và tích hợp đầy đủ Security Headers (`Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Content-Security-Policy`, `Permissions-Policy`, `server_tokens off`).
- `web`: Ứng dụng Node.js v20 (Express + EJS SSR + Vanilla CSS), phân quyền RBAC, phòng chống CSRF, IDOR, session cookie bảo mật (`Secure`, `HttpOnly`, `SameSite=Lax`). Cổng 3000 chỉ mở nội bộ trong Docker network.
- `db`: Cơ sở dữ liệu quan hệ PostgreSQL 16 (Alpine), lưu trữ 7 bảng chuẩn hóa với ràng buộc toàn vẹn và chỉ mục hiệu năng cao. Cổng 5432 không công khai ra bên ngoài.
- `pgadmin`: Giao diện web quản trị cơ sở dữ liệu qua đường dẫn con `/pgadmin/`. Cổng 80 chỉ mở nội bộ, kết nối bảo mật qua Nginx.
- *(Các thành phần Prometheus, Grafana, Loki, Promtail, cAdvisor, Exporters sẽ được tích hợp ở các bước tiếp theo).*

---

## 4. Hướng dẫn khởi chạy hệ thống

### 4.1. Chuẩn bị môi trường & Cấu hình biến môi trường
Sao chép tệp biến môi trường mẫu và điều chỉnh nếu cần:
```bash
cp .env.example .env
```

### 4.2. Sinh chứng chỉ SSL/TLS tự ký (Self-signed Certificate)
Chứng chỉ SSL/TLS tự ký được tạo tự động thông qua script `nginx/gen-cert.sh` bên trong môi trường WSL2 (hoặc Linux):
```bash
# Cú pháp cơ bản (SAN mặc định gồm DNS:localhost, IP:127.0.0.1):
./nginx/gen-cert.sh

# Hoặc truyền thêm địa chỉ IP LAN của máy nếu cần truy cập từ mạng nội bộ:
./nginx/gen-cert.sh 192.168.1.50
```
> **Lưu ý bảo mật**: Khóa bí mật (`server.key`) và chứng chỉ (`server.crt`) được lưu trong thư mục `nginx/certs/` và đã được cấu hình trong `.gitignore`, tuyệt đối không commit lên Git repository.

### 4.3. Khởi chạy các dịch vụ với Docker Compose
```bash
# Khởi chạy hệ thống ở chế độ nền
docker compose up -d --build

# Kiểm tra trạng thái hoạt động của các containers
docker compose ps
```

---

## 5. Địa chỉ truy cập & Hướng dẫn xử lý cảnh báo trình duyệt

### 5.1. Địa chỉ truy cập
- **Hệ thống Quản lý Đội xe**: [https://localhost](https://localhost)
- **Trang Quản trị CSDL pgAdmin 4**: [https://localhost/pgadmin/](https://localhost/pgadmin/)
- **Cổng HTTP thông thường (80)**: [http://localhost](http://localhost) (tự động chuyển hướng 301 sang HTTPS).

### 5.2. Cảnh báo chứng chỉ tự ký trên trình duyệt
Do sử dụng chứng chỉ SSL tự ký phục vụ môi trường phát triển và thực nghiệm môn học:
- Trình duyệt (Chrome/Edge/Firefox) sẽ hiển thị thông báo cảnh báo bảo mật: *"Kết nối của bạn không phải là kết nối riêng tư"* hoặc *"Your connection is not private"*.
- **Cách xử lý**: Nhấp vào nút **Nâng cao (Advanced)** $\rightarrow$ chọn **Tiếp tục truy cập localhost (không an toàn) / Proceed to localhost (unsafe)**.
- **Quy tắc an toàn**: **Tuyệt đối KHÔNG tự ý cài đặt chứng chỉ tự ký này vào kho chứng chỉ tin cậy của hệ điều hành Windows (Trusted Root Certification Authorities) khi chưa có sự đồng ý của quản trị viên**.

---

## 6. Tài khoản kiểm thử mặc định
| Vai trò | Tên đăng nhập | Mật khẩu mặc định | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Quản trị viên (Admin)** | `admin` | `FleetAdmin@2026!` | Toàn quyền quản trị, thêm xe, xem KPI |
| **Điều phối viên (Dispatcher)** | `dieuphoi01` | `FleetDisp@2026!` | Điều xe, tạo chuyến, theo dõi hạn đăng kiểm |
| **Điều phối viên (Dispatcher)** | `dieuphoi02` | `FleetDisp@2026!` | Điều phối viên khu vực phía Nam |
| **Tài xế (Driver)** | `taixe01` | `FleetDriver@2026!` | Bằng lái sắp hết hạn (20 ngày), nhận chuyến |
| **Tài xế (Driver)** | `taixe02` | `FleetDriver@2026!` | Đang thực hiện chuyến xe |
| **pgAdmin 4** | `admin@fleet.local` | Thiết lập trong `.env` | Quản trị CSDL qua giao diện web |
