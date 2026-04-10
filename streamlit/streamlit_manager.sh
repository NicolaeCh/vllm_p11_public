#!/bin/bash
# streamlit_manager.sh
# Background process manager for vLLM Streamlit application
# Usage:
#   ./streamlit_manager.sh start
#   ./streamlit_manager.sh stop
#   ./streamlit_manager.sh restart
#   ./streamlit_manager.sh status
#   ./streamlit_manager.sh logs [--follow]

set -e

# Load environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$BASE_DIR/.env" ]; then
    source "$BASE_DIR/.env"
else
    echo "Error: Environment not configured. Run setup_environment.sh first."
    exit 1
fi

# Configuration
STREAMLIT_DIR="$BASE_DIR/streamlit"
STREAMLIT_APP="vllm_chat.py"
PID_FILE="$BASE_DIR/logs/streamlit.pid"
LOG_FILE="$BASE_DIR/logs/streamlit.log"
VENV_DIR="$BASE_DIR/venv"

# Streamlit settings
STREAMLIT_PORT="${STREAMLIT_PORT:-8501}"
STREAMLIT_HOST="${STREAMLIT_HOST:-0.0.0.0}"

# Functions
function print_usage() {
    cat << EOF
Streamlit Application Manager

Usage:
  $0 start [--port PORT] [--host HOST]
  $0 stop
  $0 restart [--port PORT] [--host HOST]
  $0 status
  $0 logs [--follow]

Commands:
  start      Start Streamlit application in background
  stop       Stop running Streamlit application
  restart    Restart Streamlit application
  status     Check application status
  logs       View application logs

Options:
  --port PORT    Port to run Streamlit on (default: 8501)
  --host HOST    Host to bind to (default: 127.0.0.1)

Examples:
  # Start application
  $0 start

  # Start on different port
  $0 start --port 8502

  # Check status
  $0 status

  # View logs
  $0 logs --follow
EOF
}

function check_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        else
            # PID file exists but process is dead
            rm -f "$PID_FILE"
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

function get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    fi
}

function start_streamlit() {
    local port="$STREAMLIT_PORT"
    local host="$STREAMLIT_HOST"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                port="$2"
                shift 2
                ;;
            --host)
                host="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if check_running; then
        echo "Streamlit is already running (PID: $(get_pid))"
        echo "Use '$0 restart' to restart or '$0 stop' to stop first"
        exit 1
    fi
    
    # Check if venv exists
    if [ ! -d "$VENV_DIR" ]; then
        echo "Error: Virtual environment not found at $VENV_DIR"
        echo "Run setup_environment.sh first"
        exit 1
    fi
    
    # Check if app exists
    if [ ! -f "$STREAMLIT_DIR/$STREAMLIT_APP" ]; then
        echo "Error: Streamlit app not found at $STREAMLIT_DIR/$STREAMLIT_APP"
        exit 1
    fi
    
    echo "Starting Streamlit application..."
    echo "Host: $host"
    echo "Port: $port"
    echo "Log: $LOG_FILE"
    
    # Activate virtual environment and start Streamlit in background
    cd "$STREAMLIT_DIR"
    
    nohup "$VENV_DIR/bin/streamlit" run "$STREAMLIT_APP" \
        --server.port "$port" \
        --server.address "$host" \
        --server.headless true \
        --browser.gatherUsageStats false \
        --server.enableCORS false \
        --server.enableXsrfProtection false \
        > "$LOG_FILE" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 2
    
    if check_running; then
        echo "✓ Streamlit started successfully"
        echo ""
        echo "PID: $pid"
        echo "Access: http://$host:$port"
        echo ""
        echo "Management commands:"
        echo "  Status: $0 status"
        echo "  Logs:   $0 logs --follow"
        echo "  Stop:   $0 stop"
    else
        echo "✗ Failed to start Streamlit"
        echo "Check logs: tail -f $LOG_FILE"
        rm -f "$PID_FILE"
        exit 1
    fi
}

function stop_streamlit() {
    if ! check_running; then
        echo "Streamlit is not running"
        # Clean up stale PID file
        rm -f "$PID_FILE"
        return 0
    fi
    
    local pid=$(get_pid)
    echo "Stopping Streamlit (PID: $pid)..."
    
    # Try graceful shutdown first
    kill "$pid" 2>/dev/null || true
    
    # Wait up to 10 seconds for graceful shutdown
    local count=0
    while [ $count -lt 10 ]; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            echo "✓ Streamlit stopped successfully"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    # Force kill if still running
    echo "Force stopping..."
    kill -9 "$pid" 2>/dev/null || true
    sleep 1
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo "✓ Streamlit stopped"
        rm -f "$PID_FILE"
    else
        echo "✗ Failed to stop Streamlit"
        exit 1
    fi
}

function show_status() {
    echo "Streamlit Application Status"
    echo "============================="
    echo ""
    
    if check_running; then
        local pid=$(get_pid)
        echo "Status: RUNNING ✓"
        echo "PID: $pid"
        echo ""
        
        # Try to determine port from process
        local port_info=$(lsof -Pan -p "$pid" -i 2>/dev/null | grep LISTEN || echo "")
        if [ -n "$port_info" ]; then
            echo "Listening on:"
            echo "$port_info" | awk '{print "  " $9}'
        fi
        
        # Check if accessible
        echo ""
        echo "Testing connectivity..."
        if curl -s -f "http://$STREAMLIT_HOST:$STREAMLIT_PORT" > /dev/null 2>&1; then
            echo "✓ Application is accessible at http://$STREAMLIT_HOST:$STREAMLIT_PORT"
        else
            echo "⚠ Application may still be starting up"
            echo "  Check logs: $0 logs --follow"
        fi
        
        # Show resource usage
        echo ""
        echo "Resource usage:"
        ps -p "$pid" -o pid,ppid,%cpu,%mem,vsz,rss,etime,cmd --no-headers
        
    else
        echo "Status: NOT RUNNING ✗"
        echo ""
        echo "Start with: $0 start"
    fi
    
    echo ""
    echo "Log file: $LOG_FILE"
    echo "PID file: $PID_FILE"
}

function show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file found at $LOG_FILE"
        exit 1
    fi
    
    if [ "$1" == "--follow" ] || [ "$1" == "-f" ]; then
        echo "Following logs (Ctrl+C to exit)..."
        tail -f "$LOG_FILE"
    else
        echo "Last 50 lines of logs:"
        echo "======================"
        tail -n 50 "$LOG_FILE"
        echo ""
        echo "Use '$0 logs --follow' to stream logs in real-time"
    fi
}

function restart_streamlit() {
    echo "Restarting Streamlit application..."
    stop_streamlit
    sleep 2
    start_streamlit "$@"
}

# Main command dispatcher
case "${1:-}" in
    start)
        shift
        start_streamlit "$@"
        ;;
    stop)
        stop_streamlit
        ;;
    restart)
        shift
        restart_streamlit "$@"
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
