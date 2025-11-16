#!/bin/bash

# Backup script for MongoDB and Strapi uploads
# Creates a timestamped backup in a base directory then archives it

set -euo pipefail

BASE_BACKUP_DIR="$HOME/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="strapi-backup-$TIMESTAMP"
BACKUP_DIR="$BASE_BACKUP_DIR/$BACKUP_NAME"
MONGO_BACKUP_DIR="$BACKUP_DIR/mongodb"
FILES_BACKUP_DIR="$BACKUP_DIR/strapi-uploads"
ARCHIVE_PATH="$BASE_BACKUP_DIR/$BACKUP_NAME.tar.gz"

echo "========================================="
echo "Backup Script"
echo "========================================="
echo ""
echo "Base directory: $BASE_BACKUP_DIR"
echo "Backup will be staged at: $BACKUP_DIR"
echo "Final archive: $ARCHIVE_PATH"
echo ""

# Ensure base directory exists
mkdir -p "$BASE_BACKUP_DIR"

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

# Create backup directories
echo "Creating backup directories..."
mkdir -p "$MONGO_BACKUP_DIR"
mkdir -p "$FILES_BACKUP_DIR"

echo "Step 1: Backing up MongoDB Database..."
echo "---------------------------------------"

# Get MongoDB credentials from environment
cd "$(dirname "$0")/../docker" || exit 1
source .env

# Create MongoDB dump in container
echo "Creating MongoDB dump..."
docker exec mongodb mongodump \
    --host localhost \
    --port 27017 \
    --username "$MONGO_ROOT_USERNAME" \
    --password "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --db strapi \
    --out /tmp/mongo-backup

# Copy MongoDB dump from container to host
echo "Copying MongoDB dump from container..."
docker cp mongodb:/tmp/mongo-backup/strapi "$MONGO_BACKUP_DIR/"

# Clean up temp files in container
echo "Cleaning up temporary files in MongoDB container..."
docker exec mongodb rm -rf /tmp/mongo-backup

echo "✓ MongoDB backup completed successfully"
echo "  Location: $MONGO_BACKUP_DIR"
echo ""

echo "Step 2: Backing up Strapi Upload Files..."
echo "---------------------------------------"

# Copy files from Strapi container to host
echo "Copying upload files from Strapi container..."
docker cp strapi-cms:/app/public/uploads/. "$FILES_BACKUP_DIR/"

# Count files
FILE_COUNT=$(ls -1 "$FILES_BACKUP_DIR" | wc -l | xargs)

echo "✓ Strapi files backup completed successfully"
echo "  Location: $FILES_BACKUP_DIR"
echo "  Files backed up: $FILE_COUNT"
echo ""

echo "========================================="
echo "Backup completed successfully!"
echo "========================================="
echo ""
# Compress staged backup
echo "Compressing backup into: $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$BASE_BACKUP_DIR" "$BACKUP_NAME"
rm -rf "$BACKUP_DIR"
echo "✓ Compression complete; cleaned up staging directory."
echo ""
echo "Summary:"
echo "  - Archive: $ARCHIVE_PATH"
echo "  - MongoDB database (pre-archive): $MONGO_BACKUP_DIR"
echo "  - Strapi uploads (pre-archive): $FILES_BACKUP_DIR ($FILE_COUNT files)"
echo ""
echo "To restore this backup later, run scripts/restore-backup.sh."
echo "It will automatically use the latest archive in $BASE_BACKUP_DIR"
echo "or you can pass a specific archive path if needed."
echo ""
