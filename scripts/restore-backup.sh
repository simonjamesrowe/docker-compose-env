#!/bin/bash

# Restore backup script for MongoDB and Strapi uploads
# Restores from a compressed archive produced by scripts/backup.sh

set -euo pipefail
shopt -s nullglob

DEFAULT_BASE_DIR="$HOME/backups"
USER_INPUT="${1:-}"
BACKUP_ARCHIVE=""
EXTRACT_DIR=""
RESTORE_ROOT=""

cleanup() {
    if [ -n "${EXTRACT_DIR:-}" ] && [ -d "$EXTRACT_DIR" ]; then
        rm -rf "$EXTRACT_DIR"
    fi
}
trap cleanup EXIT

find_latest_archive() {
    local search_dir="$1"
    local -a matches=("$search_dir"/strapi-backup-*.tar.gz)
    if [ ${#matches[@]} -eq 0 ]; then
        return 1
    fi
    ls -1t "${matches[@]}" | head -n1
}

if [ -z "$USER_INPUT" ]; then
    if ! BACKUP_ARCHIVE=$(find_latest_archive "$DEFAULT_BASE_DIR"); then
        echo "Error: No strapi-backup-*.tar.gz archives found in $DEFAULT_BASE_DIR"
        exit 1
    fi
    echo "Using latest archive from $DEFAULT_BASE_DIR:"
    echo "  $BACKUP_ARCHIVE"
elif [ -d "$USER_INPUT" ]; then
    if ! BACKUP_ARCHIVE=$(find_latest_archive "$USER_INPUT"); then
        echo "Error: No strapi-backup-*.tar.gz archives found in $USER_INPUT"
        exit 1
    fi
else
    BACKUP_ARCHIVE="$USER_INPUT"
fi

if [ ! -f "$BACKUP_ARCHIVE" ]; then
    echo "Error: Backup archive not found at $BACKUP_ARCHIVE"
    exit 1
fi

shopt -u nullglob

echo "Selected backup archive: $BACKUP_ARCHIVE"
EXTRACT_DIR=$(mktemp -d)
echo "Extracting archive to temporary directory: $EXTRACT_DIR"
tar -xzf "$BACKUP_ARCHIVE" -C "$EXTRACT_DIR"

for dir in "$EXTRACT_DIR"/*; do
    if [ -d "$dir" ]; then
        RESTORE_ROOT="$dir"
        break
    fi
done

if [ -z "$RESTORE_ROOT" ]; then
    echo "Error: Unable to find extracted backup directory."
    exit 1
fi

MONGO_DUMP_DIR="$RESTORE_ROOT/mongodb/strapi"
FILES_DIR="$RESTORE_ROOT/strapi-uploads"

echo "========================================="
echo "Backup Restore Script"
echo "========================================="
echo ""

# Validate extracted contents
if [ ! -d "$MONGO_DUMP_DIR" ]; then
    echo "Error: MongoDB dump directory not found at $MONGO_DUMP_DIR"
    exit 1
fi

if [ ! -d "$FILES_DIR" ]; then
    echo "Error: Files directory not found at $FILES_DIR"
    exit 1
fi

echo "Backup contents extracted from: $BACKUP_ARCHIVE"
echo "Mongo dump directory: $MONGO_DUMP_DIR"
echo "Uploads directory: $FILES_DIR"
echo ""

require_container() {
    local container="$1"
    if ! docker ps --format '{{.Names}}' | grep -Fxq "$container"; then
        echo "Error: Required container '$container' is not running."
        echo "       Please start services first with ./scripts/start.sh"
        exit 1
    fi
}

# Verify required containers are running
require_container "mongodb"
require_container "strapi-cms"

echo "Step 1: Restoring MongoDB Database..."
echo "---------------------------------------"

# Get MongoDB credentials from environment
cd "$(dirname "$0")/../docker" || exit 1
source .env

# Copy MongoDB dump into container
echo "Copying MongoDB dump to container..."
docker cp "$MONGO_DUMP_DIR" mongodb:/tmp/mongo-restore

# Restore MongoDB dump (excluding users-permissions collections)
echo "Restoring database: cms-production -> strapi"
echo "Excluding collections: users-permissions_*"
docker exec mongodb mongorestore \
    --host localhost \
    --port 27017 \
    --username "$MONGO_ROOT_USERNAME" \
    --password "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --db strapi \
    --nsExclude="strapi.users-permissions_*" \
    /tmp/mongo-restore

# Clean up temp files in container
echo "Cleaning up temporary files..."
docker exec mongodb rm -rf /tmp/mongo-restore

echo "✓ MongoDB restore completed successfully"
echo ""

echo "Step 2: Restoring Strapi Upload Files..."
echo "---------------------------------------"

# Copy files straight from extracted archive into Strapi container
echo "Copying upload files to Strapi container..."
docker cp "$FILES_DIR/." strapi-cms:/app/public/uploads/

# Set proper permissions in container
echo "Setting proper permissions..."
docker exec strapi-cms chown -R node:node /app/public/uploads

echo "✓ Strapi files restore completed successfully"
echo ""

FILE_COUNT=$(find "$FILES_DIR" -type f | wc -l | xargs)
echo "========================================="
echo "Restore completed successfully!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - MongoDB database restored to 'strapi' database"
echo "  - $FILE_COUNT files restored to Strapi uploads"
echo ""
echo "You may need to restart the Strapi container for changes to take effect:"
echo "  docker restart strapi-cms"
echo ""
