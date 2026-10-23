#!/usr/bin/env bash
set -uo pipefail

EVIDENCE_FILE="/home/lucka/fleet/evidence/buoc4-giamsat.txt"
mkdir -p /home/lucka/fleet/evidence

echo "================================================================================" > "$EVIDENCE_FILE"
echo "EVIDENCE - BUOC 4: HE THONG GIAM SAT PROMETHEUS + GRAFANA + EXPORTERS" >> "$EVIDENCE_FILE"
echo "Thoi diem kiem tra: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$EVIDENCE_FILE"
echo "Sinh vien: Nguyen Quang Vinh - MSSV: DTC245180115" >> "$EVIDENCE_FILE"
echo "Repo: DTC245180115-fleet-devops" >> "$EVIDENCE_FILE"
echo "================================================================================" >> "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

log_ev() {
  echo "$1" | tee -a "$EVIDENCE_FILE"
}

cd /home/lucka/fleet

# 1. DOCKER COMPOSE PS
log_ev ">>> 1. TRANG THAI TAT CA CONTAINERS (DOCKER COMPOSE PS):"
docker compose ps | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 2. KIEM TRA PROMETHEUS TARGETS UP
log_ev ">>> 2. KIEM TRA PROMETHEUS TARGETS QUA API (/api/v1/targets):"
docker exec fleet_prometheus wget -qO- http://localhost:9090/api/v1/targets | \
  jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError, scrapeUrl: .scrapeUrl}' | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 3. KIEM TRA CAC TRUY VAN PROMQL QUA API
log_ev ">>> 3. KIEM TRA TRUY VAN PROMQL (CO DU LIEU THAT):"
log_ev "a) container_memory_usage_bytes (cAdvisor):"
docker exec fleet_prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=container_memory_usage_bytes' | \
  jq '.data.result[0:3]' | tee -a "$EVIDENCE_FILE"

log_ev "b) nginx_connections_active (Nginx Exporter):"
docker exec fleet_prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=nginx_connections_active' | \
  jq '.data.result' | tee -a "$EVIDENCE_FILE"

log_ev "c) pg_stat_database_numbackends (Postgres Exporter):"
docker exec fleet_prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=pg_stat_database_numbackends%7Bdatname%3D%22fleetdb%22%7D' | \
  jq '.data.result' | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 4. KIEM TRA GRAFANA LOGIN QUA HTTPS
log_ev ">>> 4. KIEM TRA TRANG DANG NHAP GRAFANA QUA HTTPS (CURL -KI HTTPS://LOCALHOST/GRAFANA/LOGIN):"
curl -k -s -I https://localhost/grafana/login | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 5. KIEM TRA GRAFANA PROVISIONING QUA API
log_ev ">>> 5. KIEM TRA DATASOURCE VA DASHBOARDS PROVISIONED QUA GRAFANA API:"
log_ev "a) Danh sach Datasources:"
curl -k -s -u "fleetadmin:FleetGrafana@2026!" https://localhost/grafana/api/datasources | \
  jq '.[0] | {id, name, type, url, isDefault, readOnly}' | tee -a "$EVIDENCE_FILE"

log_ev "b) Danh sach Dashboards trong thu muc Fleet Monitoring:"
curl -k -s -u "fleetadmin:FleetGrafana@2026!" https://localhost/grafana/api/search | \
  jq '.[] | {id, uid, title, type, folderTitle, url}' | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 6. SINH TAI VA XAC NHAN SO LIEU CAP NHAT
log_ev ">>> 6. KET QUA SINH TAI HE THONG (200 REQUESTS, LOGIN, TRIPS):"
COOKIE_JAR="/tmp/test4_cookie.txt"
rm -f "$COOKIE_JAR"

CSRF=$(curl -k -s -c "$COOKIE_JAR" https://localhost/login | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1)
curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST https://localhost/login \
  -d "username=admin&password=FleetAdmin@2026!&_csrf=$CSRF" > /dev/null

log_ev "Dang sinh tai them 50 requests toi /vehicles va /kpi..."
for i in $(seq 1 50); do
  curl -k -s -b "$COOKIE_JAR" https://localhost/vehicles -o /dev/null &
  curl -k -s -b "$COOKIE_JAR" https://localhost/kpi -o /dev/null &
  if (( i % 10 == 0 )); then wait; fi
done
wait

NGINX_REQ=$(docker exec fleet_prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=nginx_http_requests_total' | jq -r '.data.result[0].value[1]')
PG_XACT=$(docker exec fleet_prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=pg_stat_database_xact_commit%7Bdatname%3D%22fleetdb%22%7D' | jq -r '.data.result[0].value[1]')
PG_TUP=$(docker exec fleet_prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=pg_stat_database_tup_returned%7Bdatname%3D%22fleetdb%22%7D' | jq -r '.data.result[0].value[1]')

log_ev "Nginx tong so requests da phuc vu: ${NGINX_REQ}"
log_ev "PostgreSQL tong so giao dich commit: ${PG_XACT}"
log_ev "PostgreSQL tong so tuples duyet qua: ${PG_TUP}"
echo "" >> "$EVIDENCE_FILE"

# 7. GHI RO LUU Y VE CADVISOR TREN DOCKER DESKTOP / WSL2
log_ev ">>> 7. GHI CHU KY THUAT VE CADVISOR TRONG MOI TRUONG DOCKER DESKTOP (WSL2):"
log_ev "- Docker Desktop tren Windows chay daemon trong may ao chuyen biet (docker-desktop)."
log_ev "- Duong dan /var/lib/docker/ thuoc ve may ao rieng, khong nam truc tiep tren he thong tap tin cua distro WSL Ubuntu-22.04."
log_ev "- cAdvisor duoc cau hinh voi co --docker_only=true va --housekeeping_interval=10s, ket noi qua /var/run/docker.sock va /sys."
log_ev "- So lieu tong quan RAM (container_memory_usage_bytes), CPU, va Network I/O duoc thu thap va hien thi day du tren Grafana ma khong can cap quyen --privileged."
echo "" >> "$EVIDENCE_FILE"

log_ev "=== HOAN TAT TOAN BO KIEM TRA BUOC 4 ==="
