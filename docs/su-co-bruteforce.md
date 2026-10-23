# Báo Cáo Xử Lý Sự Cố An Toàn Thông Tin: Tấn Công Dò Mật Khẩu (Brute Force) Vào Trang Đăng Nhập

- **Hệ thống:** Hệ thống Quản lý Đội xe (Fleet Management System)
- **Người thực hiện:** Nguyễn Quang Vinh – MSSV: DTC245180115
- **Mức độ nghiêm trọng:** Critical (Đe dọa an toàn tài khoản quản trị viên và dữ liệu điều vận đội xe)
- **Thời điểm diễn ra sự cố:** 2026-10-23 23:58:03 +07 (16:58:03 UTC)
- **Thời điểm kích hoạt cảnh báo:** 2026-10-23 23:58:20 +07 (16:58:20 UTC)
- **Thời điểm hoàn thành truy vết và gia cố:** 2026-10-24 00:10:00 +07

---

## 1. Mô tả sự cố (Incident Description)

Vào lúc **23:58:03 ngày 23/10/2026 (giờ địa phương)**, hệ thống Reverse Proxy Nginx và máy chủ ứng dụng web tiếp nhận chuỗi yêu cầu gửi dồn dập tới endpoint bảo mật HTTPS `https://localhost/login`.

Kẻ tấn công sử dụng công cụ script tự động (`curl/7.81.0`) gửi liên tiếp **20 yêu cầu xác thực POST** nhắm vào tài khoản quản trị viên tối cao `admin` cùng từ điển các mật khẩu phổ biến (`123456`, `password`, `admin123`, `welcome`,...). Kẻ tấn công tự động phân tích trang HTML `/login` để lấy CSRF token hợp lệ trước mỗi lượt thử nhằm vượt qua cơ chế chống CSRF.

Do mỗi lần xác thực mật khẩu sai, ứng dụng Node.js phải truy vấn cơ sở dữ liệu PostgreSQL và thực hiện hàm so sánh băm `bcrypt.compare()` (thuật toán mã hóa tốn nhiều chu kỳ CPU), hành vi tấn công này không chỉ có nguy cơ chiếm đoạt tài khoản quản trị mà còn gây suy giảm nghiêm trọng hiệu năng hệ thống.

---

## 2. Phát hiện sự cố qua hệ thống cảnh báo (Detection & Alerting)

### 2.1 Cấu hình giám sát và quy tắc cảnh báo (Grafana Alerting Rule)
Hệ thống triển khai cụm log tập trung **Loki 3.0** và **Promtail 3.0** để thu thập log từ tất cả các container. Trên Grafana 11, một Alert Rule được cấu hình sẵn thông qua cơ chế Provisioning (`grafana/provisioning/alerting/rules.yaml`):

- **Tên cảnh báo:** `Fleet - Brute force login`
- **Thư mục quản lý:** `Fleet Monitoring`
- **Mục tiêu giám sát:** Đếm số lần đăng nhập thất bại trong ứng dụng web (`LOGIN_FAILED`)
- **Biểu thức truy vấn LogQL (Query A):**
  ```logql
  sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
  ```
- **Điều kiện kích hoạt (Condition C):** Math expression `$B > 5` (nếu vượt quá 5 lần trong vòng 1 phút).
- **Độ trễ đánh giá (For):** 10 giây.
- **Mức độ (Severity):** `critical`.

### 2.2 Diễn biến kích hoạt cảnh báo
1. **Trước tấn công (23:55:13):** Gọi API Alertmanager Grafana `GET /grafana/api/alertmanager/grafana/api/v2/alerts` trả về danh sách rỗng `[]`, không có cảnh báo nào kích hoạt.
2. **Trong tấn công (23:58:03 - 23:58:16):** 20 yêu cầu đăng nhập sai sinh ra 20 dòng log `LOGIN_FAILED` trong `fleet_web` và lập tức được Promtail thu thập, gắn nhãn `job="webapp"` rồi đẩy vào Loki.
3. **Kích hoạt Firing (23:58:20):** Giá trị đo lường trong cửa sổ 1 phút đạt **20** (vượt ngưỡng 5). Alert rule chuyển trạng thái từ `Normal` sang **Firing** (`state: active`).
4. **Gửi thông báo Contact Point (23:58:25):** Grafana Alertmanager tự động phát webhook `POST /alerts` tới container dịch vụ `alert-sink:9099`.
   Log của `alert-sink`:
   ```text
   [ALERT_RECEIVED] [2026-10-23T16:58:25Z] Status: firing, Total Alerts: 1
   [SECURITY_ALERT] [2026-10-23T16:58:25Z] Alert: 'Fleet - Brute force login' | Severity: critical | Summary: Phat hien tan cong do mat khau (Brute Force) vao ung dung doi xe | Description: Co hon 5 lan dang nhap that bai (LOGIN_FAILED) trong vong 1 phut. Huong dan truy vet: Chay LogQL {job="webapp"} |= "LOGIN_FAILED" de xac dinh IP va tai khoan bi tan cong, sau do kiem tra {job="nginx"} de chan IP.
   ```
   Do `alert-sink` ghi log ra stdout, bản thân sự kiện cảnh báo này cũng được Promtail thu thập ngược lại vào Loki (`job="alert-sink"`), đảm bảo tính toàn vẹn và khép kín của chuỗi kiểm toán an toàn thông tin.

---

## 3. Điều tra và truy vết sự cố bằng LogQL (Forensics Investigation)

Sau khi nhận được cảnh báo, kỹ sư an toàn thông tin tiến hành điều tra truy vết thông qua giao diện Grafana Explore hoặc Loki API:

### 3.1 Xác định IP nguồn và tài khoản mục tiêu
Chạy truy vấn LogQL:
```logql
{job="webapp"} |= "LOGIN_FAILED"
```
**Kết quả thực tế ghi nhận từ Loki:**
```text
[2026-10-23 16:58:16 UTC] LOGIN_FAILED ip=172.23.0.1 user=admin reason=wrong_password
[2026-10-23 16:58:15 UTC] LOGIN_FAILED ip=172.23.0.1 user=admin reason=wrong_password
[2026-10-23 16:58:14 UTC] LOGIN_FAILED ip=172.23.0.1 user=admin reason=wrong_password
...
[2026-10-23 16:58:04 UTC] LOGIN_FAILED ip=172.23.0.1 user=admin reason=wrong_password
```
- **Địa chỉ IP nguồn:** `172.23.0.1` (IP gateway mạng Docker nội bộ kết nối từ WSL2).
- **Tài khoản bị nhắm mục tiêu:** `admin` (tài khoản quản trị hệ thống).
- **Khoảng thời gian:** Bắt đầu lúc `16:58:04 UTC`, kết thúc lúc `16:58:16 UTC` (12 giây).
- **Tổng số lần thử nghiệm:** 20 lần thử sai liên tục.

### 3.2 Đối chiếu với log truy cập Nginx
Chạy truy vấn LogQL trên Nginx access log để phân tích hành vi mạng:
```logql
{job="nginx"} |= "172.23.0.1" |= "POST /login"
```
**Kết quả thực tế:**
```text
172.23.0.1 - - [23/Oct/2026:16:58:04 +0000] "POST /login HTTP/1.1" 302 28 "-" "curl/7.81.0" "-" rt=0.082 uct="0.000" uht="0.082" urt="0.082"
172.23.0.1 - - [23/Oct/2026:16:58:04 +0000] "POST /login HTTP/1.1" 302 28 "-" "curl/7.81.0" "-" rt=0.079 uct="0.000" uht="0.079" urt="0.079"
```
- **User-Agent:** `curl/7.81.0` chứng minh đây là công cụ quét script tự động, không phải người dùng qua trình duyệt thông thường.
- **Thời gian phản hồi:** Khoảng `80ms` cho mỗi request.
- **Mã phản hồi HTTP:** `302 Found` (redirect về `/login` kèm thông báo lỗi).

---

## 4. Biện pháp xử lý và khắc phục (Remediation & Hardening)

### 4.1 Gia cố tức thời: Áp dụng Rate Limiting tại Nginx Reverse Proxy
Để ngăn chặn các cuộc tấn công lặp lại và giảm tải cho backend Node.js, cấu hình giới hạn tốc độ yêu cầu được bổ sung vào `nginx/nginx.conf`:

1. **Khai báo vùng nhớ chia sẻ (Shared Memory Zone):**
   ```nginx
   limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
   limit_req_status 429;
   ```
   - `$binary_remote_addr`: Dùng địa chỉ IP dạng nhị phân (tiết kiệm bộ nhớ, 10MB lưu được ~160.000 IP duy nhất).
   - `rate=5r/m`: Cho phép tối đa 5 yêu cầu mỗi phút cho mỗi IP.
   - `limit_req_status 429`: Thiết lập mã trạng thái chuẩn RFC 6585 `HTTP 429 Too Many Requests` thay cho mã mặc định 503.

2. **Áp dụng riêng cho endpoint đăng nhập (`location = /login`):**
   ```nginx
   location = /login {
       limit_req zone=login_limit burst=5 nodelay;
       proxy_pass http://backend_web;
       ...
   }
   ```
   - `burst=5`: Cho phép một lượng yêu cầu đột biến tối đa 5 request.
   - `nodelay`: Xử lý ngay lập tức các yêu cầu trong ngưỡng burst mà không làm chậm trải nghiệm, nhưng từ chối tức thì (HTTP 429) đối với yêu cầu thứ 6 trở đi.

### 4.2 Kiểm chứng hiệu quả sau khi gia cố
Chạy lại kịch bản mô phỏng tấn công `scripts/simulate_bruteforce.sh`:
- **Yêu cầu 1 và 2:** Nhận `HTTP 302` (xử lý đăng nhập bình thường trong ngưỡng burst).
- **Yêu cầu 3 đến 20:** Bị Nginx chặn đứng và trả về **`HTTP 429 Too Many Requests`** ngay tại tầng reverse proxy.
- **Tỷ lệ ngăn chặn:** Đạt **18/20 yêu cầu (90%)** bị triệt tiêu, không chuyển tiếp vào backend Node.js, bảo vệ CPU và database không bị kiệt quệ tài nguyên.
- **Kiểm chứng người dùng thông thường:** Thử nghiệm đăng nhập tài khoản hợp lệ với nhịp độ thao tác thông thường của con người. Kết quả trả về `HTTP 200` và chuyển hướng thành công vào hệ thống quản lý xe `/vehicles`.

### 4.3 Đề xuất các giải pháp nâng cao cho môi trường Production
1. **Khóa tài khoản tạm thời (Account Lockout Policy):** Khóa tài khoản 15 phút nếu sai mật khẩu quá 5 lần liên tiếp.
2. **Tích hợp Cloudflare Turnstile hoặc reCAPTCHA v3:** Tự động kích hoạt thử thách CAPTCHA khi phát hiện luồng truy cập bất thường.
3. **Cơ chế Fail2ban / Web Application Firewall (WAF):** Tự động thêm IP vi phạm vào quy tắc tường lửa `iptables`/`nftables` tại máy chủ host.
4. **Xác thực hai yếu tố (2FA / TOTP):** Bắt buộc đối với các vai trò quản trị viên (`admin`) và điều phối viên (`dispatcher`).

---

## 5. Bài học kinh nghiệm (Lessons Learned)

1. **Tầm quan trọng của Log tập trung (Centralized Logging):** Việc có Loki và Promtail giúp phát hiện và điều tra sự cố chỉ trong vài chục giây, thay vì phải SSH thủ công vào từng container để rà soát file log phân tán.
2. **Sức mạnh của cảnh báo tự động (Proactive Alerting):** Cảnh báo dựa trên LogQL kết hợp Contact Point webhook giúp đội ngũ vận hành phản ứng kịp thời trước khi kẻ tấn công kịp tìm ra mật khẩu hoặc làm sập dịch vụ.
3. **Phòng thủ theo chiều sâu (Defense-in-Depth):** Việc chặn đứng tấn công tần suất cao ngay tại tầng biên Nginx (Edge/Reverse Proxy) bằng HTTP 429 hiệu quả hơn nhiều so với việc để ứng dụng backend tự xử lý, tiết kiệm năng lực tính toán và bảo vệ cơ sở dữ liệu.
