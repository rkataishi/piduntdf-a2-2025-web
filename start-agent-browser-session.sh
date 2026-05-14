#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"
PAGE="${1:-index-3.html}"
SESSION_NAME="${SESSION_NAME:-piduntdf-web}"

STATE_DIR="${ROOT_DIR}/.trae/session"
PID_FILE="${STATE_DIR}/http-server.pid"
LOG_FILE="${STATE_DIR}/http-server.log"
SNAPSHOT_FILE="${STATE_DIR}/last-snapshot.txt"
URL="http://${HOST}:${PORT}/${PAGE}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Falta el comando requerido: $1" >&2
    exit 1
  fi
}

is_pid_running() {
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

port_is_listening() {
  lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for_url() {
  local tries=0
  until curl -fsS "${URL}" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [[ "$tries" -ge 50 ]]; then
      echo "No se pudo levantar ${URL}" >&2
      exit 1
    fi
    sleep 0.2
  done
}

start_server() {
  mkdir -p "$STATE_DIR"

  if [[ -f "$PID_FILE" ]]; then
    local old_pid
    old_pid="$(cat "$PID_FILE")"
    if is_pid_running "$old_pid"; then
      return
    fi
    rm -f "$PID_FILE"
  fi

  if port_is_listening; then
    echo "El puerto ${PORT} ya esta en uso; reutilizando el servidor existente."
    return
  fi

  nohup python3 -m http.server "$PORT" --bind "$HOST" --directory "$ROOT_DIR" \
    >"$LOG_FILE" 2>&1 &
  echo "$!" >"$PID_FILE"
}

require_cmd python3
require_cmd curl
require_cmd agent-browser
require_cmd lsof

start_server
wait_for_url

agent-browser --session-name "$SESSION_NAME" open --headed "$URL"
agent-browser --session-name "$SESSION_NAME" wait --load networkidle
agent-browser --session-name "$SESSION_NAME" snapshot -i | tee "$SNAPSHOT_FILE"

cat <<EOF

Sesion lista.
- URL: ${URL}
- Session: ${SESSION_NAME}
- Snapshot guardado en: ${SNAPSHOT_FILE}
- Log del servidor: ${LOG_FILE}

Comandos utiles:
  agent-browser --session-name "${SESSION_NAME}" snapshot -i
  agent-browser --session-name "${SESSION_NAME}" screenshot --annotate ./after.png
  agent-browser --session-name "${SESSION_NAME}" reload

Si queres abrir otra pagina:
  ./start-agent-browser-session.sh piduntdf-integrantes-2.html
EOF
