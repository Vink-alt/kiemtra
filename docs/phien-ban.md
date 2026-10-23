# Bảng Quản lý Thành phần và Phiên bản Docker Image

| Thành phần | Tên Image (Cố định tag) | Phiên bản / Digest | Mục đích sử dụng | Trạng thái kiểm chứng |
| :--- | :--- | :--- | :--- | :--- |
| **Nginx Reverse Proxy** | `nginx:1.27.0-alpine` | `sha256:208b70eefac13ee9be00e486f79c695b15cef861c680527171a27d253d834be9` | Reverse Proxy HTTPS, TLS termination, Security Headers | Đã pull và chạy healthy |
| **PostgreSQL Database** | `postgres:16.3-alpine3.20` | PostgreSQL 16.3 (Alpine 3.20) | Cơ sở dữ liệu chính (fleetdb) | Đã pull và chạy healthy |
| **Web Runtime Base** | `node:20-alpine` (v20.14.0+) | Node.js LTS v20 (Alpine) | Môi trường ứng dụng Express/EJS | Đã build và chạy healthy |
| **pgAdmin 4** | `dpage/pgadmin4:8.8` | pgAdmin 4 v8.8 | Quản trị CSDL qua giao diện web | Đã pull và phản hồi HTTP 200 |
| **Prometheus Server** | `prom/prometheus:v2.53.0` | `sha256:075b1ba2c4ebb04bc3a6ab86c06ec8d8099f8fda1c96ef6d104d9bb1def1d8bc` | Thu thập, lưu trữ time-series metrics (7d retention) | Đã pull và chạy healthy |
| **Grafana Dashboard** | `grafana/grafana:11.0.0` | `sha256:0dc5a246ab16bb2c38a349fb588174e832b4c6c2db0981d0c3e6cd774ba66a54` | Trực quan hóa bảng điều khiển giám sát qua HTTPS | Đã pull và chạy healthy |
| **cAdvisor Container Monitor** | `gcr.io/cadvisor/cadvisor:v0.49.1` | `sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388` | Giám sát tài nguyên phần cứng container (CPU, RAM, Net) | Đã pull và chạy healthy |
| **Nginx Prometheus Exporter** | `nginx/nginx-prometheus-exporter:1.2.0` | `sha256:e42144361f6f4750380165f91a7be7f04ac705d4c201f3b023a68b8cf1f4be79` | Thu thập metrics từ Nginx stub_status | Đã pull và phản hồi metrics |
| **PostgreSQL Exporter** | `prometheuscommunity/postgres-exporter:v0.15.0` | `sha256:386b12d19eab2a37d7cd8ca8b4c7491cc7a830d9581f49af6c98a393da9605e6` | Thu thập metrics hiệu năng từ PostgreSQL qua pg_monitor | Đã pull và phản hồi metrics |

*(Bảng này sẽ tiếp tục được cập nhật ở Bước 5 & 6 tích hợp Loki, Promtail, cAdvisor hardening và công cụ quét bảo mật Trivy).*
