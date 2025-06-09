#!/bin/bash

# Stop Docker Compose environment
echo "Stopping Docker Compose environment..."

# List of compose files
COMPOSE_FILES=(
    "data-stores.yml"
    # "observability.yml"
    # "services.yml"
)

# Build the docker-compose command
DOCKER_COMPOSE_CMD="docker-compose"
for file in "${COMPOSE_FILES[@]}"; do
    if [ -f "$file" ]; then
        DOCKER_COMPOSE_CMD="$DOCKER_COMPOSE_CMD -f $file"
    fi
done

# Stop services
$DOCKER_COMPOSE_CMD down

echo "Environment stopped successfully!"