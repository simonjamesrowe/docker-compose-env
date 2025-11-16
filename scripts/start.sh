#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$REPO_ROOT/docker"
ENV_FILE="$DOCKER_DIR/.env"

# Start Docker Compose environment
echo "Starting Docker Compose environment..."

# Change to docker directory
cd "$DOCKER_DIR" || exit 1

# List of compose files
COMPOSE_FILES=(
    "data-stores.yml"
    "tools.yml"
    "services.yml"
    "reverse-proxy.yml"
    # "observability.yml"
)

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Please copy .env.template to .env and configure it."
    exit 1
fi

# Load environment variables for helper integrations
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

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

# Start services
echo "Running: docker-compose ${COMPOSE_ARGS[*]} up -d"
if docker-compose "${COMPOSE_ARGS[@]}" up -d; then
    echo "Environment started successfully!"
    echo "Use './stop.sh' to stop the environment"
    if ! "$REPO_ROOT/scripts/localxpose-start.sh"; then
        echo "LocalXpose tunnel did not start automatically. Check logs above or run scripts/localxpose-start.sh manually."
    fi
else
    echo "Failed to start environment"
    exit 1
fi
