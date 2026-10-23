#!/usr/bin/env bash
set -euo pipefail

# Script sinh chứng chỉ SSL/TLS tự ký phục vụ Nginx Reverse Proxy
# Chạy trong môi trường WSL2 (distro Ubuntu-22.04)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
mkdir -p "${CERTS_DIR}"

LAN_IP="${1:-}"

# Subject Alternative Name (SAN) bắt buộc gồm DNS:localhost và IP:127.0.0.1
SAN="DNS:localhost,IP:127.0.0.1"

if [[ -n "${LAN_IP}" ]]; then
  SAN="${SAN},IP:${LAN_IP}"
  echo "[gen-cert] Bổ sung IP LAN vào SAN: ${LAN_IP}"
fi

echo "[gen-cert] Bắt đầu khởi tạo chứng chỉ tự ký (RSA 2048-bit, hạn dùng 365 ngày)..."
echo "[gen-cert] Cấu hình SAN: ${SAN}"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERTS_DIR}/server.key" \
  -out "${CERTS_DIR}/server.crt" \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Fleet DevOps/OU=IT/CN=localhost" \
  -addext "subjectAltName = ${SAN}"

chmod 600 "${CERTS_DIR}/server.key"
chmod 644 "${CERTS_DIR}/server.crt"

echo "[gen-cert] Khởi tạo chứng chỉ thành công!"
echo "  - Private Key : ${CERTS_DIR}/server.key"
echo "  - Certificate : ${CERTS_DIR}/server.crt"
echo "[gen-cert] Thông tin chứng chỉ đã tạo:"
openssl x509 -in "${CERTS_DIR}/server.crt" -noout -subject -dates -ext subjectAltName
