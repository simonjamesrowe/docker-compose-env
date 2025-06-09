#!/bin/bash

# Start Docker Compose environment
echo "Starting Docker Compose environment..."

# List of compose files
COMPOSE_FILES=(
    "data-stores.yml"
    # "observability.yml"
    # "services.yml"
)

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found. Please copy .env.template to .env and configure it."
    exit 1
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