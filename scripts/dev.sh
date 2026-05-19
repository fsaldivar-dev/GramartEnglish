#!/usr/bin/env bash
# GramartEnglish — dev runner.
#
# Usage:
#   scripts/dev.sh                  # backend + app, fresh DB
#   scripts/dev.sh --keep-db        # backend + app, preserve existing DB
#   scripts/dev.sh backend          # solo backend
#   scripts/dev.sh app <port>       # solo app, apuntando al puerto dado
#
# Prereqs:
#   - Node 20 LTS (no v25; mise/nvm activated)
#   - pnpm 9 (corepack o brew)
#   - Ollama corriendo con qwen2.5:7b u otro modelo de chat
#   - macOS 14+ Apple Silicon
#
# El backend imprime un handshake JSON en la primera línea de stdout con su
# puerto. Si lanzas backend y app por separado, copia ese puerto manualmente.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
APP_DIR="$REPO_ROOT/app/GramartEnglish"
LOG_DIR="$REPO_ROOT/.gramart-logs"

mkdir -p "$LOG_DIR"

# ---- Checks ---------------------------------------------------------------
check_tooling() {
  local node_v
  node_v="$(node -v 2>/dev/null || echo 'missing')"
  if [[ ! "$node_v" =~ ^v20\. ]]; then
    echo "❌ Node 20 LTS required (found: $node_v)." >&2
    echo "   → mise use --global node@20    (or nvm install 20)" >&2
    exit 1
  fi
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "❌ pnpm not on PATH." >&2
    echo "   → corepack enable && corepack prepare pnpm@9.12.0 --activate" >&2
    exit 1
  fi
  if ! pgrep -x ollama >/dev/null 2>&1 && ! pgrep -fx 'ollama serve' >/dev/null 2>&1; then
    echo "⚠️  Ollama doesn't seem to be running. AI features will fall back to canonical." >&2
    echo "   → ollama serve &" >&2
  fi
}

# ---- Backend --------------------------------------------------------------
launch_backend() {
  local keep_db="${1:-no}"
  if [[ "$keep_db" != "keep" ]]; then
    rm -rf "$REPO_ROOT/.gramart"
    echo "🧹 Cleaned .gramart (fresh DB on boot)"
  fi
  echo "🚀 Starting backend…"
  cd "$BACKEND_DIR"
  GRAMART_CHAT_MODEL="${GRAMART_CHAT_MODEL:-qwen2.5:7b}" \
    pnpm run dev > "$LOG_DIR/backend.log" 2>&1 &
  local pid=$!
  echo "$pid" > "$LOG_DIR/backend.pid"
  sleep 3
  local port
  port="$(head -1 "$LOG_DIR/backend.log" | jq -r .port 2>/dev/null || echo '')"
  if [[ -z "$port" || "$port" == "null" ]]; then
    echo "❌ Backend failed to print handshake. See $LOG_DIR/backend.log" >&2
    cat "$LOG_DIR/backend.log" >&2
    exit 1
  fi
  echo "$port" > "$LOG_DIR/backend.port"
  echo "✅ Backend ready on http://127.0.0.1:$port  (pid $pid)"
  echo "   Logs: $LOG_DIR/backend.log"
  echo "$port"
}

# ---- App ------------------------------------------------------------------
launch_app() {
  local port="$1"
  echo "🚀 Starting macOS app (will compile if needed)…"
  cd "$APP_DIR"
  GRAMART_BACKEND_URL="http://127.0.0.1:$port" swift run
}

# ---- Stop helpers --------------------------------------------------------
stop_backend() {
  local pid_file="$LOG_DIR/backend.pid"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "🛑 Backend stopped (pid $pid)"
    fi
    rm -f "$pid_file"
  fi
}

# ---- Dispatch ------------------------------------------------------------
cmd="${1:-all}"
case "$cmd" in
  all)
    check_tooling
    keep="no"
    [[ "${2:-}" == "--keep-db" ]] && keep="keep"
    PORT="$(launch_backend "$keep")"
    trap stop_backend EXIT
    launch_app "$PORT"
    ;;
  backend)
    check_tooling
    keep="no"
    [[ "${2:-}" == "--keep-db" ]] && keep="keep"
    PORT="$(launch_backend "$keep")"
    echo
    echo "Backend running. To stop:   $0 stop"
    echo "To launch the app:          $0 app $PORT"
    wait
    ;;
  app)
    PORT="${2:-$(cat "$LOG_DIR/backend.port" 2>/dev/null || echo '')}"
    if [[ -z "$PORT" ]]; then
      echo "❌ Pass the port: $0 app <port>" >&2
      exit 1
    fi
    launch_app "$PORT"
    ;;
  stop)
    stop_backend
    ;;
  status)
    if [[ -f "$LOG_DIR/backend.pid" ]] && kill -0 "$(cat "$LOG_DIR/backend.pid")" 2>/dev/null; then
      echo "✅ Backend running  pid=$(cat "$LOG_DIR/backend.pid")  port=$(cat "$LOG_DIR/backend.port" 2>/dev/null)"
    else
      echo "❌ Backend not running"
    fi
    ;;
  *)
    echo "Usage: $0 [all | backend | app <port> | stop | status] [--keep-db]" >&2
    exit 1
    ;;
esac
