#!/usr/bin/env bash
set -uo pipefail

OUT="/home/lucka/fleet/evidence/buoc6-trivy.txt"
mkdir -p /home/lucka/fleet/evidence

echo "================================================================================" > "$OUT"
echo "EVIDENCE - BUOC 6: TRIVY VULNERABILITY SCAN REPORT" >> "$OUT"
echo "Thoi diem quet: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$OUT"
echo "Sinh vien: Nguyen Quang Vinh - MSSV: DTC245180115" >> "$OUT"
echo "Repo: DTC245180115-fleet-devops" >> "$OUT"
echo "================================================================================" >> "$OUT"
echo "" >> "$OUT"

scan_image() {
  local img="$1"
  echo "================================================================================" | tee -a "$OUT"
  echo ">>> QUET AN TOAN IMAGE: $img" | tee -a "$OUT"
  echo "================================================================================" | tee -a "$OUT"
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy_cache:/root/.cache \
    aquasec/trivy:0.50.1 image --skip-db-update --scanners vuln --severity CRITICAL,HIGH --format table "$img" 2>&1 | tee -a "$OUT"
  echo "" >> "$OUT"
}

scan_image "fleet-web"
scan_image "nginxinc/nginx-unprivileged:1.27-alpine"
scan_image "postgres:16.3-alpine3.20"
scan_image "prom/prometheus:v2.53.0"
scan_image "grafana/grafana:11.0.0"
scan_image "grafana/loki:3.0.0"

echo "=== HOAN TAT QUET TRIVY CHO TAT CA CAC IMAGE CHINH ===" | tee -a "$OUT"