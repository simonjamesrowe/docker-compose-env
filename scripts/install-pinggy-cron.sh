#!/bin/bash

##############################################################################
# Pinggy Tunnel Cron Installation
# Installs cron jobs for automatic Pinggy tunnel monitoring on macOS
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TUNNEL_MANAGER="$REPO_ROOT/scripts/pinggy-tunnel-manager.sh"

echo "Installing Pinggy tunnel monitoring cron jobs..."

# Check if tunnel manager exists
if [ ! -f "$TUNNEL_MANAGER" ]; then
    echo "Error: pinggy-tunnel-manager.sh not found at $TUNNEL_MANAGER"
    exit 1
fi

# Check if tunnel manager is executable
if [ ! -x "$TUNNEL_MANAGER" ]; then
    echo "Making tunnel manager executable..."
    chmod +x "$TUNNEL_MANAGER"
fi

# Get current crontab (if it exists)
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

# Define the cron jobs
HEALTH_CHECK_CRON="*/2 * * * * $TUNNEL_MANAGER check >> /tmp/pinggy-cron.log 2>&1"
RESTART_CRON="0 * * * * $TUNNEL_MANAGER restart >> /tmp/pinggy-cron.log 2>&1"

# Check if jobs already exist
if echo "$CURRENT_CRON" | grep -q "$TUNNEL_MANAGER check"; then
    echo "Health check cron job already installed"
else
    echo "Installing health check cron job (every 2 minutes)..."
    echo "$CURRENT_CRON
$HEALTH_CHECK_CRON" | grep -v '^$' | crontab -
fi

if echo "$CURRENT_CRON" | grep -q "$TUNNEL_MANAGER restart"; then
    echo "Restart cron job already installed"
else
    echo "Installing restart cron job (every hour)..."
    CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")
    echo "$CURRENT_CRON
$RESTART_CRON" | grep -v '^$' | crontab -
fi

echo ""
echo "✓ Pinggy tunnel monitoring cron jobs installed!"
echo ""
echo "Installed cron jobs:"
echo "  - Health check: every 2 minutes"
echo "  - Forced restart: every hour (at :00)"
echo ""
echo "Cron log file: /tmp/pinggy-cron.log"
echo "Tunnel log file: /tmp/pinggy-tunnel.log"
echo ""
echo "Verify installation with: crontab -l"
echo ""
