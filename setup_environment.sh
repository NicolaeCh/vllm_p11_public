#!/bin/bash
# setup_environment.sh
# Initial setup script for vLLM testing environment on IBM Power11
# Usage: bash setup_environment.sh

set -e  # Exit on error

echo "=================================================="
echo "vLLM Testing Environment Setup"
echo "IBM Power11 / AlmaLinux 9 / ppc64le"
echo "=================================================="
echo ""

# Configuration
USERNAME=$(whoami)
BASE_DIR="$HOME/vllm-project"
MODELS_DIR="$BASE_DIR/models"
CACHE_DIR="$BASE_DIR/cache/huggingface"
SCRIPTS_DIR="$BASE_DIR/scripts"
STREAMLIT_DIR="$BASE_DIR/streamlit"
LOGS_DIR="$BASE_DIR/logs"

echo "Step 1: Checking system prerequisites..."
echo "----------------------------------------"

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "ppc64le" ]; then
    echo "WARNING: Architecture is $ARCH, expected ppc64le"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for Podman or Docker
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    echo "✓ Podman found: $(podman --version)"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    echo "✓ Docker found: $(docker --version)"
else
    echo "✗ Neither Podman nor Docker found!"
    echo "  Installing Podman..."
    sudo dnf install -y podman
    CONTAINER_CMD="podman"
fi

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo "✓ Python found: $PYTHON_VERSION"
else
    echo "✗ Python3 not found!"
    echo "  Installing Python..."
    sudo dnf install -y python3 python3-pip
fi

echo ""
echo "Step 2: Creating directory structure..."
echo "----------------------------------------"

mkdir -p "$MODELS_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$STREAMLIT_DIR"
mkdir -p "$LOGS_DIR"

echo "✓ Created: $BASE_DIR"
echo "  ├── models/"
echo "  ├── cache/huggingface/"
echo "  ├── scripts/"
echo "  ├── streamlit/"
echo "  └── logs/"

echo ""
echo "Step 3: Setting up Python virtual environment..."
echo "------------------------------------------------"

cd "$BASE_DIR"

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

source venv/bin/activate

echo "✓ Virtual environment activated"

echo ""
echo "Step 4: Installing Python dependencies..."
echo "------------------------------------------"

cat > "$STREAMLIT_DIR/requirements.txt" << 'EOF'
streamlit>=1.32.0
openai>=1.0.0
requests>=2.31.0
pandas>=2.0.0
pyyaml>=6.0
huggingface-hub>=0.20.0
python-dotenv>=1.0.0
psutil>=5.9.0
EOF

pip install --upgrade pip
pip install -r "$STREAMLIT_DIR/requirements.txt"

echo "✓ Python packages installed"

echo ""
echo "Step 5: Pulling vLLM container image..."
echo "----------------------------------------"

$CONTAINER_CMD pull icr.io/ppc64le-oss/vllm-ppc64le:0.9.1

if [ $? -eq 0 ]; then
    echo "✓ Container image pulled successfully"
else
    echo "✗ Failed to pull container image"
    echo "  This may be due to network issues or registry access"
    echo "  You can retry this step later with:"
    echo "  $CONTAINER_CMD pull icr.io/ppc64le-oss/vllm-ppc64le:0.9.1"
fi

echo ""
echo "Step 6: Creating configuration file..."
echo "---------------------------------------"

cat > "$STREAMLIT_DIR/config.yaml" << EOF
# vLLM Testing Configuration
project_dir: $BASE_DIR
models_dir: $MODELS_DIR
cache_dir: $CACHE_DIR
logs_dir: $LOGS_DIR

# Container settings
container_name: vllm-test
container_port: 8000
host_bind: 127.0.0.1

# Default vLLM parameters
default_dtype: bfloat16
default_max_model_len: 4096
default_max_num_batched_tokens: 4096
default_max_num_seqs: 8

# CPU settings (adjust based on your system)
omp_num_threads: 16
cpu_threads_bind: all
kvcache_space: 8

# Streamlit settings
streamlit_port: 8501
streamlit_host: 0.0.0.0
EOF

echo "✓ Configuration file created: $STREAMLIT_DIR/config.yaml"

echo ""
echo "Step 7: Creating helper scripts..."
echo "-----------------------------------"

# Save the container command to a config file for scripts to use
echo "CONTAINER_CMD=$CONTAINER_CMD" > "$BASE_DIR/.env"
echo "BASE_DIR=$BASE_DIR" >> "$BASE_DIR/.env"

echo "✓ Environment configuration saved"

echo ""
echo "=================================================="
echo "Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Activate the Python environment:"
echo "   source $BASE_DIR/venv/bin/activate"
echo ""
echo "2. Download a test model (see model download guide)"
echo ""
echo "3. Start the Streamlit application:"
echo "   cd $STREAMLIT_DIR"
echo "   streamlit run vllm_chat.py"
echo ""
echo "Project directory: $BASE_DIR"
echo "Container command: $CONTAINER_CMD"
echo ""
echo "Documentation files will be created in: $BASE_DIR"
echo "=================================================="
