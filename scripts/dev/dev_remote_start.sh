#!/usr/bin/env bash
# Dev remote start script — configures and starts both backend and Flutter web for remote iPhone development
# Uses the App Store Tailscale CLI to detect the Tailscale IPv4 address.
# Run once to set up, then use this script to start/continue remote development.
# Press Ctrl+C to stop background processes, or run the restart script.
set -Eeuo pipefail

REPO_ROOT="/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos"
BACKEND="$REPO_ROOT/backend"
FLUTTER="$REPO_ROOT/software1"
LOGFILE="/tmp/appprestamos_dev.log"

log() { printf '[dev-remote] %s\n' "$*" >&2; }

# ------------------------------------------------------------
# 1. Tailscale IPv4 detection — using App Store CLI only
# ------------------------------------------------------------
# The Mac uses the App Store Tailscale CLI. Do NOT rely on `tailscale` being in PATH.
TAILSCALE_BE_CLI=1
TAILSCALE_BIN="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
TAILSCALE_IP=""

if [ "$TAILSCALE_BE_CLI" = "1" ] && [ -x "$TAILSCALE_BIN" ]; then
  TAILSCALE_IP=$("$TAILSCALE_BIN" ip -4 2>&1 | tail -1 || true)
  # Validate it looks like an IPv4 address
  if echo "$TAILSCALE_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    log "Tailscale IPv4 detected: $TAILSCALE_IP"
  else
    TAILSCALE_IP=""
    log "WARNING: Tailscale IP not valid; falling back to error mode"
  fi
else
  log "Tailscale App Store CLI not found or not enabled; will fail without LAN IP fallback"
fi

# ------------------------------------------------------------
# 2. Fail clearly if Tailscale IP cannot be detected
# ------------------------------------------------------------
if [ -z "$TAILSCALE_IP" ]; then
  echo "=========================================" >&2
  echo "  FATAL: Could not detect Tailscale IPv4 address" >&2
  echo "  Make sure Tailscale is running and the App Store CLI exists:" >&2
  echo "    /Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4" >&2
  echo "  This remote-development setup requires Tailscale for the iPhone URL." >&2
  echo "  To use local Mac-only development instead, modify the script." >&2
  echo "=========================================" >&2
  exit 1
fi

log "Using Tailscale IP: $TAILSCALE_IP"

# ------------------------------------------------------------
# 3. PostgreSQL
# ------------------------------------------------------------
pg_ctl -D /opt/homebrew/var/postgresql@18 start -l /tmp/pg.log 2>&1 | log || true
pg_ctl -D /opt/homebrew/var/postgresql@18 status >/dev/null 2>&1 && log "PostgreSQL 18 active" || log "WARNING: PostgreSQL could not be started"

# ------------------------------------------------------------
# 4. Backend .env (create only if missing)
# ------------------------------------------------------------
if [[ ! -f "$BACKEND/.env" ]]; then
  cat > "$BACKEND/.env" <<'ENVEOF'
NODE_ENV=development
PORT=3000
HOST=0.0.0.0
DATABASE_URL=postgresql://johancarlosherrera@localhost:5432/appprestamos_local
DB_SSL_DISABLED=1
DB_POOL_MAX=10
DB_IDLE_TIMEOUT_MS=30000
DB_CONN_TIMEOUT_MS=8000
DB_SLOW_QUERY_MS=400
DB_LOG_ALL=0
DEBUG_DB_TUNING=0
CORS_ORIGINS=http://localhost:7357,http://127.0.0.1:7357
JWT_SECRET=$(openssl rand -base64 48)
AUTH_DEBUG=0
AUTH_OMIT_FOTO=0
LOG_REQUESTS=0
DEBUG_ROUTES=0
LOG_SIGNATURES=0
NOTIFIER_DEBUG=0
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
SMTP_FORCE_IPV4=0
SMTP_CONN_TIMEOUT=12000
SMTP_SOCKET_TIMEOUT=20000
SMTP_GREETING_TIMEOUT=10000
SMTP_HARD_TIMEOUT=25000
SMTP_ENABLE_FALLBACK=0
SMTP_FORCE_FALLBACK=0
SMTP_FALLBACK_HOST=
SMTP_FALLBACK_PORT=465
SMTP_FALLBACK_SECURE=true
DOCUMENT_TARGET_EMAIL=
DEFAULT_TARGET_EMAIL=
DOCUMENT_FROM_EMAIL=
MAIL_FROM=
FORCED_FALLBACK_FROM=1
EMAIL_MONITOR_BCC=
EMAIL_HTTP_PROVIDER=
SENDGRID_API_KEY=
EMAIL_HTTP_FORCE=0
EMAIL_HTTP_SANDBOX=1
EMAIL_HTTP_DEBUG=0
EMAIL_ASYNC=0
EMAIL_ASYNC_ON_FAIL=0
EMAIL_SOFT_FAIL=0
EMAIL_OUTBOX=0
EMAIL_OUTBOX_DISABLED=1
EMAIL_OUTBOX_DEBUG=0
EMAIL_BATCH_SIZE=10
EMAIL_MAX_ATTEMPTS=5
EMAIL_WORKER_INTERVAL_MS=12000
FCM_SERVER_KEY=
AUTO_UPDATE_DOCUMENT_STATUS=0
RESTRICT_UPLOAD_MIME=1
UPLOAD_DEBUG=0
OUTBOUND_SCAN_ENABLED=0
OUTBOUND_SCAN_TIMEOUT=5000
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
ENVEOF
  log "Created backend/.env"
else
  log "backend/.env already exists — skipping"
fi

# ------------------------------------------------------------
# 5. Update backend CORS to include Tailscale IP
# ------------------------------------------------------------
# Append Tailscale IP to CORS if not already present
CORS_FILE="$BACKEND/.env"
if grep -q "CORS_ORIGINS" "$CORS_FILE"; then
  # Add Tailscale IP origin if not already present
  if ! grep -q "http://${TAILSCALE_IP}:7357" "$CORS_FILE"; then
    # Read current value, append Tailscale IP
    CURRENT_CORS=$(grep '^CORS_ORIGINS=' "$CORS_FILE" | cut -d= -f2-)
    UPDATED_CORS="${CURRENT_CORS},http://${TAILSCALE_IP}:7357"
    sed -i '' "s|^CORS_ORIGINS=.*|CORS_ORIGINS=${UPDATED_CORS}|" "$CORS_FILE"
    log "Updated CORS_ORIGINS to include http://${TAILSCALE_IP}:7357"
  else
    log "CORS_ORIGINS already includes http://${TAILSCALE_IP}:7357"
  fi
else
  log "No CORS_ORIGINS found in backend .env — adding default + Tailscale"
  sed -i '' 's|^CORS_ORIGINS=.*|CORS_ORIGINS=http://localhost:7357,http://127.0.0.1:7357,http://'"${TAILSCALE_IP}"':7357|' "$CORS_FILE"
fi

# ------------------------------------------------------------
# 6. Start backend (background, port 3000, 0.0.0.0)
# ------------------------------------------------------------
if ! pgrep -f "node.*index.js" >/dev/null 2>&1; then
  cd "$BACKEND" && nohup npm start > "$LOGFILE" 2>&1 &
  log "Started backend (PID=$!), listening on http://0.0.0.0:3000"
  # Wait for backend health
  for i in $(seq 1 30); do
    if curl --fail --max-time 1 http://127.0.0.1:3000/ >/dev/null 2>&1; then
      log "Backend health check passed"
      break
    fi
    sleep 1
  done
else
  log "Backend already running — skipping restart"
fi

# ------------------------------------------------------------
# 7. Determine Flutter API_BASE_URL from Tailscale Serve HTTPS endpoint
# ------------------------------------------------------------
# The Mac has a Tailscale Serve proxy mapping:
#   https://johans-macbook-pro.tailfbc2ea.ts.net:3001 -> http://127.0.0.1:3000
# Use this HTTPS endpoint so that Flutter's API calls reach the backend
# whether the iPhone is on the same Tailscale network (remote) or the
# Mac is running locally (the Serve proxy forwards to the local backend).
FLUTTER_API_URL="https://johans-macbook-pro.tailfbc2ea.ts.net:3001"
log "Flutter API_BASE_URL will be set to: $FLUTTER_API_URL"

# ------------------------------------------------------------
# 8. Start Flutter Web (background, port 7357, 0.0.0.0 hostname)
# ------------------------------------------------------------
# Use web-server mode so the Flutter app is an HTTP server accessible
# from external IPs (iPhone on Tailscale). --web-hostname 0.0.0.0 makes it
# listen on all interfaces, not just localhost.
FLUTTER_CMD="flutter run -d web-server --web-hostname 0.0.0.0 --web-port 7357"

log "Running Flutter command: $FLUTTER_CMD --dart-define=API_BASE_URL=$FLUTTER_API_URL"
mkdir -p "$FLUTTER/build"
cd "$FLUTTER" && nohup $FLUTTER_CMD --dart-define=API_BASE_URL=$FLUTTER_API_URL > /tmp/flutter_web.log 2>&1 &
log "Started Flutter web (PID=$!), listening on http://0.0.0.0:7357"
# Wait for Flutter health
for i in $(seq 1 60); do
  if curl --fail --max-time 1 http://0.0.0.0:7357/ 2>/dev/null || \
     curl --fail --max-time 1 http://localhost:7357/ >/dev/null 2>&1 || \
     curl --fail --max-time 1 http://127.0.0.1:7357/ >/dev/null 2>&1; then
    log "Flutter web health check passed"
    break
  fi
  sleep 1
done

# ------------------------------------------------------------
# 9. Summary
# ------------------------------------------------------------
echo ""
echo "========================================="
echo "  AppPrestamos — Remote dev ready"
echo "========================================="
echo "  Tailscale IPv4:   $TAILSCALE_IP"
echo "  Flutter Web:      http://${TAILSCALE_IP}:7357"
echo "  (also localhost: http://127.0.0.1:7357 on Mac)"
echo "  Backend API:      https://johans-macbook-pro.tailfbc2ea.ts.net:3001"
echo "  (Tailscale Serve proxy: https://johans-macbook-pro.tailfbc2ea.ts.net:3001 -> http://127.0.0.1:3000)"
echo "  DB health:        https://johans-macbook-pro.tailfbc2ea.ts.net:3001/db-health (DO NOT expose DB)"
echo ""
echo "  iPhone: open Safari and go to:"
echo "    http://${TAILSCALE_IP}:7357"
echo ""
echo "  Mac local shortcuts:"
echo "    Kill backend:   pkill -f 'node.*index.js'"
echo "    Kill Flutter:   pkill -f 'flutter.*chrome'"
echo "    Restart all:    $0"
echo "========================================="