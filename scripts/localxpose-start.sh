#!/bin/zsh

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_FILE="$DOCKER_DIR/.env"
PID_FILE="$REPO_ROOT/.localxpose.pid"
CONFIG_FILE="$REPO_ROOT/localxpose.tunnels.yaml"
LOG_FILE="$REPO_ROOT/logs/localxpose.log"
LOCALXPOSE_BIN="${LOCALXPOSE_BIN:-loclx}"

if [ ! -f "$ENV_FILE" ]; then
    echo "LocalXpose: .env file not found at $ENV_FILE"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

enabled="$(printf '%s' "${LOCALXPOSE_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
if [ "$enabled" != "true" ]; then
    echo "LocalXpose is disabled (set LOCALXPOSE_ENABLED=true to enable)."
    exit 0
fi

if ! command -v "$LOCALXPOSE_BIN" >/dev/null 2>&1; then
    echo "LocalXpose binary '$LOCALXPOSE_BIN' not found in PATH."
    exit 1
fi

if [ -z "${LOCALXPOSE_AUTH_TOKEN:-}" ]; then
    echo "LOCALXPOSE_AUTH_TOKEN is not set; skipping tunnel start."
    exit 1
fi

if [ -f "$PID_FILE" ]; then
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
        echo "LocalXpose tunnel already running (PID $pid)."
        exit 0
    fi
    rm -f "$PID_FILE"
fi

mkdir -p "$(dirname "$LOG_FILE")"

echo "Authenticating LocalXpose client..."
if ! "$LOCALXPOSE_BIN" account login --token "$LOCALXPOSE_AUTH_TOKEN" >/dev/null 2>&1; then
    echo "Failed to authenticate LocalXpose account."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    target_port="${LOCALXPOSE_TUNNEL_PORT:-8080}"
    reserved_domain="${LOCALXPOSE_DOMAIN:-simonrowe.dev}"
    region="${LOCALXPOSE_REGION:-eu}"
    cat >"$CONFIG_FILE" <<EOF
primary:
  type: http
  to: localhost:${target_port}
  region: ${region}
  reserved_domain: ${reserved_domain}
EOF
    echo "LocalXpose config created at $CONFIG_FILE"
else
    echo "Using existing LocalXpose config at $CONFIG_FILE"
fi

extra_args=()
if [ -n "${LOCALXPOSE_EXTRA_ARGS:-}" ]; then
    set -o noglob
    extra_args=(${=LOCALXPOSE_EXTRA_ARGS})
    set +o noglob
fi

echo "Starting LocalXpose tunnel(s) defined in $CONFIG_FILE"
nohup "$LOCALXPOSE_BIN" tunnel config \
    -f "$CONFIG_FILE" \
    --raw-mode \
    "${extra_args[@]}" \
    >>"$LOG_FILE" 2>&1 &
pid=$!
echo "$pid" >"$PID_FILE"
echo "LocalXpose tunnel running in background (PID $pid). Logs: $LOG_FILE"
