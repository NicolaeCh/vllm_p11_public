#!/bin/bash
# download_model.sh
# Download models from HuggingFace Hub
# Usage: ./download_model.sh <model-id> [token]

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$BASE_DIR/.env" ]; then
    source "$BASE_DIR/.env"
else
    echo "Error: Environment not configured. Run setup_environment.sh first."
    exit 1
fi

MODELS_DIR="$BASE_DIR/models"
CACHE_DIR="$BASE_DIR/cache/huggingface"

function print_usage() {
    cat << EOF
HuggingFace Model Download Utility

Usage:
  $0 <model-id> [hf-token]

Arguments:
  model-id    HuggingFace model identifier (e.g., ibm-granite/granite-3.3-8b-instruct)
  hf-token    Optional HuggingFace token for private/gated models

Examples:
  # Download public model
  $0 ibm-granite/granite-3.3-8b-instruct

  # Download with authentication
  $0 meta-llama/Llama-2-7b-chat-hf hf_xxxxxxxxxxxxx

  # Download specific revision
  HF_REVISION=main $0 mistralai/Mistral-7B-Instruct-v0.2

Environment Variables:
  HF_TOKEN      HuggingFace token (alternative to command line arg)
  HF_REVISION   Specific revision/branch to download (default: main)
  HF_CACHE_DIR  Custom cache directory

Notes:
  - Models are downloaded to: $MODELS_DIR
  - Cache is stored in: $CACHE_DIR
  - Large models may take significant time to download
  - Requires internet connection
EOF
}

function check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        echo "Error: Python3 not found"
        exit 1
    fi

    # Check if huggingface-hub is installed
    if ! python3 -c "import huggingface_hub" 2>/dev/null; then
        echo "Installing huggingface-hub..."
        pip install huggingface-hub
    fi
}

function download_model() {
    local model_id="$1"
    local hf_token="${2:-${HF_TOKEN:-}}"
    local revision="${HF_REVISION:-main}"
    
    if [ -z "$model_id" ]; then
        echo "Error: Model ID required"
        print_usage
        exit 1
    fi

    # Extract model name for local directory
    local model_name=$(echo "$model_id" | sed 's/\//-/g')
    local target_dir="$MODELS_DIR/$model_name"

    echo "=================================================="
    echo "Downloading Model from HuggingFace Hub"
    echo "=================================================="
    echo ""
    echo "Model ID: $model_id"
    echo "Revision: $revision"
    echo "Target:   $target_dir"
    echo "Cache:    $CACHE_DIR"
    echo ""

    # Check if model already exists
    if [ -d "$target_dir" ] && [ -f "$target_dir/config.json" ]; then
        echo "⚠ Model already exists at $target_dir"
        read -p "Re-download? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Download cancelled"
            exit 0
        fi
        rm -rf "$target_dir"
    fi

    mkdir -p "$target_dir"
    mkdir -p "$CACHE_DIR"

    echo "Starting download..."
    echo "This may take a while for large models..."
    echo ""

    # Create Python download script
    python3 << EOF
import os
import sys
from pathlib import Path
from huggingface_hub import snapshot_download

model_id = "$model_id"
target_dir = "$target_dir"
cache_dir = "$CACHE_DIR"
token = "$hf_token" if "$hf_token" else None
revision = "$revision"

try:
    # Download model
    print(f"Downloading {model_id}...")
    print(f"Target: {target_dir}")
    
    snapshot_download(
        repo_id=model_id,
        local_dir=target_dir,
        cache_dir=cache_dir,
        token=token,
        revision=revision,
        resume_download=True,
        local_dir_use_symlinks=False,
    )
    
    print("\n✓ Download complete!")
    print(f"\nModel saved to: {target_dir}")
    
    # Verify essential files
    config_file = Path(target_dir) / "config.json"
    if config_file.exists():
        print("✓ config.json found")
    else:
        print("⚠ config.json not found - model may be incomplete")
    
    # Check for model files
    model_files = list(Path(target_dir).glob("*.safetensors")) + \
                  list(Path(target_dir).glob("*.bin"))
    if model_files:
        print(f"✓ Found {len(model_files)} model weight file(s)")
        total_size = sum(f.stat().st_size for f in model_files)
        print(f"  Total size: {total_size / 1024**3:.2f} GB")
    else:
        print("⚠ No model weight files found")
    
except Exception as e:
    print(f"\n✗ Download failed: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        echo ""
        echo "=================================================="
        echo "Download Successful!"
        echo "=================================================="
        echo ""
        echo "Model location: $target_dir"
        echo ""
        echo "To use this model with vLLM:"
        echo "  ./vllm_manager.sh start $model_name"
        echo ""
        echo "Or in Streamlit, select: $model_name"
        echo ""
    else
        echo ""
        echo "✗ Download failed"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check internet connection"
        echo "2. Verify model ID is correct"
        echo "3. For gated models, ensure you have:"
        echo "   - Accepted the model's terms on HuggingFace"
        echo "   - Provided a valid token"
        echo "4. Check disk space"
        exit 1
    fi
}

# Main
case "${1:-}" in
    -h|--help)
        print_usage
        exit 0
        ;;
    "")
        echo "Error: Model ID required"
        print_usage
        exit 1
        ;;
    *)
        check_dependencies
        download_model "$@"
        ;;
esac
