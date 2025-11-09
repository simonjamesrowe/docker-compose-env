#!/bin/bash

# Restore backup script for MongoDB and Strapi uploads
# Restores from ~/Downloads/sjr-backup-31Oct2021/

set -e  # Exit on error

BACKUP_DIR="$HOME/Downloads/sjr-backup-31Oct2021"
MONGO_DUMP_DIR="$BACKUP_DIR/cms-production/cms-production"
FILES_DIR="$BACKUP_DIR/files"

echo "========================================="
echo "Backup Restore Script"
echo "========================================="
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not found at $BACKUP_DIR"
    exit 1
fi

if [ ! -d "$MONGO_DUMP_DIR" ]; then
    echo "Error: MongoDB dump directory not found at $MONGO_DUMP_DIR"
    exit 1
fi

if [ ! -d "$FILES_DIR" ]; then
    echo "Error: Files directory not found at $FILES_DIR"
    exit 1
fi

echo "Backup directory found: $BACKUP_DIR"
echo ""

# Check if MongoDB container is running
if ! docker ps | grep -q "mongodb"; then
    echo "Error: MongoDB container is not running. Please start services first with ./start.sh"
    exit 1
fi

# Check if Strapi container is running
if ! docker ps | grep -q "strapi-cms"; then
    echo "Error: Strapi CMS container is not running. Please start services first with ./start.sh"
    exit 1
fi

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

# Create temporary directory for files
TEMP_DIR=$(mktemp -d)
echo "Copying files to temporary directory: $TEMP_DIR"
cp -r "$FILES_DIR"/* "$TEMP_DIR/"

# Copy files to Strapi container
echo "Copying upload files to Strapi container..."
docker cp "$TEMP_DIR/." strapi-cms:/app/public/uploads/

# Clean up temporary directory
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

# Set proper permissions in container
echo "Setting proper permissions..."
docker exec strapi-cms chown -R node:node /app/public/uploads

echo "✓ Strapi files restore completed successfully"
echo ""

echo "========================================="
echo "Restore completed successfully!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - MongoDB database restored to 'strapi' database"
echo "  - $(ls -1 "$FILES_DIR" | wc -l | xargs) files restored to Strapi uploads"
echo ""
echo "You may need to restart the Strapi container for changes to take effect:"
echo "  docker restart strapi-cms"
echo ""
