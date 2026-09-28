#!/usr/bin/env bash
# Dev remote restart script — stops and restarts both backend and Flutter web
set -Eeuo pipefail

REPO_ROOT="/Users/johancarlosherrera/Documents/ChatGPT/Proyecto_AppPrestamos/AppPrestamos"
BACKEND="$REPO_ROOT/backend"
FLUTTER="$REPO_ROOT/software1"
LOGFILE="/tmp/appprestamos_dev.log"

log() { printf '[dev-remote-restart] %s\n' "$*" >&2; }

# ------------------------------------------------------------
# 1. Stop any running instances
# ------------------------------------------------------------
log "Stopping any running backend/Flutter processes..."
pkill -f "node.*index.js" 2>/dev/null && log "Killed existing backend" || log "No backend process found to kill"
pkill -f "flutter.*chrome" 2>/dev/null && log "Killed existing Flutter web" || log "No Flutter process found to kill"
sleep 2

# ------------------------------------------------------------
# 2. Start the full remote dev stack
# ------------------------------------------------------------
bash "$REPO_ROOT/scripts/dev/dev_remote_start.sh" 2>&1 | tail -15