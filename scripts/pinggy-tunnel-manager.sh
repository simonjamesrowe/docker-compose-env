#!/bin/bash

##############################################################################
# Pinggy SSH Tunnel Manager
# Manages SSH tunnel lifecycle for Pinggy remote access with health monitoring
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_HELPER="$REPO_ROOT/scripts/lib/env.sh"
DOCKER_DIR="$REPO_ROOT/docker"

PID_FILE="/tmp/pinggy-tunnel.pid"
LOCK_FILE="/tmp/pinggy-tunnel.lock"
LOG_FILE="/tmp/pinggy-tunnel.log"
TUNNEL_URL_FILE="/tmp/pinggy-tunnel.url"

# Timeout for lock file (5 minutes)
LOCK_TIMEOUT=300

# Retry configuration
MAX_RETRIES=3
RETRY_DELAYS=(5 10 30)

##############################################################################
# Utility Functions
##############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_only() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

acquire_lock() {
    local timeout=$LOCK_TIMEOUT
    local start_time=$(date +%s)

    while [ -f "$LOCK_FILE" ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -gt $timeout ]; then
            log "Lock file expired, removing stale lock"
            rm -f "$LOCK_FILE"
            break
        fi

        sleep 1
    done

    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

cleanup_tunnel() {
    local pid=$1

    if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
        # Check if it's actually an SSH process
        if ps -p "$pid" | grep -q ssh; then
            log_only "Sending SIGTERM to process $pid"
            kill -TERM "$pid" 2>/dev/null || true

            # Wait 5 seconds for graceful shutdown
            sleep 5

            # Force kill if still running
            if ps -p "$pid" > /dev/null 2>&1; then
                log_only "Sending SIGKILL to process $pid"
                kill -9 "$pid" 2>/dev/null || true
                sleep 1
            fi
        fi
    fi
}

check_process_health() {
    local pid_to_check=$1

    # Verify PID exists
    if [ ! -f "$PID_FILE" ]; then
        return 1
    fi

    pid_to_check=$(cat "$PID_FILE" 2>/dev/null)
    if [ -z "$pid_to_check" ]; then
        return 1
    fi

    # Verify process is running and is SSH
    if ! ps -p "$pid_to_check" > /dev/null 2>&1; then
        return 1
    fi

    if ! ps -p "$pid_to_check" | grep -q ssh; then
        return 1
    fi

    return 0
}

check_network_health() {
    # Test local nginx is responding
    if curl -f -s -o /dev/null http://localhost:8080/health 2>/dev/null; then
        return 0
    fi

    # Fallback: test connection to localhost:8080
    if timeout 3 bash -c "echo > /dev/tcp/localhost/8080" 2>/dev/null; then
        return 0
    fi

    return 1
}

capture_tunnel_url() {
    # If we already have a URL, keep using it
    if [ -f "$TUNNEL_URL_FILE" ]; then
        cat "$TUNNEL_URL_FILE"
        return 0
    fi

    # Try to extract from SSH output (not available with -f background flag)
    # Pinggy provides URL in format: [remote] <URL>
    # For now, we'll construct it from token if needed
    echo "https://\${PINGGY_AUTH_TOKEN}.pinggy.io"
}

##############################################################################
# Tunnel Operations
##############################################################################

tunnel_start() {
    log "Starting Pinggy SSH tunnel..."

    # Load environment variables
    cd "$DOCKER_DIR" || exit 1
    if ! . "$ENV_HELPER" 2>/dev/null; then
        error "Failed to load environment helpers"
        return 1
    fi
    if ! load_env_files 2>/dev/null; then
        error "Failed to load environment files"
        return 1
    fi

    # Check if tunnel is already running
    if check_process_health; then
        log "Tunnel already running with PID $(cat "$PID_FILE")"
        return 0
    fi

    # Check prerequisites
    if [ -z "${PINGGY_AUTH_TOKEN}" ]; then
        error "PINGGY_AUTH_TOKEN not set in environment"
        return 1
    fi

    # Clean up stale PID file
    rm -f "$PID_FILE"

    # Start SSH tunnel in background
    # Using -f (background), -N (no command), ServerAliveInterval for stability
    ssh -f -N -p 443 -o ServerAliveInterval=60 -o ConnectionAttempts=5 \
        -o ConnectTimeout=10 -R 0:localhost:8080 \
        "${PINGGY_AUTH_TOKEN}@pro.pinggy.io" 2>/dev/null

    local ssh_status=$?
    if [ $ssh_status -ne 0 ]; then
        error "Failed to start SSH tunnel (exit code: $ssh_status)"
        return 1
    fi

    # Wait for SSH process to fully establish
    sleep 2

    # Find and save the SSH process PID
    # Note: pidof ssh might return multiple PIDs, get the most recent one
    local ssh_pid=$(pgrep -f "ssh.*pro.pinggy.io" | tail -1)

    if [ -z "$ssh_pid" ]; then
        error "Could not find SSH process after starting tunnel"
        return 1
    fi

    echo "$ssh_pid" > "$PID_FILE"
    log "Tunnel started with PID $ssh_pid"

    # Wait a bit for tunnel establishment
    sleep 3

    # Verify health
    if check_process_health && check_network_health; then
        log "Tunnel health verified"
        return 0
    else
        error "Tunnel failed health check after startup"
        cleanup_tunnel "$ssh_pid"
        rm -f "$PID_FILE"
        return 1
    fi
}

tunnel_stop() {
    log "Stopping Pinggy SSH tunnel..."

    if [ ! -f "$PID_FILE" ]; then
        log "No PID file found, tunnel not running"
        return 0
    fi

    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -z "$pid" ]; then
        rm -f "$PID_FILE"
        return 0
    fi

    cleanup_tunnel "$pid"
    rm -f "$PID_FILE" "$TUNNEL_URL_FILE" "$LOCK_FILE"
    log "Tunnel stopped"
    return 0
}

tunnel_restart() {
    log "Restarting Pinggy SSH tunnel..."
    tunnel_stop
    sleep 2
    tunnel_start
}

tunnel_check() {
    # Check if tunnel is healthy, restart if not
    if ! check_process_health; then
        log "Tunnel process not healthy, restarting..."
        tunnel_restart
        return $?
    fi

    if ! check_network_health; then
        log "Tunnel network not healthy, restarting..."
        tunnel_restart
        return $?
    fi

    log_only "Tunnel health check passed"
    return 0
}

tunnel_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Tunnel: NOT RUNNING"
        return 1
    fi

    local pid=$(cat "$PID_FILE" 2>/dev/null)

    if [ -z "$pid" ] || ! ps -p "$pid" > /dev/null 2>&1; then
        echo "Tunnel: NOT RUNNING (stale PID file)"
        rm -f "$PID_FILE"
        return 1
    fi

    if ! ps -p "$pid" | grep -q ssh; then
        echo "Tunnel: NOT RUNNING (PID is not SSH)"
        rm -f "$PID_FILE"
        return 1
    fi

    echo "Tunnel: RUNNING (PID: $pid)"

    if [ -f "$TUNNEL_URL_FILE" ]; then
        echo "Tunnel URL: $(cat "$TUNNEL_URL_FILE")"
    fi

    return 0
}

##############################################################################
# Main
##############################################################################

main() {
    local operation="${1:-status}"

    case "$operation" in
        start)
            acquire_lock
            tunnel_start
            local result=$?
            release_lock
            exit $result
            ;;
        stop)
            acquire_lock
            tunnel_stop
            local result=$?
            release_lock
            exit $result
            ;;
        restart)
            acquire_lock
            tunnel_restart
            local result=$?
            release_lock
            exit $result
            ;;
        check)
            acquire_lock
            tunnel_check
            local result=$?
            release_lock
            exit $result
            ;;
        status)
            tunnel_status
            exit $?
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|check|status}"
            exit 1
            ;;
    esac
}

main "$@"
