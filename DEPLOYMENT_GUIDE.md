# vLLM Deployment Guide - IBM Power11
## Complete Step-by-Step Instructions

---

## TABLE OF CONTENTS
1. [Initial Setup](#initial-setup)
2. [Manual Model Download](#manual-model-download)
3. [Container Operations](#container-operations)
4. [Streamlit Application](#streamlit-application)
5. [Testing and Validation](#testing-and-validation)
6. [Troubleshooting](#troubleshooting)
7. [Performance Tuning](#performance-tuning)

---

## INITIAL SETUP

### Step 1: Prepare Your System

```bash
# Update system packages
sudo dnf update -y

# Install required packages
sudo dnf install -y podman python3 python3-pip git

# Verify installation
podman --version
python3 --version
```

### Step 2: Run Setup Script

```bash
# Navigate to your home directory
cd ~

# Create project directory structure and set up environment
bash setup_environment.sh
```

This script will:
- Create directory structure in `~/vllm-project/`
- Set up Python virtual environment
- Install Python dependencies
- Pull the vLLM container image
- Create configuration files

**Expected output:**
```
✓ Podman found: podman version X.X.X
✓ Python found: 3.9.X
✓ Virtual environment created
✓ Python packages installed
✓ Container image pulled successfully
✓ Configuration file created
```

### Step 3: Install Scripts

```bash
# Copy scripts to project directory
cd ~/vllm-project

# Make scripts executable
chmod +x scripts/vllm_manager.sh
chmod +x scripts/download_model.sh
```

**Directory structure after setup:**
```
~/vllm-project/
├── models/              # Model storage
├── cache/               # HuggingFace cache
├── scripts/             # Management scripts
│   ├── vllm_manager.sh
│   └── download_model.sh
├── streamlit/           # Streamlit app
│   ├── vllm_chat.py
│   ├── config.yaml
│   └── requirements.txt
├── logs/                # Log files
└── venv/                # Python virtual environment
```

---

## MANUAL MODEL DOWNLOAD

### Method 1: Using Download Script (Recommended)

```bash
# Activate virtual environment
cd ~/vllm-project
source venv/bin/activate

# Download a model
./scripts/download_model.sh ibm-granite/granite-3.3-8b-instruct
```

**For gated/private models:**
```bash
# Set your HuggingFace token
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxx"

# Download with authentication
./scripts/download_model.sh meta-llama/Llama-2-7b-chat-hf $HF_TOKEN
```

### Method 2: Using Python Directly

```bash
# Activate virtual environment
source ~/vllm-project/venv/bin/activate

# Run Python script
python3 << 'EOF'
from huggingface_hub import snapshot_download
from pathlib import Path

model_id = "ibm-granite/granite-3.3-8b-instruct"
target_dir = Path.home() / "vllm-project/models/ibm-granite-granite-3.3-8b-instruct"

print(f"Downloading {model_id}...")
snapshot_download(
    repo_id=model_id,
    local_dir=target_dir,
    local_dir_use_symlinks=False,
)
print(f"✓ Model downloaded to {target_dir}")
EOF
```

### Method 3: Using HuggingFace CLI

```bash
# Install HuggingFace CLI
pip install -U "huggingface_hub[cli]"

# Login (for gated models)
huggingface-cli login

# Download model
huggingface-cli download \
    ibm-granite/granite-3.3-8b-instruct \
    --local-dir ~/vllm-project/models/ibm-granite-granite-3.3-8b-instruct \
    --local-dir-use-symlinks False
```

### Method 4: Using Git LFS

```bash
# Install git-lfs
sudo dnf install -y git-lfs
git lfs install

# Clone model repository
cd ~/vllm-project/models
git clone https://huggingface.co/ibm-granite/granite-3.3-8b-instruct
```

### Verify Downloaded Model

```bash
# Check model structure
ls -lh ~/vllm-project/models/ibm-granite-granite-3.3-8b-instruct/

# Should see:
# - config.json
# - tokenizer.json
# - tokenizer_config.json
# - *.safetensors or *.bin files
```

### List Available Models

```bash
cd ~/vllm-project
./scripts/vllm_manager.sh list-models
```

---

## CONTAINER OPERATIONS

### Starting vLLM Server

**Start with local model:**
```bash
cd ~/vllm-project
./scripts/vllm_manager.sh start ibm-granite-3.3-8b-instruct
```

**Start with HuggingFace model (will download if not cached):**
```bash
./scripts/vllm_manager.sh start ibm-granite/granite-3.3-8b-instruct
```

**Start with custom parameters:**
```bash
./scripts/vllm_manager.sh start ibm-granite-3.3-8b-instruct \
    --max-model-len 8192 \
    --max-batched-tokens 8192 \
    --omp-threads 32 \
    --dtype bfloat16
```

**Available parameters:**
- `--dtype`: Model precision (bfloat16, float16, auto)
- `--max-model-len`: Maximum context length (default: 4096)
- `--max-batched-tokens`: Batch size (default: 4096)
- `--max-seqs`: Max concurrent sequences (default: 8)
- `--omp-threads`: OpenMP threads (default: 16)
- `--port`: Server port (default: 8000)

### Monitoring Container

**Check status:**
```bash
./scripts/vllm_manager.sh status
```

**View logs:**
```bash
# Last 100 lines
./scripts/vllm_manager.sh logs

# Follow logs in real-time
./scripts/vllm_manager.sh logs --follow
```

**Test API endpoint:**
```bash
# Check health
curl http://127.0.0.1:8000/health

# List models
curl http://127.0.0.1:8000/v1/models

# Test completion
curl http://127.0.0.1:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-3.3-8b-instruct",
    "prompt": "Hello, how are you?",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### Stopping and Switching Models

**Stop server:**
```bash
./scripts/vllm_manager.sh stop
```

**Switch to different model:**
```bash
# This will stop current model and start new one
./scripts/vllm_manager.sh restart llama-2-7b-chat
```

---

## STREAMLIT APPLICATION

### Starting Streamlit

```bash
# Activate virtual environment
cd ~/vllm-project
source venv/bin/activate

# Start Streamlit application . put 0.0.0.0 to allow remote access
cd streamlit
streamlit run vllm_chat.py --server.port 8501 --server.address 127.0.0.1
```

**Access the UI:**
- Open browser to: http://localhost:8501
- Or from remote: http://<server-ip>:8501

### Application Features

**Sidebar - Configuration:**
- **Server Status**: Shows if vLLM is running and which model is active
- **Model Management**: Select and load models from local library
- **Model Download**: Download new models from HuggingFace
- **Inference Parameters**: 
  - Temperature (0.0 - 2.0)
  - Max Tokens (128 - 4096)
  - Top P, Top K
  - Presence/Frequency Penalties
- **Performance Monitoring**: Real-time metrics display

**Main Chat Interface:**
- Chat-based interaction with loaded model
- Streaming responses
- Performance metrics per response:
  - TTFT (Time to First Token)
  - TPS (Tokens Per Second)
  - Total response time
- Conversation history

### Using the Application

1. **Start a model** (via sidebar or terminal):
   ```bash
   ./scripts/vllm_manager.sh start granite-3.3-8b-instruct
   ```

2. **Wait for model to load** (2-5 minutes):
   - Watch terminal logs or check status in UI
   - Server status will show "READY" when complete

3. **Configure parameters** in sidebar:
   - Adjust temperature, max tokens as needed
   - Enable/disable streaming

4. **Start chatting**:
   - Type message in chat input
   - View response with performance metrics
   - Adjust parameters based on results

5. **Download new models**:
   - Expand "Download from HuggingFace" section
   - Enter model ID (e.g., `mistralai/Mistral-7B-Instruct-v0.2`)
   - Optionally provide HF token for gated models
   - Click "Start Download"
   - Monitor progress in terminal

### Running as Background Service

**Option 1: Using tmux/screen**
```bash
# Start tmux session
tmux new -s vllm-ui

# Activate and run
cd ~/vllm-project
source venv/bin/activate
cd streamlit
streamlit run vllm_chat.py --server.port 8501

# Detach: Ctrl+B, then D
# Reattach: tmux attach -t vllm-ui
```

**Option 2: Using systemd service**
```bash
# Create service file
sudo tee /etc/systemd/system/vllm-streamlit.service << 'EOF'
[Unit]
Description=vLLM Streamlit Testing Interface
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/home/YOUR_USERNAME/vllm-project/streamlit
Environment="PATH=/home/YOUR_USERNAME/vllm-project/venv/bin"
ExecStart=/home/YOUR_USERNAME/vllm-project/venv/bin/streamlit run vllm_chat.py --server.port 8501 --server.address 127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable vllm-streamlit
sudo systemctl start vllm-streamlit

# Check status
sudo systemctl status vllm-streamlit
```

---

## TESTING AND VALIDATION

### Quick Test Sequence

```bash
# 1. Start with a small model
cd ~/vllm-project
./scripts/vllm_manager.sh start granite-3.3-8b-instruct

# 2. Wait for model to load (watch logs)
./scripts/vllm_manager.sh logs --follow
# Wait for: "Uvicorn running on http://0.0.0.0:8000"
# Press Ctrl+C to exit logs

# 3. Test API directly
curl http://127.0.0.1:8000/v1/models

# 4. Test completion
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-3.3-8b-instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'

# 5. Start Streamlit and test interactively
source venv/bin/activate
cd streamlit
streamlit run vllm_chat.py
```

### Performance Benchmarking

**Simple throughput test:**
```python
import time
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8000/v1",
    api_key="not-needed"
)

# Measure time to first token and total time
prompt = "Explain quantum computing in simple terms."

start = time.time()
first_token = None
tokens = 0

stream = client.chat.completions.create(
    model="granite-3.3-8b-instruct",
    messages=[{"role": "user", "content": prompt}],
    stream=True,
    max_tokens=200
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        if first_token is None:
            first_token = time.time()
        tokens += 1

end = time.time()

print(f"TTFT: {first_token - start:.2f}s")
print(f"Total time: {end - start:.2f}s")
print(f"Tokens: {tokens}")
print(f"TPS: {tokens / (end - start):.1f}")
```

---

## TROUBLESHOOTING

### Container Won't Start

**Check logs:**
```bash
./scripts/vllm_manager.sh logs
```

**Common issues:**
1. **Model not found**: Verify model path
   ```bash
   ls -la ~/vllm-project/models/
   ```

2. **Port already in use**: Change port
   ```bash
   ./scripts/vllm_manager.sh start model-name --port 8001
   ```

3. **Out of memory**: Use smaller context
   ```bash
   ./scripts/vllm_manager.sh start model-name --max-model-len 2048
   ```

### Streamlit Connection Issues

**Check vLLM server:**
```bash
curl http://127.0.0.1:8000/health
```

**Check Streamlit config:**
```bash
cat ~/vllm-project/streamlit/config.yaml
```

**Restart both services:**
```bash
# Stop vLLM
./scripts/vllm_manager.sh stop

# Restart with fresh model
./scripts/vllm_manager.sh start granite-3.3-8b-instruct

# Restart Streamlit (Ctrl+C then restart)
streamlit run vllm_chat.py
```

### Performance Issues

**Slow responses:**
1. Check CPU usage: `htop`
2. Increase OMP threads:
   ```bash
   ./scripts/vllm_manager.sh start model-name --omp-threads 32
   ```
3. Reduce batch size:
   ```bash
   ./scripts/vllm_manager.sh start model-name --max-batched-tokens 2048
   ```

**High memory usage:**
1. Reduce context length: `--max-model-len 2048`
2. Reduce concurrent sequences: `--max-seqs 4`
3. Use smaller model

---

## PERFORMANCE TUNING

### For IBM Power11 Systems

**Recommended settings for 32-core system:**
```bash
export OMP_NUM_THREADS=24
export VLLM_CPU_OMP_THREADS_BIND="0-23"
export VLLM_CPU_KVCACHE_SPACE=16

./scripts/vllm_manager.sh start model-name \
    --omp-threads 24 \
    --max-model-len 8192 \
    --max-batched-tokens 8192 \
    --max-seqs 16
```

**For maximum throughput:**
```bash
./scripts/vllm_manager.sh start model-name \
    --max-batched-tokens 16384 \
    --max-seqs 32 \
    --omp-threads 32
```

**For lower latency:**
```bash
./scripts/vllm_manager.sh start model-name \
    --max-model-len 4096 \
    --max-batched-tokens 4096 \
    --max-seqs 4
```

### Monitoring Resources

```bash
# CPU and memory
htop

# Container stats
podman stats vllm-test

# vLLM metrics (if available)
curl http://127.0.0.1:8000/metrics
```

---

## RECOMMENDED MODELS FOR TESTING

### Small Models (8GB+ RAM)
- `google/gemma-2b-it`
- `TinyLlama/TinyLlama-1.1B-Chat-v1.0`

### Medium Models (16GB+ RAM)
- `ibm-granite/granite-3.3-8b-instruct`
- `mistralai/Mistral-7B-Instruct-v0.2`
- `meta-llama/Llama-2-7b-chat-hf` (gated)

### Large Models (32GB+ RAM)
- `ibm-granite/granite-20b-code-instruct`
- `meta-llama/Llama-2-13b-chat-hf` (gated)

---

## QUICK REFERENCE

**Essential Commands:**
```bash
# Setup
bash setup_environment.sh
source ~/vllm-project/venv/bin/activate

# Download model
./scripts/download_model.sh <model-id>

# Start server
./scripts/vllm_manager.sh start <model-name>

# Check status
./scripts/vllm_manager.sh status

# View logs
./scripts/vllm_manager.sh logs --follow

# Start UI
streamlit run vllm_chat.py

# Stop server
./scripts/vllm_manager.sh stop
```

**Directories:**
- Models: `~/vllm-project/models/`
- Scripts: `~/vllm-project/scripts/`
- Logs: `~/vllm-project/logs/`
- Streamlit: `~/vllm-project/streamlit/`

**URLs:**
- vLLM API: `http://127.0.0.1:8000`
- Streamlit UI: `http://127.0.0.1:8501`

---

**Last Updated:** 2026-04-09  
**Version:** 1.0  
**Platform:** IBM Power11 / AlmaLinux 9 / ppc64le
