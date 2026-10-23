cat << 'EOF' > /home/lucka/fleet/README.md
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
- `prometheus`: Hệ thống thu thập và lưu trữ time-series metrics với retention 7 ngày, quản lý các targets qua mạng nội bộ.
- `grafana`: Nền tảng trực quan hóa dữ liệu giám sát với 3 dashboard tự động nạp qua cơ chế Provisioning, phục vụ qua HTTPS tại `/grafana/`.
- `cadvisor`: Giám sát tài nguyên phần cứng cấp container (CPU %, RAM bytes, Network I/O).
- `nginx-exporter`: Thu thập chỉ số hiệu năng và trạng thái kết nối của Nginx Reverse Proxy.
- `postgres-exporter`: Thu thập chỉ số hoạt động, giao dịch, cache hit ratio và kích thước CSDL từ PostgreSQL thông qua role tối thiểu `pg_monitor`.
- *(Các thành phần Loki, Promtail, cAdvisor hardening và kiểm thử bảo mật sẽ được hoàn thiện ở các bước tiếp theo).*

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

### 4.3. Khởi tạo người dùng Exporter cho CSDL đã có dữ liệu
Tệp `db/init.sql` đã tích hợp sẵn lệnh tạo user `exporter` kèm role `pg_monitor`. Trong trường hợp volume cơ sở dữ liệu `db_data` đã tồn tại trước đó, chạy lệnh an toàn sau:
```bash
docker exec -i fleet_db psql -U fleet_app -d fleetdb -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'exporter') THEN
    CREATE ROLE exporter WITH LOGIN PASSWORD 'FleetExporter@2026!';
    GRANT pg_monitor TO exporter;
  END IF;
END
\$\$;"
```

### 4.4. Khởi chạy các dịch vụ với Docker Compose
```bash
# Khởi chạy toàn bộ hệ thống ở chế độ nền
docker compose up -d --build

# Kiểm tra trạng thái hoạt động của các containers
docker compose ps
```

---

## 5. Địa chỉ truy cập & Hướng dẫn xử lý cảnh báo trình duyệt

### 5.1. Địa chỉ truy cập
- **Hệ thống Quản lý Đội xe**: [https://localhost](https://localhost)
- **Trang Quản trị CSDL pgAdmin 4**: [https://localhost/pgadmin/](https://localhost/pgadmin/)
- **Hệ thống Giám sát Grafana**: [https://localhost/grafana/](https://localhost/grafana/)
- **Cổng HTTP thông thường (80)**: [http://localhost](http://localhost) (tự động chuyển hướng 301 sang HTTPS).

### 5.2. Cách xem giao diện Prometheus Targets an toàn (Không publish cổng lâu dài)
Theo kiến trúc bảo mật, Prometheus (cổng 9090) không publish ra máy chủ host. Để mở tạm thời phục vụ kiểm tra hoặc chụp ảnh minh chứng:
1. Tạo tệp `docker-compose.override.yml` (tệp này đã có trong `.gitignore`, không bị commit):
   ```yaml
   services:
     prometheus:
       ports:
         - "127.0.0.1:9090:9090"
   ```
2. Cập nhật dịch vụ Prometheus:
   ```bash
   docker compose up -d prometheus
   ```
3. Mở trình duyệt truy cập: `http://localhost:9090/targets` để xem trạng thái 4 targets (`UP`).
4. Sau khi kiểm tra xong, xóa tệp override và đưa Prometheus trở lại mạng nội bộ an toàn:
   ```bash
   rm -f docker-compose.override.yml
   docker compose up -d
   ```

### 5.3. Xử lý cảnh báo chứng chỉ tự ký trên trình duyệt
Do sử dụng chứng chỉ SSL tự ký phục vụ môi trường phát triển và thực nghiệm môn học:
- Trình duyệt sẽ hiển thị cảnh báo: *"Kết nối của bạn không phải là kết nối riêng tư"* hoặc *"Your connection is not private"*.
- **Cách xử lý**: Nhấp vào nút **Nâng cao (Advanced)** $\rightarrow$ chọn **Tiếp tục truy cập localhost (không an toàn) / Proceed to localhost (unsafe)**.
- **Quy tắc an toàn**: **Tuyệt đối KHÔNG tự ý cài đặt chứng chỉ tự ký này vào kho chứng chỉ tin cậy của Windows (Trusted Root Certification Authorities) khi chưa có sự đồng ý của quản trị viên**.

---

## 6. Danh mục Bảng điều khiển Giám sát (Grafana Dashboards)
Các bảng điều khiển được nạp tự động qua thư mục `Fleet Monitoring`:
1. **Fleet - Containers** (`fleet-containers`): Giám sát tỉ lệ sử dụng CPU (%), mức tiêu thụ bộ nhớ RAM và lưu lượng mạng I/O (RX/TX) của toàn bộ các container.
2. **Fleet - Nginx** (`fleet-nginx`): Giám sát số kết nối đang hoạt động (active connections), tốc độ yêu cầu (requests/s), kết nối đã tiếp nhận so với đã xử lý (handled vs accepted), và trạng thái reading/writing/waiting.
3. **Fleet - PostgreSQL** (`fleet-postgres`): Giám sát số kết nối hiện tại (backends), tốc độ giao dịch (commit/rollback / sec), số lượng bản ghi (tuples) duyệt qua và truy xuất, tỉ lệ trúng bộ nhớ đệm (Cache Hit Ratio %) và dung lượng cơ sở dữ liệu `fleetdb`.

---

## 7. Tài khoản kiểm thử mặc định
| Dịch vụ / Vai trò | Tên đăng nhập | Mật khẩu mặc định | Ghi chú |
| :--- | :--- | :--- | :--- |
| **Quản trị viên Ứng dụng (Admin)** | `admin` | `FleetAdmin@2026!` | Toàn quyền quản trị, thêm xe, xem KPI |
| **Điều phối viên (Dispatcher)** | `dieuphoi01` | `FleetDisp@2026!` | Điều xe, tạo chuyến, theo dõi hạn đăng kiểm |
| **Tài xế (Driver)** | `taixe01` | `FleetDriver@2026!` | Bằng lái sắp hết hạn (20 ngày), nhận chuyến |
| **Quản trị CSDL pgAdmin 4** | `admin@fleet.local` | Thiết lập trong `.env` | Quản trị CSDL qua giao diện web |
| **Hệ thống Giám sát Grafana** | `fleetadmin` | Thiết lập trong `.env` | Xem toàn bộ 3 dashboard giám sát |
EOF
