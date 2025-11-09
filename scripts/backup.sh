#!/bin/bash

# Backup script for MongoDB and Strapi uploads
# Creates a timestamped backup in ~/Downloads/

set -e  # Exit on error

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$HOME/Downloads/strapi-backup-$TIMESTAMP"
MONGO_BACKUP_DIR="$BACKUP_DIR/mongodb"
FILES_BACKUP_DIR="$BACKUP_DIR/strapi-uploads"

echo "========================================="
echo "Backup Script"
echo "========================================="
echo ""
echo "Backup will be created at: $BACKUP_DIR"
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
echo "Summary:"
echo "  - Backup location: $BACKUP_DIR"
echo "  - MongoDB database: $MONGO_BACKUP_DIR"
echo "  - Strapi uploads: $FILES_BACKUP_DIR ($FILE_COUNT files)"
echo ""
echo "To restore this backup, update the BACKUP_DIR variable in restore-backup.sh"
echo "to point to: $BACKUP_DIR"
echo ""
