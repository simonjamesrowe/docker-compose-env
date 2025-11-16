#!/bin/zsh

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_FILE="$DOCKER_DIR/.env"
PID_FILE="$REPO_ROOT/.localxpose.pid"

if [ ! -f "$ENV_FILE" ]; then
    echo "LocalXpose stop skipped: .env file not found."
    exit 0
fi

set -a
source "$ENV_FILE"
set +a

enabled="$(printf '%s' "${LOCALXPOSE_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
if [ "$enabled" != "true" ]; then
    echo "LocalXpose is disabled; nothing to stop."
    exit 0
fi

if [ ! -f "$PID_FILE" ]; then
    echo "No LocalXpose PID file found; tunnel may already be stopped."
    exit 0
fi

pid="$(cat "$PID_FILE" 2>/dev/null || true)"
if [ -z "$pid" ]; then
    rm -f "$PID_FILE"
    echo "LocalXpose PID file was empty; cleaned up."
    exit 0
fi

if ps -p "$pid" >/dev/null 2>&1; then
    echo "Stopping LocalXpose tunnel (PID $pid)..."
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" 2>/dev/null || true
else
    echo "LocalXpose process $pid is not running."
fi

rm -f "$PID_FILE"
echo "LocalXpose tunnel stopped."
