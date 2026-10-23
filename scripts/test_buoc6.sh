#!/usr/bin/env bash
set -uo pipefail

BASE_URL="https://localhost"
EVIDENCE_FILE="/home/lucka/fleet/evidence/buoc6-hardening.txt"
COOKIE_JAR="/tmp/cookie_buoc6.txt"
rm -f "$COOKIE_JAR"

echo "================================================================================" > "$EVIDENCE_FILE"
echo "EVIDENCE - BUOC 6: HARDENING + SECURITY CONTROLS + TRIVY SCAN" >> "$EVIDENCE_FILE"
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

# 2. KIEM TRA NON-ROOT USER CHO TUNG SERVICE
log_ev ">>> 2. KIEM TRA NON-ROOT CONTAINER (ID CUA TUNG SERVICE):"
for s in web prometheus loki alert-sink grafana nginx postgres-exporter pgadmin; do
  c="fleet_${s//-/_}"
  uid_out=$(docker exec "$c" id 2>&1 || echo "failed")
  log_ev "$s ($c): $uid_out"
done
log_ev "nginx-exporter: $(docker inspect fleet_nginx_exporter --format 'uid={{.Config.User}}')"
log_ev "NGOAI LE BAT BUOC ROOT (DA GIAI THICH TRONG README):"
log_ev "cadvisor: $(docker exec fleet_cadvisor id) -> Yeu cau root de doc cgroup va /var/run/docker.sock"
log_ev "promtail: $(docker exec fleet_promtail id) -> Yeu cau root de doc container logs va docker.sock"
log_ev "db (postgres): $(docker exec fleet_db id) -> Khoi dong root de setup file perms sau do drop privileges ve user postgres"
echo "" >> "$EVIDENCE_FILE"

# 3. NETWORK ISOLATION
log_ev ">>> 3. NETWORK ISOLATION (DOCKER NETWORK LS & INSPECT):"
docker network ls | grep fleet | tee -a "$EVIDENCE_FILE"
log_ev "--- Chi tiet fleet_backend (internal: true) ---"
docker network inspect fleet_backend --format 'Name: {{.Name}} | Internal: {{.Internal}} | Containers: {{range $k, $v := .Containers}}{{$v.Name}} {{end}}' | tee -a "$EVIDENCE_FILE"
log_ev "--- Chi tiet fleet_frontend ---"
docker network inspect fleet_frontend --format 'Name: {{.Name}} | Internal: {{.Internal}} | Containers: {{range $k, $v := .Containers}}{{$v.Name}} {{end}}' | tee -a "$EVIDENCE_FILE"
log_ev "--- Chi tiet fleet_monitoring ---"
docker network inspect fleet_monitoring --format 'Name: {{.Name}} | Internal: {{.Internal}} | Containers: {{range $k, $v := .Containers}}{{$v.Name}} {{end}}' | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 4. LEAST PRIVILEGE DATABASE
log_ev ">>> 4. LEAST PRIVILEGE DATABASE (ROLES, TABLE PERMISSIONS & THU DROP TABLE):"
log_ev "--- Danh sach roles (\du) ---"
docker exec fleet_db psql -U fleet_admin -d fleetdb -P pager=off -c '\du' | tee -a "$EVIDENCE_FILE"
log_ev "--- Quyen tren cac bang (\dp) ---"
docker exec fleet_db psql -U fleet_admin -d fleetdb -P pager=off -c '\dp' | tee -a "$EVIDENCE_FILE"
log_ev "--- Thu DROP TABLE vehicles bang user fleet_app (ky vong BI TU CHOI) ---"
DROP_TEST=$(docker exec fleet_db psql -U fleet_app -d fleetdb -c "DROP TABLE vehicles;" 2>&1 || true)
log_ev "Ket qua: $DROP_TEST"
echo "" >> "$EVIDENCE_FILE"

# 5. SECURITY HEADERS VA AN THONG TIN
log_ev ">>> 5. SECURITY HEADERS VA AN THONG TIN (CURL -kI HTTPS://LOCALHOST/):"
curl -k -I -s https://localhost/ | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"
log_ev "--- Kiem tra chan /nginx_status tu ben ngoai qua HTTPS (ky vong 404) ---"
curl -k -I -s https://localhost/nginx_status | grep -E "HTTP/|Server:" | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 6. DOCKER SECURITY OPTS, CAP DROP, READONLY ROOTFS
log_ev ">>> 6. CONTAINER SECURITY CONFIG (CAP DROP, SECURITY_OPT, READONLY):"
for c in fleet_web fleet_nginx fleet_prometheus fleet_loki fleet_alert_sink fleet_postgres_exporter fleet_db; do
  docker inspect "$c" --format 'Service: {{.Name}} | SecurityOpt: {{.HostConfig.SecurityOpt}} | CapDrop: {{.HostConfig.CapDrop}} | ReadonlyRootfs: {{.HostConfig.ReadonlyRootfs}}' | tee -a "$EVIDENCE_FILE"
done
echo "" >> "$EVIDENCE_FILE"

# 7. AUDIT GIT SECRET
log_ev ">>> 7. RÀ SOÁT SECRET TRONG GIT REPO (GIT GREP PASSWORD):"
log_ev "Permissions cua .env: $(ls -l /home/lucka/fleet/.env)"
GIT_SECRET_COUNT=$(git grep -i "password" | grep -v "\.env\.example" | grep -v "README\.md" | grep -v "init\.sql" | grep -v "test_" | grep -v "views" | grep -v "controllers" | grep -v "docker-compose" | wc -l)
log_ev "So luong secret / password bi hardcode trong git (ky vong 0): $GIT_SECRET_COUNT"
echo "" >> "$EVIDENCE_FILE"

# 8. SMOKE TEST TOAN BO CHUC NANG QUA HTTPS
log_ev ">>> 8. SMOKE TEST CHUC NANG HE THONG QUA HTTPS:"
# A. Login
LOGIN_PAGE=$(curl -k -s -c "$COOKIE_JAR" "$BASE_URL/login")
CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1 || true)
LOGIN_RESP=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$BASE_URL/login" \
  -d "username=admin&password=FleetAdmin@2026!&_csrf=${CSRF_TOKEN}" -w "%{http_code}" -o /dev/null)
log_ev "Dang nhap Admin qua HTTPS: HTTP $LOGIN_RESP (Ky vong: 302)"

# B. Vehicles list
VEHICLES_RESP=$(curl -k -s -b "$COOKIE_JAR" "$BASE_URL/vehicles" -w "%{http_code}" -o /dev/null)
log_ev "Xem danh sach xe: HTTP $VEHICLES_RESP (Ky vong: 200)"

# C. Detail
DETAIL_RESP=$(curl -k -s -b "$COOKIE_JAR" "$BASE_URL/vehicles/1" -w "%{http_code}" -o /dev/null)
log_ev "Xem chi tiet xe ID 1: HTTP $DETAIL_RESP (Ky vong: 200)"

# D. Print QR
PRINT_RESP=$(curl -k -s -b "$COOKIE_JAR" "$BASE_URL/trips/1/print")
if echo "$PRINT_RESP" | grep -q 'data:image/png;base64'; then
  log_ev "Phieu lenh dieu xe kem ma QR Code hop le: THANH CONG"
else
  log_ev "Phieu lenh QR Code: THAT BAI"
fi

# E. RBAC
DRIVER_JAR="/tmp/driver_cookie.txt"
rm -f "$DRIVER_JAR"
DL_PAGE=$(curl -k -s -c "$DRIVER_JAR" "$BASE_URL/login")
D_CSRF=$(echo "$DL_PAGE" | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1 || true)
curl -k -s -b "$DRIVER_JAR" -c "$DRIVER_JAR" -X POST "$BASE_URL/login" \
  -d "username=taixe01&password=FleetDriver@2026!&_csrf=${D_CSRF}" -o /dev/null
RBAC_RESP=$(curl -k -s -b "$DRIVER_JAR" "$BASE_URL/admin/users" -w "%{http_code}" -o /dev/null)
log_ev "Kiem tra RBAC (Tai xe truy cap /admin/users): HTTP $RBAC_RESP (Ky vong: 403)"

# F. Monitoring health
log_ev "--- Kiem tra Prometheus Scrapes & Loki ---"
log_ev "Nginx metrics (nginx_up): $(docker exec fleet_prometheus wget -qO- http://nginx-exporter:9113/metrics | grep -E '^nginx_up')"
log_ev "Postgres metrics (pg_up): $(docker exec fleet_prometheus wget -qO- http://postgres-exporter:9187/metrics | grep -E '^pg_up')"
log_ev "Loki ready: $(docker exec fleet_prometheus wget -qO- http://loki:3100/ready)"
log_ev "Alert sink health: $(docker exec fleet_prometheus wget -qO- http://alert-sink:9099/health)"
echo "" >> "$EVIDENCE_FILE"

# 9. KICH BAN BRUTE FORCE RATE LIMITING
log_ev ">>> 9. KIEM TRA KICH BAN RATE LIMITING VA CANH BAO (SIMULATE BRUTE FORCE):"
log_ev "Chay 10 request sai mat khau lien tiep de kiem tra Rate Limiting (HTTP 429)..."
COUNT_429=0
for i in {1..10}; do
  BF_PAGE=$(curl -k -s -c "$COOKIE_JAR" "$BASE_URL/login")
  BF_CSRF=$(echo "$BF_PAGE" | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1 || true)
  CODE=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$BASE_URL/login" \
    -d "username=admin&password=WrongPass_$i&_csrf=$BF_CSRF" -w "%{http_code}" -o /dev/null)
  if [[ "$CODE" == "429" ]]; then
    COUNT_429=$((COUNT_429 + 1))
  fi
done
log_ev "So luong request bi chan boi Rate Limiting (HTTP 429): $COUNT_429 / 10"
log_ev "Nhat ky canh bao moi nhat cua alert-sink:"
docker exec fleet_alert_sink tail -n 5 /app/alerts.log 2>&1 | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

log_ev "=== HOAN TAT TOAN BO KIEM TRA HARDENING BUOC 6 ==="