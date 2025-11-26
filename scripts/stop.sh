#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_HELPER="$REPO_ROOT/scripts/lib/env.sh"

# Stop Docker Compose environment
echo "Stopping Docker Compose environment..."

# Change to docker directory
cd "$DOCKER_DIR" || exit 1

# Load environment if it exists (used for logging/enabled flag visibility)
# shellcheck source=scripts/lib/env.sh
. "$ENV_HELPER"
if ! load_env_files; then
    exit 1
fi

# List of compose files
COMPOSE_FILES=(
    "data-stores.yml"
    "tools.yml"
    "services.yml"
    "reverse-proxy.yml"
    # "observability.yml"
)

# Build the docker-compose command with optional profile
CMD=(docker-compose)
localxpose_enabled="$(printf '%s' "${LOCALXPOSE_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
if [ "$localxpose_enabled" = "true" ]; then
    CMD+=("--profile" "localxpose")
fi
for file in "${COMPOSE_FILES[@]}"; do
    if [ -f "$file" ]; then
        CMD+=("-f" "$file")
    fi
done
CMD+=("down")

# Stop Pinggy tunnel if running
if [ -f "/tmp/pinggy-tunnel.pid" ]; then
    echo "Stopping Pinggy SSH tunnel..."
    "$REPO_ROOT/scripts/pinggy-tunnel-manager.sh" stop
fi

# Stop services
"${CMD[@]}"

# Remove the app-network if it exists and is not being used
if docker network ls | grep -q "app-network"; then
    echo "Removing app-network..."
    if docker network rm app-network 2>/dev/null; then
        echo "app-network removed successfully"
    else
        echo "app-network could not be removed (may still be in use)"
    fi
fi

echo "Environment stopped successfully!"
