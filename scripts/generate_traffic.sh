#!/usr/bin/env bash
set -e

COOKIE_JAR="/tmp/driver_cookie.txt"
rm -f ""

TOKEN=
curl -k -s -b "" -c "" -X POST https://localhost/login   --data-urlencode "username=taixe01"   --data-urlencode "password=FleetDriver@2026!"   --data-urlencode "_csrf=" -o /dev/null

TOKEN2=
if [ -n "" ]; then
  curl -k -s -b "" -c "" -X POST https://localhost/trips/6/start     --data-urlencode "_csrf=" -o /dev/null || true
  sleep 1
  TOKEN3=
  if [ -n "" ]; then
    curl -k -s -b "" -c "" -X POST https://localhost/trips/6/end       --data-urlencode "_csrf="       --data-urlencode "end_odometer=12890" -o /dev/null || true
  fi
fi

# Trigger HTTP 500 error on webapp to test Q1 and Q2
curl -k -s -b "" https://localhost/vehicles/not_an_int -o /dev/null || true

echo "Traffic generation complete!"
