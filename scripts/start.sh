#!/bin/bash

# Start Docker Compose environment
echo "Starting Docker Compose environment..."

# Change to docker directory
cd "$(dirname "$0")/../docker" || exit 1

# List of compose files
COMPOSE_FILES=(
    "data-stores.yml"
    "tools.yml"
    "reverse-proxy.yml"
    # "observability.yml"
    # "services.yml"
)

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please copy .env.template to .env and configure it."
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

# Start services
echo "Running: docker-compose ${COMPOSE_ARGS[*]} up -d"
if docker-compose "${COMPOSE_ARGS[@]}" up -d; then
    echo "Environment started successfully!"
    echo "Use './stop.sh' to stop the environment"
else
    echo "Failed to start environment"
    exit 1
fi