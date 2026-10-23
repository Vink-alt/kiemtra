#!/usr/bin/env bash
set -uo pipefail

EVIDENCE_FILE="/home/lucka/fleet/evidence/buoc3-nginx.txt"
mkdir -p /home/lucka/fleet/evidence

echo "================================================================================" > "$EVIDENCE_FILE"
echo "EVIDENCE - BUOC 3: NGINX REVERSE PROXY + HTTPS TU KY + SECURITY HEADERS" >> "$EVIDENCE_FILE"
echo "Thoi diem kiem tra: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$EVIDENCE_FILE"
echo "Sinh vien: Nguyen Quang Vinh - MSSV: DTC245180115" >> "$EVIDENCE_FILE"
echo "Repo: DTC245180115-fleet-devops" >> "$EVIDENCE_FILE"
echo "================================================================================" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

log_ev() {
  echo "$1" | tee -a "$EVIDENCE_FILE"
}

cd /home/lucka/fleet

# 1. TRANG THAI CONTAINERS
log_ev ">>> 1. TRANG THAI CONTAINERS (DOCKER COMPOSE PS):"
docker compose ps | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 2. KIEM TRA CU PHAP NGINX
log_ev ">>> 2. KIEM TRA CU PHAP NGINX (NGINX -T):"
docker compose exec nginx nginx -t 2>&1 | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 3. KIEM TRA CHUNG CHI SSL/TLS TREN CONG 443
log_ev ">>> 3. KIEM TRA CHUNG CHI SSL/TLS TREN CONG 443 (OPENSSL S_CLIENT):"
openssl s_client -connect localhost:443 </dev/null 2>/dev/null | openssl x509 -noout -subject -dates -ext subjectAltName | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 4. KIEM TRA CHUYEN HUONG HTTP (CONG 80 -> 301 HTTPS)
log_ev ">>> 4. KIEM TRA HTTP CONG 80 (CURL -I HTTP://LOCALHOST):"
curl -s -I http://localhost | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 5. KIEM TRA HEADERS VA SECURITY HEADERS TREN HTTPS (CONG 443)
log_ev ">>> 5. KIEM TRA SECURITY HEADERS VA PHAN HOI HTTPS (CURL -KI HTTPS://LOCALHOST):"
curl -k -s -I https://localhost | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 6. KIEM TRA CONG 3000 VA 5050 BI KHOA TREN HOST
log_ev ">>> 6. XAC NHAN CONG 3000 VA 5050 KHONG CON PUBLISH RA NGOAI:"
log_ev "Kiem tra ket noi localhost:3000..."
curl --connect-timeout 2 http://localhost:3000 2>&1 | tee -a "$EVIDENCE_FILE" || true
log_ev "Kiem tra ket noi localhost:5050..."
curl --connect-timeout 2 http://localhost:5050 2>&1 | tee -a "$EVIDENCE_FILE" || true
echo "" >> "$EVIDENCE_FILE"

# 7. KIEM TRA STUB_STATUS CHO EXPORTER NOI BO
log_ev ">>> 7. KIEM TRA ENDPOINT NGINX_STATUS CHO EXPORTER NOI BO:"
curl -s http://127.0.0.1/nginx_status | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 8. KIEM TRA REVERSE PROXY PGADMIN (HTTPS://LOCALHOST/PGADMIN/)
log_ev ">>> 8. KIEM TRA PGADMIN 4 QUA REVERSE PROXY (HTTPS://LOCALHOST/PGADMIN/):"
log_ev "Kiem tra HEAD https://localhost/pgadmin/:"
curl -k -s -I https://localhost/pgadmin/ | tee -a "$EVIDENCE_FILE"
PGA_HTTP_CODE=$(curl -k -s -L -o /dev/null -w "%{http_code}" https://localhost/pgadmin/)
log_ev "Kiem tra theo doi chuyen huong toi trang dang nhap pgAdmin: HTTP Code $PGA_HTTP_CODE (Ky vong: 200)"
echo "" >> "$EVIDENCE_FILE"

# 9. KIEM TRA DANG NHAP HTTPS BANG CURL COOKIE JAR (XAC NHAN COOKIE SECURE & SESSION)
log_ev ">>> 9. KIEM TRA DANG NHAP HTTPS QUA NGINX (COOKIE JAR & SECURE COOKIE):"
COOKIE_JAR="/tmp/fleet_test_cookie.txt"
rm -f "$COOKIE_JAR"

# Lay token CSRF tu trang login
LOGIN_HTML=$(curl -k -s -c "$COOKIE_JAR" https://localhost/login)
CSRF_TOKEN=$(echo "$LOGIN_HTML" | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1 || true)
log_ev "CSRF Token lay duoc: ${CSRF_TOKEN:0:16}..."

# Thuc hien dang nhap bang tai khoan admin
LOGIN_RESP=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST https://localhost/login \
  -d "username=admin&password=FleetAdmin@2026!&_csrf=${CSRF_TOKEN}" -w "%{http_code}" -o /dev/null)
log_ev "HTTP status code sau POST login: ${LOGIN_RESP} (Ky vong: 302)"

# Kiem tra noi dung cookie jar
log_ev "Cookie jar ghi nhan:"
cat "$COOKIE_JAR" | grep -v '^#' | tee -a "$EVIDENCE_FILE"

# Kiem tra truy cap trang chu (goc /) va chuyen huong toi /vehicles
ROOT_RESP=$(curl -k -s -b "$COOKIE_JAR" https://localhost/ -w "%{http_code}" -o /dev/null)
log_ev "HTTP status code khi truy cap https://localhost/ sau dang nhap: ${ROOT_RESP} (Ky vong: 302)"

# Kiem tra truy cap Dashboard /kpi va danh sach /vehicles
KPI_HTML=$(curl -k -s -b "$COOKIE_JAR" https://localhost/kpi)
if echo "$KPI_HTML" | grep -q "Báo cáo KPI & Hiệu suất Đội xe"; then
  log_ev "Truy cap Dashboard KPI (/kpi) qua HTTPS thanh cong (xac thuc phien lam viec dung)!"
else
  log_ev "Loi truy cap Dashboard KPI qua HTTPS!"
fi

VEHICLES_HTML=$(curl -k -s -b "$COOKIE_JAR" https://localhost/vehicles)
if echo "$VEHICLES_HTML" | grep -q "Danh mục Đội xe"; then
  log_ev "Truy cap Danh muc Xe (/vehicles) qua HTTPS thanh cong!"
else
  log_ev "Loi truy cap Danh muc Xe qua HTTPS!"
fi
echo "" >> "$EVIDENCE_FILE"

# 10. KIEM TRA UPLOAD ANH XE QUA HTTPS
log_ev ">>> 10. KIEM TRA TAO XE VA TAI ANH XE LEN QUA HTTPS (MULTIPART FORM):"
CREATE_PAGE=$(curl -k -s -b "$COOKIE_JAR" https://localhost/vehicles/create)
CREATE_CSRF=$(echo "$CREATE_PAGE" | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1 || true)
if [[ -z "$CREATE_CSRF" ]]; then
  CREATE_CSRF="$CSRF_TOKEN"
fi

TEST_PNG="/tmp/https_upload_test.png"
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_PNG"

NEW_PLATE="30H-888.99"
# Xoa neu da ton tai truoc do
docker exec -i fleet_db psql -U fleet_app -d fleetdb -c "DELETE FROM vehicles WHERE plate_number = '$NEW_PLATE';" > /dev/null 2>&1 || true

UPLOAD_RESP=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  "https://localhost/vehicles/create?_csrf=$CREATE_CSRF" \
  -F "_csrf=$CREATE_CSRF" \
  -F "plate_number=$NEW_PLATE" \
  -F "vehicle_type_id=2" \
  -F "make=Ford" \
  -F "model=Everest Titanium" \
  -F "year=2024" \
  -F "fuel_type=diesel" \
  -F "seats=7" \
  -F "odometer_km=5000" \
  -F "status=available" \
  -F "registration_expiry=2027-12-31" \
  -F "insurance_expiry=2027-12-31" \
  -F "next_service_km=15000" \
  -F "image=@$TEST_PNG;type=image/png" \
  -w "%{http_code}" -o /dev/null)
log_ev "HTTP status code sau tao xe kem upload anh qua HTTPS: ${UPLOAD_RESP} (Ky vong: 302)"

CHECK_DB=$(docker exec -i fleet_db psql -U fleet_app -d fleetdb -t -c \
  "SELECT plate_number, make, model, image_path FROM vehicles WHERE plate_number = '$NEW_PLATE';")
log_ev "Kiem tra du lieu xe va duong dan anh luu trong CSDL: $CHECK_DB"
echo "" >> "$EVIDENCE_FILE"

# 11. KIEM TRA PHIEU LENH DIEU XE CO MA QR QUA HTTPS
log_ev ">>> 11. KIEM TRA PHIEU LENH DIEU XE CO MA QR QUA HTTPS (GET /trips/1/print):"
PRINT_HTML=$(curl -k -s -b "$COOKIE_JAR" https://localhost/trips/1/print)
if echo "$PRINT_HTML" | grep -q 'data:image/png;base64'; then
  log_ev "Phieu lenh dieu xe kem ma QR Code hop le da render thanh cong qua HTTPS!"
  QR_SNIPPET=$(echo "$PRINT_HTML" | grep -oP '<img[^>]*data:image/png;base64[^>]*>' | head -n 1)
  log_ev "The ma QR: ${QR_SNIPPET:0:65}...>"
else
  log_ev "Loi: Khong tim thay ma QR tren phieu dieu xe!"
fi
echo "" >> "$EVIDENCE_FILE"

# 12. LOGS NGINX TRUY CAP
log_ev ">>> 12. TRICH XUAT LOGS NGINX DINH DANG KET HOP PHUC VU MONITORING:"
docker compose logs --tail 8 nginx | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

log_ev "=== HOAN TAT TOAN BO KIEM TRA BUOC 3 ==="
