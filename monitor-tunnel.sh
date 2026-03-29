#!/bin/bash
#
# SSH Reverse Tunnel Monitor
# Checks tunnel health and auto-restarts if needed
#

set -euo pipefail

# Load configuration
CONFIG_FILE="${1:-./ssh-reverse-tunnel.conf}"
if [[ -f "$CONFIG_FILE" ]]; then
    set +u
    source "$CONFIG_FILE"
    set -u
fi

# Default configuration
REMOTE_HOST="${REMOTE_HOST:-jump_host}"
REMOTE_USER="${REMOTE_USER:-tunnel_user}"
REMOTE_PORT="${REMOTE_PORT:-22}"
TUNNEL_PORT="${TUNNEL_PORT:-2222}"
LOCAL_PORT="${LOCAL_PORT:-22}"
PID_FILE="${PID_FILE:-/var/run/ssh-reverse-tunnel.pid}"
SCRIPT_NAME="$(basename "$0")"

# Monitoring thresholds
RESTART_COOLDOWN="${RESTART_COOLDOWN:-300}"  # 5 minutes
COOLDOWN_FILE="/tmp/tunnel-restart-cooldown"

# Logging
log() {
    local level="$1"
    shift
    local message="$@"
    
    if command -v logger &> /dev/null; then
        logger -t "$SCRIPT_NAME" -p "user.${level,,}" "$message"
    fi
    
    if [[ -t 1 ]]; then
        case "$level" in
            ERROR)
                echo "[ERROR] $message" >&2
                ;;
            WARN)
                echo "[WARN] $message"
                ;;
            INFO)
                echo "[INFO] $message"
                ;;
        esac
    fi
}

# Check if process is running
is_process_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check if tunnel port is listening on remote host
is_port_listening() {
    # Try to connect to the tunnel port using nc or bash TCP
    if command -v nc &> /dev/null; then
        nc -z -w 2 "$REMOTE_HOST" "$TUNNEL_PORT" 2>/dev/null || return 1
    elif command -v timeout &> /dev/null; then
        # Fallback: use bash TCP connection
        timeout 2 bash -c "echo > /dev/tcp/$REMOTE_HOST/$TUNNEL_PORT" 2>/dev/null || return 1
    else
        # No tool available, just trust the process check
        return 0
    fi
    return 0
}

# Check if restart is on cooldown
is_on_cooldown() {
    if [[ -f "$COOLDOWN_FILE" ]]; then
        local last_restart=$(cat "$COOLDOWN_FILE")
        local current_time=$(date +%s)
        local time_since=$((current_time - last_restart))
        
        if [[ $time_since -lt $RESTART_COOLDOWN ]]; then
            log WARN "Restart cooldown active (${time_since}s/$RESTART_COOLDOWN). Skipping restart."
            return 0
        fi
    fi
    return 1
}

# Record restart time
record_restart() {
    echo "$(date +%s)" > "$COOLDOWN_FILE"
}

# Monitor tunnel health
monitor() {
    local tunnel_script="${2:-.}/ssh-reverse-tunnel.sh"
    
    if ! is_process_running; then
        log ERROR "Tunnel process is not running"
        
        if is_on_cooldown; then
            return 1
        fi
        
        log INFO "Attempting to restart tunnel..."
        if "$tunnel_script" start; then
            record_restart
            log INFO "Tunnel restarted successfully"
            return 0
        else
            log ERROR "Failed to restart tunnel"
            return 1
        fi
    fi
    
    # Process is running, check if port is actually listening
    if ! is_port_listening; then
        log ERROR "Tunnel process running but port $TUNNEL_PORT not listening on $REMOTE_HOST"
        
        if is_on_cooldown; then
            return 1
        fi
        
        log INFO "Attempting to restart tunnel..."
        "$tunnel_script" stop
        sleep 1
        if "$tunnel_script" start; then
            record_restart
            log INFO "Tunnel restarted successfully"
            return 0
        else
            log ERROR "Failed to restart tunnel"
            return 1
        fi
    fi
    
    # All checks passed
    log INFO "Tunnel health check passed"
    return 0
}

# Display usage
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
  -c, --config FILE          Configuration file (default: ./ssh-reverse-tunnel.conf)
  -t, --tunnel SCRIPT        Path to tunnel script (default: ./ssh-reverse-tunnel.sh)
  --cooldown SECONDS         Restart cooldown period (default: $RESTART_COOLDOWN)
  -h, --help                Display this help message

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME -c /etc/ssh-reverse-tunnel.conf
  $SCRIPT_NAME -c ./config.conf -t ./ssh-reverse-tunnel.sh

For use in cron:
  * * * * * /path/to/monitor-tunnel.sh -c /etc/ssh-reverse-tunnel.conf

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -t|--tunnel)
            TUNNEL_SCRIPT="$2"
            shift 2
            ;;
        --cooldown)
            RESTART_COOLDOWN="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    TUNNEL_SCRIPT="${TUNNEL_SCRIPT:-.}/ssh-reverse-tunnel.sh"
    monitor "$CONFIG_FILE" "$(dirname "$TUNNEL_SCRIPT")"
fi
