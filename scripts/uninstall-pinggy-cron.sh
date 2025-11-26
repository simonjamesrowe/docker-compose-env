#!/bin/bash

##############################################################################
# Pinggy Tunnel Cron Uninstallation
# Removes cron jobs for Pinggy tunnel monitoring
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TUNNEL_MANAGER="$REPO_ROOT/scripts/pinggy-tunnel-manager.sh"

echo "Removing Pinggy tunnel monitoring cron jobs..."

# Get current crontab
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

if [ -z "$CURRENT_CRON" ]; then
    echo "No crontab found, nothing to uninstall"
    exit 0
fi

# Check if any Pinggy jobs exist
if ! echo "$CURRENT_CRON" | grep -q "$TUNNEL_MANAGER"; then
    echo "No Pinggy cron jobs found to uninstall"
    exit 0
fi

# Remove the Pinggy cron jobs
echo "$CURRENT_CRON" | grep -v "$TUNNEL_MANAGER" | crontab - 2>/dev/null || true

echo "✓ Pinggy tunnel monitoring cron jobs removed!"
echo ""
echo "Verify removal with: crontab -l"
echo ""
echo "Optional: Clean up log files"
echo "  rm /tmp/pinggy-cron.log /tmp/pinggy-tunnel.log"
echo ""
