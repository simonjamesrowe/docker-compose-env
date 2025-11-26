#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_HELPER="$REPO_ROOT/scripts/lib/env.sh"

# Start Docker Compose environment
echo "Starting Docker Compose environment..."

# Change to docker directory
cd "$DOCKER_DIR" || exit 1

# Load shared env helpers
# shellcheck source=scripts/lib/env.sh
. "$ENV_HELPER"

# List of compose files
COMPOSE_FILES=(
    "data-stores.yml"
    "tools.yml"
    "services.yml"
    "reverse-proxy.yml"
    # "observability.yml"
)

# Load environment variables for helper integrations and docker-compose
if ! load_env_files; then
    exit 1
fi

# Create the app-network if it doesn't exist
if ! docker network ls | grep -q "app-network"; then
    echo "Creating app-network..."
    docker network create app-network
else
    echo "app-network already exists"
fi

# Build the docker-compose command arguments
COMPOSE_ARGS=()
for file in "${COMPOSE_FILES[@]}"; do
    if [ -f "$file" ]; then
        COMPOSE_ARGS+=("-f" "$file")
    else
        echo "Warning: $file not found, skipping..."
    fi
done

CMD=(docker-compose "${COMPOSE_ARGS[@]}" up -d)
echo "Running: ${CMD[*]}"
if "${CMD[@]}"; then
    echo "Environment started successfully!"
    echo "Use './stop.sh' to stop the environment"

    # Start Pinggy tunnel if enabled
    pinggy_enabled="$(printf '%s' "${PINGGY_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
    if [ "$pinggy_enabled" = "true" ]; then
        if [ -z "${PINGGY_AUTH_TOKEN}" ]; then
            echo "Warning: PINGGY_ENABLED is true but PINGGY_AUTH_TOKEN is not set. Skipping Pinggy tunnel."
        else
            echo "Starting Pinggy SSH tunnel..."
            if "$REPO_ROOT/scripts/pinggy-tunnel-manager.sh" start; then
                echo "Pinggy tunnel started successfully!"
            else
                echo "Warning: Failed to start Pinggy tunnel. Check your PINGGY_AUTH_TOKEN and logs."
            fi
        fi
    fi
else
    echo "Failed to start environment"
    exit 1
fi
