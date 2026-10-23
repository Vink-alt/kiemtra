# Bảng Quản lý Thành phần và Phiên bản Docker Image

| Thành phần | Tên Image (Cố định tag) | Phiên bản / Digest | Mục đích sử dụng | Trạng thái kiểm chứng |
| :--- | :--- | :--- | :--- | :--- |
| **Nginx Reverse Proxy** | `nginx:1.27.0-alpine` | `sha256:208b70eefac13ee9be00e486f79c695b15cef861c680527171a27d253d834be9` | Reverse Proxy HTTPS, TLS termination, Security Headers | Đã pull và chạy healthy |
| **PostgreSQL Database** | `postgres:16.3-alpine3.20` | PostgreSQL 16.3 (Alpine 3.20) | Cơ sở dữ liệu chính (fleetdb) | Đã pull và chạy healthy |
| **Web Runtime Base** | `node:20-alpine` (v20.14.0+) | Node.js LTS v20 (Alpine) | Môi trường ứng dụng Express/EJS | Đã build và chạy healthy |
| **pgAdmin 4** | `dpage/pgadmin4:8.8` | pgAdmin 4 v8.8 | Quản trị CSDL qua giao diện web | Đã pull và phản hồi HTTP 200 |

*(Bảng này sẽ tiếp tục được cập nhật ở các bước tích hợp Prometheus, Grafana, Loki, Promtail, cAdvisor, Exporters).*
