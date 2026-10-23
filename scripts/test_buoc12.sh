#!/usr/bin/env bash
set -uo pipefail

if command curl -s --connect-timeout 2 "http://127.0.0.1:3000/health" > /dev/null 2>&1; then
  BASE_URL="http://127.0.0.1:3000"
  PGADMIN_URL="http://127.0.0.1:5050"
else
  BASE_URL="https://localhost"
  PGADMIN_URL="https://localhost/pgadmin/"
fi

curl() {
  command curl -k "$@"
}

EVIDENCE_FILE="/home/lucka/fleet/evidence/buoc12-web-db.txt"

echo "================================================================================" > "$EVIDENCE_FILE"
echo "EVIDENCE - BUOC 1 & 2: UNG DUNG WEB + POSTGRESQL + PGADMIN" >> "$EVIDENCE_FILE"
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
log_ev ">>> 1. KIEM TRA TRANG THAI CONTAINERS (DOCKER COMPOSE PS):"
docker compose ps | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# 2. KIEM TRA HEALTHCHECK & TRANG LOGIN
log_ev ">>> 2. KIEM TRA /health VA TRANG DANG NHAP:"
log_ev "$ curl -i $BASE_URL/health"
curl -s -i "$BASE_URL/health" | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

log_ev "$ curl -s -o /dev/null -w \"HTTP Status: %{http_code}\n\" $BASE_URL/login"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$BASE_URL/login" | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

# Helper for CSRF
get_csrf() {
  local jar="$1"
  local url="$2"
  local html
  html=$(curl -s -c "$jar" -b "$jar" "$url")
  echo "$html" | grep -o 'name="_csrf" value="[^"]*"' | head -n 1 | cut -d '"' -f 4
}

# 3. DANG NHAP THAT BAI (LOGGING LOGIN_FAILED)
log_ev ">>> 3. KIEM TRA DANG NHAP THAT BAI VA LOGGING LOGIN_FAILED:"
COOKIE_DISP=$(mktemp)
CSRF_LOGIN=$(get_csrf "$COOKIE_DISP" "$BASE_URL/login")
log_ev "Dang nhap sai mat khau cho user dieuphoi01..."
curl -s -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/login" \
  -d "_csrf=$CSRF_LOGIN" -d "username=dieuphoi01" -d "password=SaiMatKhau123" -o /dev/null

sleep 1
log_ev "Kiem tra log container web (tim LOGIN_FAILED):"
docker compose logs --tail=10 web | grep "LOGIN_FAILED" | tail -n 1 | tee -a "$EVIDENCE_FILE" || true
echo "" >> "$EVIDENCE_FILE"

# 4. DANG NHAP THANH CONG (LOGGING LOGIN_SUCCESS)
log_ev ">>> 4. KIEM TRA DANG NHAP THANH CONG VA LOGGING LOGIN_SUCCESS:"
CSRF_LOGIN=$(get_csrf "$COOKIE_DISP" "$BASE_URL/login")
curl -s -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/login" \
  -d "_csrf=$CSRF_LOGIN" -d "username=dieuphoi01" -d "password=FleetDisp@2026!" -o /dev/null

sleep 1
log_ev "Kiem tra log container web (tim LOGIN_SUCCESS):"
docker compose logs --tail=10 web | grep "LOGIN_SUCCESS" | tail -n 1 | tee -a "$EVIDENCE_FILE" || true
echo "" >> "$EVIDENCE_FILE"

# 5. DISPATCHER TAO CHUYEN XE VA GIAO TAI XE
log_ev ">>> 5. DISPATCHER TAO CHUYEN XE VA GIAO TAI XE (taixe01, xe 30A-123.45):"
CSRF_TRIP=$(get_csrf "$COOKIE_DISP" "$BASE_URL/trips/create")
START_TIME="2026-11-10T08:00"
END_TIME="2026-11-10T12:00"

curl -s -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_TRIP" \
  -d "vehicle_id=1" \
  -d "driver_id=1" \
  -d "origin=Trụ sở Hà Nội" \
  -d "destination=KCN Tiên Sơn Bắc Ninh" \
  -d "planned_start=$START_TIME" \
  -d "planned_end=$END_TIME" \
  -d "purpose=Chở đoàn thanh tra công tác" -o /dev/null

NEW_TRIP_INFO=$(docker exec -i fleet_db psql -U fleet_app -d fleetdb -t -c \
  "SELECT id, trip_code, vehicle_id, driver_id, status FROM trips WHERE destination = 'KCN Tiên Sơn Bắc Ninh' ORDER BY id DESC LIMIT 1;")
log_ev "Thong tin chuyen xe vua tao trong CSDL: $NEW_TRIP_INFO"
NEW_TRIP_ID=$(echo "$NEW_TRIP_INFO" | awk '{print $1}')
NEW_TRIP_CODE=$(echo "$NEW_TRIP_INFO" | awk '{print $3}')
echo "" >> "$EVIDENCE_FILE"

# 6. THU GIAO XE BI TRUNG LICH GIO (XAC NHAN BI TU CHOI)
log_ev ">>> 6. KIEM TRA RANG BUOC TRUNG LICH (Giao cung xe 30A-123.45 trung gio):"
CSRF_TRIP2=$(get_csrf "$COOKIE_DISP" "$BASE_URL/trips/create")
CONFLICT_RESP=$(curl -s -L -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_TRIP2" \
  -d "vehicle_id=1" \
  -d "driver_id=2" \
  -d "origin=Hà Nội" \
  -d "destination=Hưng Yên" \
  -d "planned_start=$START_TIME" \
  -d "planned_end=$END_TIME" \
  -d "purpose=Chở hàng trùng giờ")
log_ev "Phan hoi khi tao trung gio:"
echo "$CONFLICT_RESP" | grep -A 1 "alert-box alert-error" | head -n 2 | tee -a "$EVIDENCE_FILE" || true
echo "" >> "$EVIDENCE_FILE"

# 6b. CHAY SONG SONG NHIEU YEU CAU TAO CHUYEN CHO CUNG MOT XE
log_ev ">>> 6b. CHAY SONG SONG NHIEU YEU CAU CHO CUNG XE 5 (Toyota Fortuner 30F-456.78):"
PARA_START="2026-11-20T08:00"
PARA_END="2026-11-20T11:00"
COOKIE_P1=$(mktemp)
COOKIE_P2=$(mktemp)
CSRF_P1=$(get_csrf "$COOKIE_P1" "$BASE_URL/login")
CSRF_P2=$(get_csrf "$COOKIE_P2" "$BASE_URL/login")
curl -s -c "$COOKIE_P1" -b "$COOKIE_P1" -X POST "$BASE_URL/login" -d "_csrf=$CSRF_P1" -d "username=dieuphoi01" -d "password=FleetDisp@2026!" -o /dev/null
curl -s -c "$COOKIE_P2" -b "$COOKIE_P2" -X POST "$BASE_URL/login" -d "_csrf=$CSRF_P2" -d "username=dieuphoi02" -d "password=FleetDisp@2026!" -o /dev/null

CSRF_SUB1=$(get_csrf "$COOKIE_P1" "$BASE_URL/trips/create")
CSRF_SUB2=$(get_csrf "$COOKIE_P2" "$BASE_URL/trips/create")

curl -s -c "$COOKIE_P1" -b "$COOKIE_P1" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_SUB1" -d "vehicle_id=5" -d "driver_id=2" -d "origin=Hà Nội" -d "destination=Hải Phòng" \
  -d "planned_start=$PARA_START" -d "planned_end=$PARA_END" -d "purpose=Song song 1" -o /dev/null &
PID1=$!

curl -s -c "$COOKIE_P2" -b "$COOKIE_P2" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_SUB2" -d "vehicle_id=5" -d "driver_id=3" -d "origin=Hà Nội" -d "destination=Quảng Ninh" \
  -d "planned_start=$PARA_START" -d "planned_end=$PARA_END" -d "purpose=Song song 2" -o /dev/null &
PID2=$!

wait $PID1 $PID2
rm -f "$COOKIE_P1" "$COOKIE_P2"

PARA_COUNT=$(docker exec -i fleet_db psql -U fleet_app -d fleetdb -t -c \
  "SELECT count(*) FROM trips WHERE vehicle_id = 5 AND planned_start = '2026-11-20 08:00:00+00';")
log_ev "Ket qua so chuyen xe duoc tao thanh cong cho xe 5 cung gio: $(echo $PARA_COUNT | xargs) (Ky vong: dung 1)"
echo "" >> "$EVIDENCE_FILE"

# 7. THU GIAO XE DANG BAO DUONG / THANH LY & GIAO TAI XE HET HAN BANG LAI
log_ev ">>> 7. KIEM TRA TU CHOI XE BAO DUONG / THANH LY & TAI XE HET HAN BANG LAI:"
# Giao xe 7 (dang maintenance)
CSRF_TRIP3=$(get_csrf "$COOKIE_DISP" "$BASE_URL/trips/create")
MAINT_RESP=$(curl -s -L -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_TRIP3" \
  -d "vehicle_id=7" \
  -d "driver_id=2" \
  -d "origin=Hà Nội" \
  -d "destination=Hải Phòng" \
  -d "planned_start=2026-11-25T08:00" \
  -d "planned_end=2026-11-25T12:00" \
  -d "purpose=Test xe bảo dưỡng")
log_ev "Phan hoi khi giao xe dang bao duong:"
echo "$MAINT_RESP" | grep -A 1 "alert-box alert-error" | head -n 2 | tee -a "$EVIDENCE_FILE" || true

# Giao xe 16 (retired)
CSRF_TRIP4=$(get_csrf "$COOKIE_DISP" "$BASE_URL/trips/create")
RET_RESP=$(curl -s -L -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_TRIP4" \
  -d "vehicle_id=16" \
  -d "driver_id=2" \
  -d "origin=Hà Nội" \
  -d "destination=Hải Dương" \
  -d "planned_start=2026-11-25T08:00" \
  -d "planned_end=2026-11-25T12:00" \
  -d "purpose=Test xe thanh lý")
log_ev "Phan hoi khi giao xe da thanh ly:"
echo "$RET_RESP" | grep -A 1 "alert-box alert-error" | head -n 2 | tee -a "$EVIDENCE_FILE" || true

# Giao tai xe taixe01 chuyen xe sau khi bang lai da het han (taixe01 het han sau 20 ngay -> test giao sau 60 ngay)
CSRF_TRIP5=$(get_csrf "$COOKIE_DISP" "$BASE_URL/trips/create")
EXP_DRIVER_RESP=$(curl -s -L -c "$COOKIE_DISP" -b "$COOKIE_DISP" -X POST "$BASE_URL/trips/create" \
  -d "_csrf=$CSRF_TRIP5" \
  -d "vehicle_id=1" \
  -d "driver_id=1" \
  -d "origin=Hà Nội" \
  -d "destination=Thái Nguyên" \
  -d "planned_start=2026-12-28T08:00" \
  -d "planned_end=2026-12-28T12:00" \
  -d "purpose=Test tài xế hết hạn bằng")
log_ev "Phan hoi khi giao tai xe het han bang lai:"
echo "$EXP_DRIVER_RESP" | grep -A 1 "alert-box alert-error" | head -n 2 | tee -a "$EVIDENCE_FILE" || true
echo "" >> "$EVIDENCE_FILE"

# 8. TAI XE (taixe01) BAT DAU VA HOAN THANH CHUYEN XE
log_ev ">>> 8. TAI XE THUC HIEN CHUYEN XE (BAT DAU -> KET THUC):"
COOKIE_DRIVER=$(mktemp)
CSRF_DLOGIN=$(get_csrf "$COOKIE_DRIVER" "$BASE_URL/login")
curl -s -c "$COOKIE_DRIVER" -b "$COOKIE_DRIVER" -X POST "$BASE_URL/login" \
  -d "_csrf=$CSRF_DLOGIN" -d "username=taixe01" -d "password=FleetDriver@2026!" -o /dev/null

# Lay so km hien tai cua xe 1
CURR_KM=$(docker exec -i fleet_db psql -U fleet_app -d fleetdb -t -c "SELECT odometer_km FROM vehicles WHERE id = 1;" | xargs)
START_KM=$CURR_KM
END_KM=$((START_KM + 75))

# Bat dau chuyen xe voi start_odometer = $START_KM
CSRF_START=$(get_csrf "$COOKIE_DRIVER" "$BASE_URL/trips/driver")
curl -s -c "$COOKIE_DRIVER" -b "$COOKIE_DRIVER" -X POST "$BASE_URL/trips/$NEW_TRIP_ID/start" \
  -d "_csrf=$CSRF_START" -d "start_odometer=$START_KM" -o /dev/null

sleep 1
log_ev "Trang thai log sau khi bat dau chuyen (tim TRIP_STATUS_CHANGE):"
docker compose logs --tail=10 web | grep "TRIP_STATUS_CHANGE.*to=in_progress" | tail -n 1 | tee -a "$EVIDENCE_FILE" || true

# Kiem tra ket thuc voi so km < bat dau bi tu choi
CSRF_END_FAIL=$(get_csrf "$COOKIE_DRIVER" "$BASE_URL/trips/driver")
FAIL_END_RESP=$(curl -s -L -c "$COOKIE_DRIVER" -b "$COOKIE_DRIVER" -X POST "$BASE_URL/trips/$NEW_TRIP_ID/end" \
  -d "_csrf=$CSRF_END_FAIL" -d "end_odometer=$((START_KM - 20))")
log_ev "Phan hoi khi ket thuc voi end_odometer < start_odometer:"
echo "$FAIL_END_RESP" | grep -A 1 "alert-box alert-error" | head -n 2 | tee -a "$EVIDENCE_FILE" || true

# Ket thuc hop le voi $END_KM (distance = 75 km)
CSRF_END_OK=$(get_csrf "$COOKIE_DRIVER" "$BASE_URL/trips/driver")
curl -s -c "$COOKIE_DRIVER" -b "$COOKIE_DRIVER" -X POST "$BASE_URL/trips/$NEW_TRIP_ID/end" \
  -d "_csrf=$CSRF_END_OK" -d "end_odometer=$END_KM" -o /dev/null

sleep 1
log_ev "Trang thai log sau khi ket thuc chuyen (tim TRIP_STATUS_CHANGE to=completed):"
docker compose logs --tail=10 web | grep "TRIP_STATUS_CHANGE.*to=completed" | tail -n 1 | tee -a "$EVIDENCE_FILE" || true

# Kiem tra CSDL xe va trip sau khi ket thuc
DB_CHECK=$(docker exec -i fleet_db psql -U fleet_app -d fleetdb -t -c \
  "SELECT t.status, t.distance_km, v.odometer_km, v.status FROM trips t JOIN vehicles v ON t.vehicle_id = v.id WHERE t.id = $NEW_TRIP_ID;")
log_ev "Trang thai trip & xe trong DB sau ket thuc (trip_status, distance_km, v_odometer, v_status): $DB_CHECK"
echo "" >> "$EVIDENCE_FILE"

# 9. PHAN QUYEN RBAC & CHAN IDOR
log_ev ">>> 9. KIEM TRA PHAN QUYEN RBAC & IDOR:"
log_ev "Tai xe truy cap /trips (trang cua dispatcher/admin):"
STATUS_TRIPS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_DRIVER" "$BASE_URL/trips")
log_ev "HTTP Code: $STATUS_TRIPS (Ky vong: 403)"

log_ev "Tai xe truy cap /vehicles/create (trang admin):"
STATUS_ADMIN=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_DRIVER" "$BASE_URL/vehicles/create")
log_ev "HTTP Code: $STATUS_ADMIN (Ky vong: 403)"

log_ev "Dispatcher truy cap /vehicles/create (trang admin):"
STATUS_DISP_ADMIN=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_DISP" "$BASE_URL/vehicles/create")
log_ev "HTTP Code: $STATUS_DISP_ADMIN (Ky vong: 403)"

# IDOR test: taixe02 truy cap print lenh dieu xe cua taixe01
COOKIE_D2=$(mktemp)
CSRF_D2=$(get_csrf "$COOKIE_D2" "$BASE_URL/login")
curl -s -c "$COOKIE_D2" -b "$COOKIE_D2" -X POST "$BASE_URL/login" \
  -d "_csrf=$CSRF_D2" -d "username=taixe02" -d "password=FleetDriver@2026!" -o /dev/null
STATUS_IDOR=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_D2" "$BASE_URL/trips/$NEW_TRIP_ID/print")
log_ev "Tai xe 02 truy cap phieu lenh dieu xe cua tai xe 01: HTTP Code $STATUS_IDOR (Ky vong: 403)"
echo "" >> "$EVIDENCE_FILE"

# 10. ADMIN TAO XE VA UPLOAD ANH
log_ev ">>> 10. ADMIN TAO XE + UPLOAD ANH HOP LE & TEST CHAN FILE GIA MAO:"
COOKIE_ADMIN=$(mktemp)
CSRF_ADMIN=$(get_csrf "$COOKIE_ADMIN" "$BASE_URL/login")
curl -s -c "$COOKIE_ADMIN" -b "$COOKIE_ADMIN" -X POST "$BASE_URL/login" \
  -d "_csrf=$CSRF_ADMIN" -d "username=admin" -d "password=FleetAdmin@2026!" -o /dev/null

TEST_PNG=$(mktemp --suffix=.png)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_PNG"

CSRF_CAR=$(get_csrf "$COOKIE_ADMIN" "$BASE_URL/vehicles/create")
NEW_PLATE="30H-777.88"
curl -s -c "$COOKIE_ADMIN" -b "$COOKIE_ADMIN" -X POST "$BASE_URL/vehicles/create?_csrf=$CSRF_CAR" \
  -F "_csrf=$CSRF_CAR" \
  -F "plate_number=$NEW_PLATE" \
  -F "vehicle_type_id=2" \
  -F "make=Hyundai" \
  -F "model=Santa Fe Calligraphy" \
  -F "year=2024" \
  -F "vin=KMHSH814DN9988776" \
  -F "fuel_type=gasoline" \
  -F "seats=7" \
  -F "odometer_km=1200" \
  -F "status=available" \
  -F "registration_expiry=2027-10-20" \
  -F "insurance_expiry=2027-10-20" \
  -F "next_service_km=10000" \
  -F "image=@$TEST_PNG;type=image/png" -o /dev/null

CAR_CHECK=$(docker exec -i fleet_db psql -U fleet_app -d fleetdb -t -c \
  "SELECT plate_number, make, model, image_path FROM vehicles WHERE plate_number = '$NEW_PLATE';")
log_ev "Kiem tra xe Hyundai Santa Fe vua tao kem anh upload: $CAR_CHECK"

# Test upload file .exe bi tu choi
CSRF_EXE=$(get_csrf "$COOKIE_ADMIN" "$BASE_URL/vehicles/create")
TEST_EXE=$(mktemp --suffix=.exe)
echo "MZ executable file dummy" > "$TEST_EXE"
EXE_RESP=$(curl -s -L -c "$COOKIE_ADMIN" -b "$COOKIE_ADMIN" -X POST "$BASE_URL/vehicles/create?_csrf=$CSRF_EXE" \
  -F "_csrf=$CSRF_EXE" \
  -F "plate_number=29E-999.00" \
  -F "vehicle_type_id=1" \
  -F "make=Test" \
  -F "model=Fake" \
  -F "year=2023" \
  -F "fuel_type=gasoline" \
  -F "seats=5" \
  -F "odometer_km=1000" \
  -F "status=available" \
  -F "registration_expiry=2027-10-20" \
  -F "insurance_expiry=2027-10-20" \
  -F "next_service_km=10000" \
  -F "image=@$TEST_EXE;type=application/octet-stream")
log_ev "Phan hoi khi upload file .exe:"
echo "$EXE_RESP" | grep -A 1 "alert-box alert-error" | head -n 2 | tee -a "$EVIDENCE_FILE" || true
echo "" >> "$EVIDENCE_FILE"

# 11. KIEM TRA PGADMIN
log_ev ">>> 11. KIEM TRA PGADMIN HOAT DONG TAI CONG 5050:"
PGA_STATUS=$(curl -s -L -o /dev/null -w "%{http_code}" "$PGADMIN_URL")
log_ev "Kiem tra $PGADMIN_URL: HTTP Code $PGA_STATUS (Ky vong: 200)"
echo "" >> "$EVIDENCE_FILE"

# 12. KIEM TRA 7 BANG POSTGRESQL TRONG CSDL
log_ev ">>> 12. KIEM TRA 7 BANG VA DU LIEU SEED TRONG POSTGRESQL:"
docker exec -i fleet_db psql -U fleet_app -d fleetdb -c '\dt' | tee -a "$EVIDENCE_FILE"
docker exec -i fleet_db psql -U fleet_app -d fleetdb -c "
SELECT 'drivers' as table_name, count(*) as row_count FROM drivers UNION ALL
SELECT 'fuel_logs', count(*) FROM fuel_logs UNION ALL
SELECT 'maintenance_records', count(*) FROM maintenance_records UNION ALL
SELECT 'trips', count(*) FROM trips UNION ALL
SELECT 'users', count(*) FROM users UNION ALL
SELECT 'vehicle_types', count(*) FROM vehicle_types UNION ALL
SELECT 'vehicles', count(*) FROM vehicles;
" | tee -a "$EVIDENCE_FILE"
echo "" >> "$EVIDENCE_FILE"

rm -f "$COOKIE_DISP" "$COOKIE_DRIVER" "$COOKIE_D2" "$COOKIE_ADMIN" "$TEST_PNG" "$TEST_EXE" 2>/dev/null || true

log_ev "================================================================================"
log_ev "HOAN THANH TOAN BO KIEM TRA BUOC 1 & 2!"
log_ev "================================================================================"
