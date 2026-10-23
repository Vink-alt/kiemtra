# TÀI LIỆU TỔNG HỢP PHỤC VỤ VIẾT BÁO CÁO HỌC PHẦN DEVOPS

- **Tên đề tài**: Triển khai, Vận hành và Bảo mật Hệ thống Quản lý Đội xe (Fleet Management System)
- **Sinh viên thực hiện**: Nguyễn Quang Vinh
- **Mã số sinh viên (MSSV)**: DTC245180115
- **Tên Repository Git**: DTC245180115-fleet-devops

---

## BẢNG 1: TỔNG HỢP SỐ LIỆU VÀ PHIÊN BẢN THỰC TẾ HỆ THỐNG

### 1.1. Bảng thành phần và phiên bản phần mềm thực tế
*(Trích xuất trực tiếp từ tệp `docker-compose.yml` và môi trường thực tế đang vận hành)*

| STT | Dịch vụ (Service) | Tên Container thực tế | Image Docker & Phiên bản | Người dùng thực thi (UID) | Cổng mạng (Network) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **Database** | `fleet_db` | `postgres:16.3-alpine3.20` | `postgres` (UID 999) | `backend` (internal: true) |
| 2 | **Web Application** | `fleet_web` | Local build (`Node.js 20-alpine`) | `node` (UID 1000) | `frontend`, `backend` |
| 3 | **Reverse Proxy** | `fleet_nginx` | `nginxinc/nginx-unprivileged:1.27-alpine` | `nginx` (UID 101) | `frontend`, `monitoring` (80/443) |
| 4 | **DB Admin** | `fleet_pgadmin` | `dpage/pgadmin4:8.8` | `pgadmin` (UID 5050) | `frontend`, `backend` |
| 5 | **Metrics Engine** | `fleet_prometheus` | `prom/prometheus:v2.53.0` | `nobody` (UID 65534) | `monitoring` |
| 6 | **Dashboard & Alert** | `fleet_grafana` | `grafana/grafana:11.0.0` | `grafana` (UID 472) | `frontend`, `monitoring` |
| 7 | **Container Monitor**| `fleet_cadvisor` | `gcr.io/cadvisor/cadvisor:v0.49.1` | Root có kiểm soát | `monitoring` |
| 8 | **Postgres Exporter** | `fleet_postgres_exporter`| `prometheuscommunity/postgres-exporter:v0.15.0` | `nobody` (UID 65534) | `backend`, `monitoring` |
| 9 | **Nginx Exporter** | `fleet_nginx_exporter` | `nginx/nginx-prometheus-exporter:1.2.0` | Non-root | `monitoring` |
| 10 | **Log Engine** | `fleet_loki` | `grafana/loki:3.0.0` | `loki` (UID 10001) | `monitoring` |
| 11 | **Log Collector** | `fleet_promtail` | `grafana/promtail:3.0.0` | Root đọc Docker logs | `monitoring` |
| 12 | **Alert Webhook** | `fleet_alert_sink` | Local build (`python:3.11-alpine`) | `nobody` (UID 65534) | `monitoring` |

### 1.2. Số liệu thống kê Git Repository
*(Số liệu chính xác lấy từ `git log` và `git diff-tree`)*
- **Tổng số Commit**: Đúng 3 commit (tuân thủ nghiêm ngặt yêu cầu bài thi).
  1. **Commit 1 (`70ca484`)**: `feat: Khởi tạo ứng dụng web quản lý đội xe, CSDL PostgreSQL và Nginx Reverse Proxy với HTTPS` (Tổng số: **58 tệp**).
  2. **Commit 2 (`b0bb55d`)**: `feat: Tích hợp hệ thống giám sát Prometheus và Grafana cùng các Exporter` (Tổng số: **13 tệp** thay đổi/thêm mới).
  3. **Commit 3 (`51845ab`)**: `feat: Thêm log tập trung Loki/Promtail và áp dụng các biện pháp hardening bảo mật` (Tổng số: **19 tệp** thay đổi/thêm mới).
- **Tổng số container vận hành**: 12/12 container hoạt động đồng thời, đạt trạng thái Healthy.
- **Tổng số file bằng chứng (Evidence)**: 9 tệp lưu tại thư mục `evidence/`.

---

## CHƯƠNG 1: TỔNG QUAN BÀI TOÁN VÀ KIẾN TRÚC HỆ THỐNG

### (a) Đoạn mô tả bằng văn phong báo cáo
Dự án đã nghiên cứu và triển khai hoàn chỉnh giải pháp DevOps toàn diện cho bài toán Quản lý Đội xe thương mại. Hệ thống giải quyết các thách thức vận hành cốt lõi: tối ưu hóa luồng điều phối phương tiện, chống tình trạng tranh chấp tài nguyên (Race Condition) khi phân công tài xế, quản lý minh bạch định mức tiêu hao nhiên liệu và chi phí bảo trì. Về mặt kiến trúc kỹ thuật, toàn bộ hệ thống được container hóa theo mô hình microservices bằng Docker Compose, áp dụng mô hình phân tách mạng đa tầng (3-tier network architecture) gồm mạng ngoại vi Frontend, mạng nội bộ Backend cô lập hoàn toàn (`internal: true`) và mạng giám sát Monitoring chuyên biệt. Tất cả dịch vụ giao tiếp với người dùng cuối đều đi qua Reverse Proxy Nginx với mã hóa bắt buộc TLSv1.2/TLSv1.3, đảm bảo tính sẵn sàng, khả năng mở rộng và mức độ bảo mật cao.

### (b) Đường dẫn file cấu hình đáng đưa vào báo cáo
- `docker-compose.yml`: Cấu hình tổng thể 12 services, phân chia networks, volume persistent và trần tài nguyên (deploy.resources.limits).
- `README.md`: Hướng dẫn vận hành chuẩn hóa và tài liệu bàn giao hệ thống.

### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc0-moitruong.txt`: Bằng chứng chuẩn bị môi trường Docker, Git, OS WSL 2 Ubuntu 22.04.

### (d) Danh sách ảnh cần chụp kèm lệnh
1. **Ảnh 1 - Trạng thái 12 containers đang chạy lành mạnh**:
   - *Lệnh thực hiện*: `docker compose ps`
   - *Mục đích*: Minh chứng 12/12 containers đều đang ở trạng thái `Up` và `healthy`.
2. **Ảnh 2 - Sơ đồ kiến trúc tổng thể hệ thống**:
   - *Hình vẽ*: Sơ đồ Mermaid kết xuất từ mục 2 của `README.md`.

---

## CHƯƠNG 2: ỨNG DỤNG WEB QUẢN LÝ ĐỘI XE VÀ CƠ SỞ DỮ LIỆU POSTGRESQL

### (a) Đoạn mô tả bằng văn phong báo cáo
Ứng dụng Web Quản lý Đội xe được xây dựng bằng công nghệ Node.js (Express framework) kết hợp kiến trúc hiển thị phía máy chủ (SSR với EJS engine) và Vanilla CSS hiện đại, trực quan. Hệ thống cài đặt đầy đủ cơ chế phân quyền RBAC (Role-Based Access Control) cho 3 nhóm vai trò: Quản trị viên (Admin), Điều phối viên (Dispatcher) và Tài xế (Driver). Cơ sở dữ liệu quan hệ PostgreSQL 16 được chuẩn hóa với 7 bảng lưu trữ (`users`, `drivers`, `vehicle_types`, `vehicles`, `trips`, `fuel_logs`, `maintenance_records`), đảm bảo tính toàn vẹn dữ liệu qua khóa ngoại và các chỉ mục (indexes) tối ưu hóa truy vấn. Đặc biệt, để xử lý triệt để nguy cơ Race Condition khi nhiều điều phối viên cùng gán một phương tiện, hệ thống áp dụng kỹ thuật khóa bi quan `SELECT ... FOR UPDATE` bên trong giao dịch (Database Transaction), đảm bảo chỉ một chuyến xe được tạo thành công tại một thời điểm. Ngoài ra, chức năng in lệnh điều xe tự động tạo mã QR Code động nhúng trực tiếp chuỗi Base64 vào HTML, và chức năng tải ảnh xe sử dụng `multer` với kiểm tra chặt chẽ định dạng MIME và kích thước tệp.

### (b) Đường dẫn file cấu hình đáng đưa vào báo cáo
- `web/Dockerfile`: Quy trình build image đa tầng, tạo user không đặc quyền `node` (UID 1000).
- `db/init.sql`: Kịch bản DDL khởi tạo cấu trúc CSDL 7 bảng, sequences, chỉ mục và dữ liệu mẫu (seed data) với mật khẩu băm bcrypt.
- `web/src/controllers/tripController.js`: Xử lý giao dịch khóa bi quan `SELECT ... FOR UPDATE` và tạo mã QR Code động.
- `web/src/controllers/adminController.js`: Xử lý tải ảnh phương tiện và phân quyền quản trị.

### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc12-web-db.txt`: Bằng chứng kiểm thử giao dịch CSDL, CRUD nghiệp vụ, chống Race Condition và nạp seed data.

### (d) Danh sách ảnh cần chụp kèm lệnh
1. **Ảnh 3 - Giao diện danh sách phương tiện**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/vehicles` (đăng nhập Admin).
2. **Ảnh 4 - Giao diện điều phối và quản lý chuyến xe**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/trips` (đăng nhập Dispatcher).
3. **Ảnh 5 - Phiếu lệnh điều xe kèm mã QR Code tạo động**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/trips/1/print`.
4. **Ảnh 6 - Giao diện quản trị pgAdmin 4**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/pgadmin/`, đăng nhập và mở cấu trúc bảng `vehicles`.

---

## CHƯƠNG 3: CẤU HÌNH NGINX REVERSE PROXY VÀ BẢO MẬT HTTPS

### (a) Đoạn mô tả bằng văn phong báo cáo
Toàn bộ lưu lượng truy cập từ người dùng bên ngoài được tiếp nhận và xử lý tập trung qua Nginx Reverse Proxy. Hệ thống đã triển khai image tối ưu bảo mật `nginxinc/nginx-unprivileged:1.27-alpine` thực thi dưới người dùng không đặc quyền (UID 101), lắng nghe trên cổng 8080 và 8443 (được map ra cổng chuẩn 80 và 443 trên host). Cấu hình Nginx thực hiện cưỡng chế chuyển hướng (HTTP 301 Redirect) toàn bộ lưu lượng HTTP sang giao thức bảo mật HTTPS với TLSv1.2/TLSv1.3 và bộ mã hóa an toàn (Cipher Suites ECDHE-ECDSA-AES128-GCM-SHA256,...). Hệ thống thiết lập đầy đủ các HTTP Security Headers theo khuyến cáo của tổ chức OWASP: HSTS (thời hạn 1 năm), CSP, X-Frame-Options (SAMEORIGIN), X-Content-Type-Options (nosniff) và ẩn hoàn toàn phiên bản phần mềm (`server_tokens off`). Chứng chỉ SSL/TLS được sinh tự động thông qua tập lệnh Bash sử dụng OpenSSL x509 hỗ trợ trường Subject Alternative Name (SAN) cho cả `localhost` và `127.0.0.1`.

### (b) Đường dẫn file cấu hình đáng đưa vào báo cáo
- `nginx/nginx.conf`: Tệp cấu hình Nginx chính với SSL/TLS, upstreams, security headers, rate limiting và location reverse proxy cho `/`, `/pgadmin/`, `/grafana/`.
- `nginx/gen-cert.sh`: Tập lệnh sinh chứng chỉ x509 tự ký với SAN và cấp quyền đọc an toàn (644 cho file key).

### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc3-nginx.txt`: Bằng chứng kiểm thử TLS 1.3, chuyển hướng HTTP 301 sang HTTPS, phân giải tên miền SAN và kiểm tra đầy đủ Security Headers bằng `curl -I`.

### (d) Danh sách ảnh cần chụp kèm lệnh
1. **Ảnh 7 - Thông tin chứng chỉ SSL/TLS trên trình duyệt**:
   - *Thao tác*: Bấm vào biểu tượng ổ khóa HTTPS trên thanh địa chỉ của trình duyệt, chụp bảng thông tin chi tiết chứng chỉ `Fleet DevOps` với SAN `localhost`.
2. **Ảnh 8 - Kết quả kiểm tra Security Headers qua cURL**:
   - *Lệnh thực hiện*: `curl -k -I https://localhost/`

---

## CHƯƠNG 4: HỆ THỐNG GIÁM SÁT PROMETHEUS, GRAFANA VÀ CÁC EXPORTER

### (a) Đoạn mô tả bằng văn phong báo cáo
Giải pháp giám sát hiệu năng được xây dựng trên bộ công cụ mã nguồn mở tiêu chuẩn công nghiệp gồm Prometheus và Grafana. Hệ thống tích hợp 3 Exporter chuyên biệt: `cadvisor` giám sát tài nguyên phần cứng (CPU, Memory, Network I/O, Disk I/O) của từng container; `postgres-exporter` thu thập các chỉ số hoạt động CSDL (tần suất giao dịch, cache hit ratio, kết nối tích cực, kích thước CSDL) thông qua tài khoản có quyền tối thiểu `pg_monitor`; và `nginx-prometheus-exporter` thu thập các chỉ số kết nối đồng thời và thông lượng yêu cầu từ Nginx Stub Status. Toàn bộ cấu hình nguồn dữ liệu (Datasources) và 3 Dashboard chuyên sâu được nạp tự động vào Grafana thông qua cơ chế Provisioning, giúp hệ thống sẵn sàng hoạt động ngay sau khi khởi chạy mà không cần cấu hình thủ công.

### (b) Đường dẫn file cấu hình đáng đưa vào báo cáo
- `prometheus/prometheus.yml`: Cấu hình scrape targets cho cAdvisor, PostgreSQL Exporter và Nginx Exporter với chu kỳ 10s.
- `grafana/provisioning/datasources/datasources.yml`: Khai báo tự động 2 datasources Prometheus và Loki.
- `grafana/provisioning/dashboards/dashboards.yml`: Cấu hình tự động nạp các tệp JSON Dashboard.
- `grafana/dashboards/fleet-containers.json`: Dashboard giám sát tài nguyên phần cứng container.
- `grafana/dashboards/fleet-postgres.json`: Dashboard giám sát CSDL PostgreSQL.
- `grafana/dashboards/fleet-nginx.json`: Dashboard giám sát Reverse Proxy Nginx.

### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc4-giamsat.txt`: Bằng chứng kiểm tra targets của Prometheus, API datasources và dashboards trong Grafana.

### (d) Danh sách ảnh cần chụp kèm lệnh
1. **Ảnh 9 - Dashboard Grafana: Fleet - Containers**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/grafana/d/fleet-containers/fleet-containers`.
2. **Ảnh 10 - Dashboard Grafana: Fleet - PostgreSQL**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/grafana/d/fleet-postgres/fleet-postgres`.
3. **Ảnh 11 - Dashboard Grafana: Fleet - Nginx**:
   - *Thao tác*: Mở trình duyệt vào `https://localhost/grafana/d/fleet-nginx/fleet-nginx`.

---

## CHƯƠNG 5: QUẢN LÝ LOG TẬP TRUNG LOKI/PROMTAIL VÀ CẢNH BÁO BẢO MẬT

### (a) Đoạn mô tả bằng văn phong báo cáo
Nhật ký vận hành toàn hệ thống được thu thập và quản lý tập trung bằng bộ đôi Grafana Loki và Promtail. Promtail đọc trực tiếp luồng log Docker container từ `/var/lib/docker/containers/`, phân tích cú pháp, trích xuất các trường nhãn động (`container_name`, `job`, `service`) và chuyển tiếp tới Loki. Ứng dụng web được cấu hình ghi log theo định dạng chuẩn hóa: `LOGIN_FAILED`, `LOGIN_SUCCESS`, `TRIP_STATUS_CHANGE`. Dựa trên nguồn log này, một Alert Rule được thiết lập trong Grafana Alerting: khi số lượng log `LOGIN_FAILED` vượt quá 5 lần trong 1 phút (`count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]) > 5`), hệ thống lập tức kích hoạt cảnh báo mức độ **Critical** và tự động gửi thông báo qua Webhook tới dịch vụ tiếp nhận sự cố `alert-sink`.

### (b) Đường dẫn file cấu hình đáng đưa vào báo cáo
- `loki/loki-config.yml`: Cấu hình lưu trữ và chỉ mục thời gian thực cho Loki.
- `promtail/promtail-config.yml`: Cấu hình pipeline thu thập log container và gán nhãn động.
- `grafana/provisioning/alerting/alert_rules.yml`: Quy tắc cảnh báo phát hiện tấn công Brute Force bằng LogQL.
- `grafana/provisioning/alerting/alert_contact_points.yml`: Điểm tiếp nhận cảnh báo Webhook `http://alert-sink:9099/webhook`.
- `alert-sink/server.py`: Dịch vụ máy chủ Python siêu nhẹ ghi nhận và hiển thị các payload cảnh báo an ninh.

### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc5-logql.txt`: Bằng chứng thực thi các câu truy vấn LogQL đa dạng trên Loki.
- `evidence/buoc5-sucodo.txt`: Bằng chứng kích hoạt tấn công Brute force, chuyển trạng thái Alert sang Firing và phản hồi Webhook.

### (d) Danh sách ảnh cần chụp kèm lệnh
1. **Ảnh 12 - Giao diện Grafana Explore truy vấn LogQL**:
   - *Thao tác*: Vào `https://localhost/grafana/explore`, chọn Loki, nhập `{job="webapp"}` và hiển thị log dòng đời sự kiện.
2. **Ảnh 13 - Giao diện Grafana Alerting trạng thái Firing**:
   - *Thao tác*: Chạy `bash scripts/simulate_bruteforce.sh`, sau đó mở trang `https://localhost/grafana/alerting/list` để chụp cảnh báo Brute Force chuyển màu đỏ (Firing).
3. **Ảnh 14 - Lịch sử Webhook tiếp nhận cảnh báo tại Alert-Sink**:
   - *Lệnh thực hiện*: `docker exec fleet_prometheus wget -qO- http://alert-sink:9099/alerts`

---

## CHƯƠNG 6: TỐI ƯU AN TOÀN VÀ BẢO MẬT HỆ THỐNG (HARDENING & VULNERABILITY SCANNING)

### (a) Đoạn mô tả bằng văn phong báo cáo
Để chuyển đổi hệ thống từ trạng thái phát triển sang môi trường vận hành tin cậy, một chuỗi biện pháp Hardening sâu rộng đã được áp dụng:
1. **Chạy không đặc quyền (Non-root Containers)**: Chuyển toàn bộ 6 dịch vụ quan trọng (Web, Nginx, PostgreSQL, Grafana, Loki, Exporters) sang UID người dùng thường.
2. **Nguyên tắc quyền hạn tối thiểu CSDL (Least Privilege)**: Tách biệt hoàn toàn tài khoản bảo trì `fleet_admin` và tài khoản ứng dụng `fleet_app`. `fleet_app` chỉ sở hữu quyền DML, bị vô hiệu hóa hoàn toàn quyền DDL (`DROP TABLE`, `ALTER TABLE`), giảm thiểu triệt để nguy cơ phá hoại dữ liệu qua SQL Injection.
3. **Phân tách mạng nội bộ**: CSDL được cô lập trong mạng `backend (internal: true)` không có kết nối internet và không mở port ra host.
4. **Thu hồi Linux Capabilities & Chống leo thang đặc quyền**: Cấu hình `cap_drop: [ALL]` và `security_opt: [no-new-privileges:true]`.
5. **Hệ thống tệp chỉ đọc**: Nginx và Alert-Sink áp dụng `read_only: true` kết hợp vùng nhớ tạm `tmpfs: [/tmp]`.
6. **Rate Limiting Nginx**: Bảo vệ endpoint nhạy cảm `/login` với hạn mức 5 req/phút, trả về HTTP 429 khi bị tấn công quét brute-force.
7. **Rà quét lỗ hổng an ninh Trivy**: Đã quét toàn diện 6 image, phát hiện các lỗ hổng hệ điều hành thư viện và lập bảng phân loại rủi ro chi tiết trong báo cáo kiểm toán an ninh.

### (b) Đường dẫn file cấu hình đáng đưa vào báo cáo
- `docker-compose.yml`: Cấu hình hardening toàn diện (user, security_opt, cap_drop, cap_add, read_only, tmpfs, limits).
- `nginx/nginx.conf`: Cấu hình `limit_req_zone` và `limit_req` chống brute-force, bảo vệ `/nginx_status`.
- `db/init.sql`: Phân quyền `GRANT SELECT, INSERT, UPDATE, DELETE` cho role `fleet_app`.

### (c) Tên file bằng chứng (Evidence)
- `evidence/buoc6-hardening.txt`: Bằng chứng kiểm tra Least privilege DB, Non-root UID, cấm DROP TABLE và Rate limiting 429.
- `evidence/buoc6-trivy.txt`: Báo cáo chi tiết kết quả quét an ninh lỗ hổng bảo mật của Trivy Scanner.
- `evidence/final-smoke-test.txt`: Bằng chứng kiểm thử tự động 18/18 tiêu chí thành công từ trạng thái sạch.

### (d) Danh sách ảnh cần chụp kèm lệnh
1. **Ảnh 15 - Kiểm tra Least Privilege CSDL (Từ chối DROP TABLE)**:
   - *Lệnh thực hiện*: `docker exec fleet_db psql -U fleet_app -d fleetdb -c "DROP TABLE vehicles;"`
2. **Ảnh 16 - Kiểm tra người dùng Non-root của các container**:
   - *Lệnh thực hiện*: `docker exec fleet_web id && docker exec fleet_nginx id`
3. **Ảnh 17 - Phản hồi HTTP 429 Too Many Requests từ Nginx**:
   - *Lệnh thực hiện*: Gửi curl liên tiếp vào `/login` để nhận phản hồi mã `429`.
4. **Ảnh 18 - Bảng tổng hợp quét an ninh container bằng Trivy**:
   - *Lệnh thực hiện*: `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.50.1 image fleet-web`

---

## KẾT LUẬN VÀ ĐÁNH GIÁ TỔNG THỂ

### 1. Đánh giá mức độ hoàn thành so với yêu cầu
- **Toàn bộ 18/18 tiêu chí smoke test** từ trạng thái sạch đều đạt kết quả PASS (100%).
- Hệ thống đáp ứng xuất sắc mọi yêu cầu nghiệp vụ quản lý đội xe, kiến trúc Docker Compose chuẩn mực, giám sát thời gian thực, quản lý log tập trung và áp dụng các giải pháp Hardening bảo mật vững chắc.

### 2. Các điểm hạn chế và Hướng phát triển tiếp theo
- **Chứng chỉ TLS**: Hiện sử dụng chứng chỉ tự ký (Self-signed) cho môi trường nội bộ. Trong môi trường Production thực tế cần tích hợp Let's Encrypt / Certbot để tự động gia hạn chứng chỉ công khai.
- **Phân cụm CSDL**: Hệ thống hiện chạy trên 1 node PostgreSQL duy nhất. Có thể mở rộng mô hình PostgreSQL High Availability (Master - Replica với Patroni/pgBouncer).