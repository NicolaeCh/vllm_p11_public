#!/bin/bash
# vllm_manager.sh
# Container lifecycle management for vLLM testing environment
# Usage: 
#   ./vllm_manager.sh start <model-path> [options]
#   ./vllm_manager.sh stop
#   ./vllm_manager.sh restart <model-path> [options]
#   ./vllm_manager.sh status
#   ./vllm_manager.sh logs

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
CONTAINER_NAME="vllm-test"
#CONTAINER_IMAGE="icr.io/ppc64le-oss/vllm-ppc64le:0.9.1"
CONTAINER_IMAGE="icr.io/ppc64le-oss/vllm-ppc64le:0.10.1.dev852.gee01645db.d20250827"
HOST_BIND="0.0.0.0"
CONTAINER_PORT="8000"
MODELS_DIR="$BASE_DIR/models"
CACHE_DIR="$BASE_DIR/cache/huggingface"
LOGS_DIR="$BASE_DIR/logs"
LOG_FILE="$LOGS_DIR/vllm_container.log"

# Default vLLM parameters (can be overridden)
DTYPE="${VLLM_DTYPE:-bfloat16}"
MAX_MODEL_LEN="${VLLM_MAX_MODEL_LEN:-4096}"
MAX_NUM_BATCHED_TOKENS="${VLLM_MAX_NUM_BATCHED_TOKENS:-4096}"
MAX_NUM_SEQS="${VLLM_MAX_NUM_SEQS:-8}"
OMP_NUM_THREADS="${VLLM_OMP_NUM_THREADS:-16}"
CPU_THREADS_BIND="${VLLM_CPU_THREADS_BIND:-all}"
KVCACHE_SPACE="${VLLM_KVCACHE_SPACE:-8}"

# Functions
function print_usage() {
    cat << EOF
vLLM Container Manager

Usage:
  $0 start <model-name-or-path> [options]
  $0 stop
  $0 restart <model-name-or-path> [options]
  $0 status
  $0 logs [--follow]
  $0 list-models

Commands:
  start       Start vLLM container with specified model
  stop        Stop running vLLM container
  restart     Restart container with new model
  status      Check container status
  logs        View container logs
  list-models List available local models

Options (for start/restart):
  --dtype <type>              Model dtype (default: bfloat16)
  --max-model-len <len>       Max context length (default: 4096)
  --max-batched-tokens <num>  Max batched tokens (default: 4096)
  --max-seqs <num>            Max concurrent sequences (default: 8)
  --omp-threads <num>         OpenMP threads (default: 16)
  --port <port>               Host port (default: 8000)

Examples:
  # Start with HuggingFace model
  $0 start ibm-granite/granite-3.3-8b-instruct

  # Start with local model
  $0 start granite-3.3-8b

  # Start with custom parameters
  $0 start llama-2-7b --max-model-len 8192 --omp-threads 32

  # Check status
  $0 status

  # View logs
  $0 logs --follow
EOF
}

function check_container_running() {
    $CONTAINER_CMD ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"
}

function stop_container() {
    echo "Stopping vLLM container..."
    if check_container_running; then
        $CONTAINER_CMD stop $CONTAINER_NAME
        $CONTAINER_CMD rm $CONTAINER_NAME
        echo "✓ Container stopped and removed"
    else
        echo "Container is not running"
        # Clean up if container exists but is not running
        if $CONTAINER_CMD ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
            $CONTAINER_CMD rm $CONTAINER_NAME
            echo "✓ Cleaned up stopped container"
        fi
    fi
}

function start_container() {
    local model_path="$1"
    shift

    if [ -z "$model_path" ]; then
        echo "Error: Model path required"
        print_usage
        exit 1
    fi

    # Parse additional options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dtype)
                DTYPE="$2"
                shift 2
                ;;
            --max-model-len)
                MAX_MODEL_LEN="$2"
                shift 2
                ;;
            --max-batched-tokens)
                MAX_NUM_BATCHED_TOKENS="$2"
                shift 2
                ;;
            --max-seqs)
                MAX_NUM_SEQS="$2"
                shift 2
                ;;
            --omp-threads)
                OMP_NUM_THREADS="$2"
                shift 2
                ;;
            --port)
                CONTAINER_PORT="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check if this is a local model or HuggingFace model
    if [ -d "$MODELS_DIR/$model_path" ]; then
        # Local model
        MODEL_MOUNT="-v $MODELS_DIR/$model_path:/model:ro,Z"
        MODEL_ARG="/model"
        MODEL_DISPLAY_NAME="$model_path"
        echo "Using local model: $MODELS_DIR/$model_path"
    elif [[ "$model_path" == *"/"* ]]; then
        # HuggingFace model ID (contains /)
        MODEL_MOUNT=""
        MODEL_ARG="$model_path"
        MODEL_DISPLAY_NAME="$model_path"
        echo "Using HuggingFace model: $model_path"
    else
        # Assume it's a local directory name
        if [ -d "$MODELS_DIR/$model_path" ]; then
            MODEL_MOUNT="-v $MODELS_DIR/$model_path:/model:ro,Z"
            MODEL_ARG="/model"
            MODEL_DISPLAY_NAME="$model_path"
            echo "Using local model: $MODELS_DIR/$model_path"
        else
            echo "Error: Model not found in $MODELS_DIR/$model_path"
            echo "If this is a HuggingFace model, use the full format: org/model-name"
            exit 1
        fi
    fi

    # Stop any existing container
    if check_container_running; then
        echo "Stopping existing container..."
        stop_container
    fi

    echo ""
    echo "Starting vLLM container..."
    echo "Model: $MODEL_ARG"
    echo "Display name: $MODEL_DISPLAY_NAME"
    echo "Port: $HOST_BIND:$CONTAINER_PORT"
    echo "Parameters:"
    echo "  dtype: $DTYPE"
    echo "  max-model-len: $MAX_MODEL_LEN"
    echo "  max-batched-tokens: $MAX_NUM_BATCHED_TOKENS"
    echo "  max-seqs: $MAX_NUM_SEQS"
    echo "  OMP threads: $OMP_NUM_THREADS"
    echo ""

    # Start container
    $CONTAINER_CMD run -d \
        --name $CONTAINER_NAME \
        -p $HOST_BIND:$CONTAINER_PORT:8000 \
        -v $CACHE_DIR:/root/.cache/huggingface \
        $MODEL_MOUNT \
        -e OMP_NUM_THREADS=$OMP_NUM_THREADS \
        -e VLLM_CPU_OMP_THREADS_BIND=$CPU_THREADS_BIND \
        -e VLLM_CPU_KVCACHE_SPACE=$KVCACHE_SPACE \
        $CONTAINER_IMAGE \
        --model $MODEL_ARG \
        --served-model-name "$MODEL_DISPLAY_NAME" \
        --host 0.0.0.0 \
        --port 8000 \
        --dtype $DTYPE \
        --max-model-len $MAX_MODEL_LEN \
        --max-num-batched-tokens $MAX_NUM_BATCHED_TOKENS \
        --max-num-seqs $MAX_NUM_SEQS \
        --disable-log-requests \
        --disable-fastapi-docs

    if [ $? -eq 0 ]; then
        echo "✓ Container started successfully"
        echo ""
        echo "Waiting for model to load (this may take several minutes)..."
        echo "Monitor progress with: $0 logs --follow"
        echo ""
        
        # Wait a bit and check if container is still running
        sleep 5
        if check_container_running; then
            echo "✓ Container is running"
            echo ""
            echo "API will be available at: http://$HOST_BIND:$CONTAINER_PORT"
            echo "Check readiness with: curl http://$HOST_BIND:$CONTAINER_PORT/v1/models"
        else
            echo "✗ Container stopped unexpectedly"
            echo "Check logs with: $0 logs"
            exit 1
        fi
    else
        echo "✗ Failed to start container"
        exit 1
    fi
}

function show_status() {
    echo "vLLM Container Status"
    echo "====================="
    echo ""
    
    if check_container_running; then
        echo "Status: RUNNING ✓"
        echo ""
        $CONTAINER_CMD ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        
        # Try to get model info from API
        echo "Checking API..."
        if curl -s -f http://$HOST_BIND:$CONTAINER_PORT/health > /dev/null 2>&1; then
            echo "API Status: READY ✓"
            echo ""
            echo "Available models:"
            curl -s http://$HOST_BIND:$CONTAINER_PORT/v1/models | python3 -m json.tool 2>/dev/null || echo "  (API not ready yet)"
        else
            echo "API Status: NOT READY (model may still be loading)"
        fi
    else
        echo "Status: NOT RUNNING ✗"
        
        # Check if container exists but is stopped
        if $CONTAINER_CMD ps -a --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
            echo ""
            echo "Container exists but is stopped. Last status:"
            $CONTAINER_CMD ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}"
        fi
    fi
}

function show_logs() {
    if [ "$1" == "--follow" ] || [ "$1" == "-f" ]; then
        echo "Following logs (Ctrl+C to exit)..."
        $CONTAINER_CMD logs -f $CONTAINER_NAME
    else
        echo "Last 100 lines of logs:"
        echo "======================="
        $CONTAINER_CMD logs --tail 100 $CONTAINER_NAME
        echo ""
        echo "Use '$0 logs --follow' to stream logs in real-time"
    fi
}

function list_models() {
    echo "Available local models:"
    echo "======================="
    
    if [ -d "$MODELS_DIR" ]; then
        cd "$MODELS_DIR"
        for model in */; do
            if [ -d "$model" ]; then
                model_name="${model%/}"
                if [ -f "$model/config.json" ]; then
                    echo "✓ $model_name"
                else
                    echo "? $model_name (incomplete - missing config.json)"
                fi
            fi
        done
    else
        echo "No models directory found"
    fi
    
    echo ""
    echo "To start with a local model:"
    echo "  $0 start <model-name>"
    echo ""
    echo "To start with a HuggingFace model:"
    echo "  $0 start org/model-name"
}

# Main command dispatcher
case "${1:-}" in
    start)
        shift
        start_container "$@"
        ;;
    stop)
        stop_container
        ;;
    restart)
        shift
        stop_container
        start_container "$@"
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    list-models)
        list_models
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
