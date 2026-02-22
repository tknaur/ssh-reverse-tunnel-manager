#!/bin/bash
#
# SSH Reverse Tunnel Manager
# Establishes reverse SSH tunnel via jump host to allow internet access to home computer
#

set -euo pipefail

# Default configuration
REMOTE_HOST="${REMOTE_HOST:-jump_host}"
REMOTE_USER="${REMOTE_USER:-tunnel_user}"
REMOTE_PORT="${REMOTE_PORT:-22}"
TUNNEL_PORT="${TUNNEL_PORT:-2222}"
LOCAL_PORT="${LOCAL_PORT:-22}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_rsa}"
LOG_FILE="${LOG_FILE:-/var/log/ssh-reverse-tunnel.log}"
PID_FILE="${PID_FILE:-/var/run/ssh-reverse-tunnel.pid}"
SSH_CLIENT="${SSH_CLIENT:-openssh}"
DROPBEAR_OPTS="${DROPBEAR_OPTS:--y}"

# Script name for logging
SCRIPT_NAME="$(basename "$0")"

# Color output (disabled when not a TTY)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Logging function
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to syslog if available
    if command -v logger &> /dev/null; then
        logger -t "$SCRIPT_NAME" -p "user.${level,,}" "$message"
    fi
    
    # Also print to console if interactive
    if [[ -t 1 ]]; then
        case "$level" in
            ERROR)
                echo -e "${RED}[ERROR]${NC} $message" >&2
                ;;
            WARN)
                echo -e "${YELLOW}[WARN]${NC} $message"
                ;;
            INFO)
                echo -e "${GREEN}[INFO]${NC} $message"
                ;;
            DEBUG)
                echo "[DEBUG] $message"
                ;;
        esac
    fi
}

# Validate prerequisites
validate_prerequisites() {
    log INFO "Validating prerequisites..."
    
    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        log ERROR "SSH key not found: $SSH_KEY"
        return 1
    fi
    
    # Check if SSH key is readable
    if [[ ! -r "$SSH_KEY" ]]; then
        log ERROR "SSH key is not readable: $SSH_KEY"
        return 1
    fi
    
    # Check if selected SSH client command exists
    local ssh_cmd=""
    case "$SSH_CLIENT" in
        openssh)
            ssh_cmd="ssh"
            ;;
        dropbear)
            ssh_cmd="dbclient"
            ;;
        *)
            log ERROR "Unknown SSH_CLIENT: $SSH_CLIENT (must be 'openssh' or 'dropbear')"
            return 1
            ;;
    esac
    
    if ! command -v "$ssh_cmd" &> /dev/null; then
        log ERROR "$ssh_cmd command not found (SSH_CLIENT=$SSH_CLIENT)"
        return 1
    fi
    
    log INFO "Prerequisites validated successfully (using $SSH_CLIENT)"
    return 0
}

# Start OpenSSH reverse tunnel
start_tunnel_openssh() {
    ssh -N \
        -R "$TUNNEL_PORT:localhost:$LOCAL_PORT" \
        -i "$SSH_KEY" \
        -p "$REMOTE_PORT" \
        -o StrictHostKeyChecking=accept-new \
        -o ServerAliveInterval=60 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        "$REMOTE_USER@$REMOTE_HOST" > /dev/null 2>&1 &
}

# Start Dropbear reverse tunnel
start_tunnel_dropbear() {
    dbclient -N \
        -R "$TUNNEL_PORT:localhost:$LOCAL_PORT" \
        -i "$SSH_KEY" \
        -p "$REMOTE_PORT" \
        $DROPBEAR_OPTS \
        "$REMOTE_USER@$REMOTE_HOST" > /dev/null 2>&1 &
}

# Check if tunnel is already running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # PID file exists but process is not running
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Start the reverse tunnel using configured SSH client
start_tunnel()
{
    log INFO "Starting SSH reverse tunnel..."
    
    if is_running; then
        log WARN "Tunnel is already running (PID: $(cat "$PID_FILE"))"
        return 0
    fi
    
    # Validate prerequisites
    if ! validate_prerequisites; then
        log ERROR "Prerequisites validation failed"
        return 1
    fi
    
    # Create PID directory if needed
    local pid_dir=$(dirname "$PID_FILE")
    if [[ ! -d "$pid_dir" ]]; then
        mkdir -p "$pid_dir" 2>/dev/null || true
    fi
    
    log INFO "Establishing tunnel: localhost:$LOCAL_PORT -> $REMOTE_HOST:$TUNNEL_PORT (using $SSH_CLIENT)"
    
    # Start tunnel based on selected SSH client
    case "$SSH_CLIENT" in
        openssh)
            start_tunnel_openssh
            ;;
        dropbear)
            start_tunnel_dropbear
            ;;
    esac
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    log INFO "SSH tunnel started with PID: $pid"
    
    # Give it a moment to verify the connection works
    sleep 2
    
    if is_running; then
        log INFO "Tunnel established successfully"
        return 0
    else
        log ERROR "Tunnel failed to establish. Check logs for details."
        rm -f "$PID_FILE"
        return 1
    fi
}

# Stop the reverse tunnel
stop_tunnel() {
    log INFO "Stopping SSH reverse tunnel..."
    
    if ! is_running; then
        log WARN "Tunnel is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    log INFO "Terminating tunnel process (PID: $pid)"
    
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait up to 5 seconds for graceful shutdown
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 5 ]]; do
        sleep 1
        ((count++))
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        log WARN "Process did not terminate gracefully, force killing..."
        kill -9 "$pid" 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
    log INFO "Tunnel stopped"
    return 0
}

# Check status of the tunnel
status_tunnel() {
    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo "Tunnel is running (PID: $pid)"
        echo "Configuration:"
        echo "  Remote Host: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
        echo "  Tunnel Port: $TUNNEL_PORT"
        echo "  Local Port: $LOCAL_PORT"
        return 0
    else
        echo "Tunnel is not running"
        return 1
    fi
}

# Display usage
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [COMMAND] [OPTIONS]

Commands:
  start       Start the SSH reverse tunnel
  stop        Stop the SSH reverse tunnel
  restart     Restart the tunnel
  status      Check tunnel status

Environment Variables (with defaults):
  REMOTE_HOST     Jump host hostname (default: $REMOTE_HOST)
  REMOTE_USER     Jump host user (default: $REMOTE_USER)
  REMOTE_PORT     Jump host SSH port (default: $REMOTE_PORT)
  TUNNEL_PORT     Port on jump host for reverse tunnel (default: $TUNNEL_PORT)
  LOCAL_PORT      Local port to forward (default: $LOCAL_PORT)
  SSH_KEY         Path to SSH private key (default: $SSH_KEY)
  SSH_CLIENT      SSH client to use: 'openssh' or 'dropbear' (default: $SSH_CLIENT)
  DROPBEAR_OPTS   Additional dbclient options (default: $DROPBEAR_OPTS)
  PID_FILE        PID file location (default: $PID_FILE)

Examples:
  $SCRIPT_NAME start
  $SCRIPT_NAME stop
  $SCRIPT_NAME status
  
  # Override configuration
  SSH_KEY=/home/user/.ssh/custom_key $SCRIPT_NAME start
  TUNNEL_PORT=2222 $SCRIPT_NAME start
  
  # Use Dropbear SSH client
  SSH_CLIENT=dropbear $SCRIPT_NAME start

EOF
}

# Main command dispatcher
main() {
    local command="${1:-}"
    
    case "$command" in
        start)
            start_tunnel
            ;;
        stop)
            stop_tunnel
            ;;
        restart)
            stop_tunnel
            sleep 1
            start_tunnel
            ;;
        status)
            status_tunnel
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
