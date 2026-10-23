#!/usr/bin/env python3
import http.server
import json
import sys
import os
from datetime import datetime

PORT = int(os.environ.get("PORT", "9099"))
LOG_FILE = "/app/alerts.log"

class AlertHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ["/health", "/"]:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "healthy"}')
        elif self.path == "/alerts":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            try:
                with open(LOG_FILE, "r") as f:
                    content = f.read()
                self.wfile.write(content.encode("utf-8"))
            except Exception:
                self.wfile.write(b'[]')
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)
        
        now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
        try:
            payload = json.loads(post_data.decode("utf-8"))
            status = payload.get("status", "unknown")
            alerts = payload.get("alerts", [])
            
            print(f"[ALERT_RECEIVED] [{now}] Status: {status}, Total Alerts: {len(alerts)}", flush=True)
            for alert in alerts:
                labels = alert.get("labels", {})
                annotations = alert.get("annotations", {})
                alert_name = labels.get("alertname", "Unknown Alert")
                severity = labels.get("severity", "unknown")
                summary = annotations.get("summary", "No summary")
                description = annotations.get("description", "No description")
                
                print(f"[SECURITY_ALERT] [{now}] Alert: '{alert_name}' | Severity: {severity} | Summary: {summary} | Description: {description}", flush=True)
            
            entry = {
                "received_at": now,
                "payload": payload
            }
            with open(LOG_FILE, "a") as f:
                f.write(json.dumps(entry) + "\n")

        except Exception as e:
            print(f"[ALERT_ERROR] Failed to parse alert: {e}", flush=True)

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status": "received"}')

    def log_message(self, format, *args):
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

if __name__ == "__main__":
    print(f"[ALERT-SINK] Starting Alert Sink Webhook receiver on port {PORT}...", flush=True)
    server = http.server.HTTPServer(("0.0.0.0", PORT), AlertHandler)
    server.serve_forever()
