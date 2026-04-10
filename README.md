# vLLM Testing Environment for IBM Power11
## Enterprise-Grade Model Testing and Evaluation Platform

[![Platform](https://img.shields.io/badge/platform-IBM_Power11-blue)]()
[![OS](https://img.shields.io/badge/os-AlmaLinux_9-green)]()
[![Arch](https://img.shields.io/badge/arch-ppc64le-orange)]()
[![Container](https://img.shields.io/badge/container-vllm_0.9.1-red)]()

---

## 📋 Overview

A complete testing environment for evaluating Large Language Models (LLMs) using vLLM on IBM Power11 systems. This solution provides:

- **One-command deployment** of vLLM container infrastructure
- **Interactive Streamlit UI** for model testing and evaluation
- **Automated model management** (download, load, switch)
- **Real-time performance metrics** (TTFT, TPS, latency)
- **Production-ready scripts** for container lifecycle management

---

## 🎯 Key Features

### Container Management
- ✅ Single container deployment (one model at a time)
- ✅ Automated start/stop/restart
- ✅ Configurable vLLM parameters
- ✅ Local and HuggingFace model support
- ✅ CPU-optimized for IBM Power systems

### Streamlit Testing Interface
- ✅ Chat-based interaction with models
- ✅ Real-time performance monitoring
- ✅ Model selection from local library
- ✅ In-UI model download from HuggingFace
- ✅ Configurable inference parameters
- ✅ Conversation history with memory

### Performance Analysis
- ✅ Time to First Token (TTFT)
- ✅ Tokens Per Second (TPS)
- ✅ Total inference time
- ✅ Historical metrics tracking
- ✅ Parameter optimization guidance

---

## 🚀 Quick Start

### 1. Initial Setup (One-Time)

```bash
# Run setup script
bash setup_environment.sh

# This creates:
# - ~/vllm-project/ (project directory)
# - Python virtual environment
# - Management scripts
# - Configuration files
```

### 2. Download a Model

```bash
# Activate environment
cd ~/vllm-project
source venv/bin/activate

# Download a test model
./scripts/download_model.sh ibm-granite/granite-3.3-8b-instruct
```

### 3. Start vLLM Server

```bash
# Start with default parameters
./scripts/vllm_manager.sh start granite-3.3-8b-instruct

# Or with custom parameters
./scripts/vllm_manager.sh start granite-3.3-8b-instruct \
    --max-model-len 8192 \
    --omp-threads 32
```

### 4. Launch Streamlit UI

```bash
# Start the testing interface (accessible from network)
cd streamlit
streamlit run vllm_chat.py --server.port 8501
```

**Access:** 
- Local: http://localhost:8501
- Network: http://\<server-ip\>:8501 (see firewall setup below)

---

## 📁 Project Structure

```
~/vllm-project/
├── models/                         # Downloaded models
│   ├── granite-3.3-8b-instruct/
│   ├── llama-2-7b-chat/
│   └── ...
├── cache/                          # HuggingFace cache
│   └── huggingface/
├── scripts/                        # Management scripts
│   ├── vllm_manager.sh            # Container lifecycle
│   └── download_model.sh          # Model download utility
├── streamlit/                      # Streamlit application
│   ├── vllm_chat.py               # Main UI
│   ├── config.yaml                # Configuration
│   └── requirements.txt           # Python dependencies
├── logs/                           # Application logs
│   ├── vllm_container.log
│   └── streamlit.log
├── venv/                           # Python virtual environment
└── .env                            # Environment configuration
```

---

## 🎮 Usage Examples

### Starting Different Models

```bash
# Local model
./scripts/vllm_manager.sh start granite-3.3-8b-instruct

# HuggingFace model (auto-download)
./scripts/vllm_manager.sh start ibm-granite/granite-3.3-8b-instruct

# With custom parameters
./scripts/vllm_manager.sh start llama-2-7b \
    --max-model-len 4096 \
    --max-batched-tokens 4096 \
    --omp-threads 24 \
    --dtype bfloat16
```

### Monitoring

```bash
# Check status
./scripts/vllm_manager.sh status

# View logs
./scripts/vllm_manager.sh logs

# Follow logs in real-time
./scripts/vllm_manager.sh logs --follow
```

### Switching Models

```bash
# Stop current model
./scripts/vllm_manager.sh stop

# Start new model
./scripts/vllm_manager.sh start different-model

# Or use restart (combines stop + start)
./scripts/vllm_manager.sh restart different-model
```

### Testing API Directly

```bash
# List available models
curl http://127.0.0.1:8000/v1/models

# Send chat completion
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-3.3-8b-instruct",
    "messages": [
      {"role": "user", "content": "Explain vLLM in one sentence."}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

---

## 🔧 Configuration

### Firewall Setup (For External Access)

If accessing from another machine, open port 8501:

```bash
# AlmaLinux / RHEL / CentOS
sudo firewall-cmd --permanent --add-port=8501/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

**Find your server IP:**
```bash
hostname -I
```

**Access from browser:**
```
http://<server-ip>:8501
```

**⚠️ Security Note:** For production, use reverse proxy with authentication. See [EXTERNAL_ACCESS_GUIDE.md](EXTERNAL_ACCESS_GUIDE.md) for security options.

### vLLM Container Parameters

Edit `~/vllm-project/streamlit/config.yaml`:

```yaml
# Container settings
container_port: 8000
host_bind: 127.0.0.1

# Default vLLM parameters
default_dtype: bfloat16
default_max_model_len: 4096
default_max_num_batched_tokens: 4096
default_max_num_seqs: 8

# CPU settings (adjust for your system)
omp_num_threads: 16
cpu_threads_bind: all
kvcache_space: 8
```

### Streamlit UI Settings

Parameters configurable in the UI sidebar:
- **Temperature:** 0.0 - 2.0
- **Max Tokens:** 128 - 4096
- **Top P:** 0.0 - 1.0
- **Top K:** 0 - 100
- **Presence Penalty:** -2.0 - 2.0
- **Frequency Penalty:** -2.0 - 2.0

---

## 📊 Performance Metrics

The Streamlit interface displays:

### Per-Response Metrics
- **TTFT (Time to First Token):** Latency before generation starts
- **TPS (Tokens Per Second):** Generation throughput
- **Total Time:** Complete response time
- **Token Count:** Number of tokens generated

### Aggregate Statistics
- Average TTFT across recent requests
- Average TPS across recent requests
- Performance trends over time

---

## 🎯 Recommended Models

### Small Models (8-16GB RAM)
```bash
./scripts/download_model.sh TinyLlama/TinyLlama-1.1B-Chat-v1.0
./scripts/download_model.sh google/gemma-2b-it
```

### Medium Models (16-32GB RAM)
```bash
./scripts/download_model.sh ibm-granite/granite-3.3-8b-instruct
./scripts/download_model.sh mistralai/Mistral-7B-Instruct-v0.2
```

### Large Models (32GB+ RAM)
```bash
./scripts/download_model.sh ibm-granite/granite-20b-code-instruct
./scripts/download_model.sh meta-llama/Llama-2-13b-chat-hf
```

---

## 🔍 Troubleshooting

### Container Issues

**Problem:** Container fails to start
```bash
# Check logs
./scripts/vllm_manager.sh logs

# Verify model exists
ls -la ~/vllm-project/models/

# Try with smaller context
./scripts/vllm_manager.sh start model-name --max-model-len 2048
```

**Problem:** Out of memory
```bash
# Reduce memory usage
./scripts/vllm_manager.sh start model-name \
    --max-model-len 2048 \
    --max-batched-tokens 2048 \
    --max-seqs 4
```

### Streamlit Issues

**Problem:** Cannot connect to vLLM
```bash
# Check vLLM is running
./scripts/vllm_manager.sh status

# Test API manually
curl http://127.0.0.1:8000/health
```

**Problem:** Slow performance
```bash
# Increase CPU threads
./scripts/vllm_manager.sh restart model-name --omp-threads 32

# Check system resources
htop
podman stats vllm-test
```

---

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md):** Complete step-by-step deployment instructions
- **[VLLM_DEPLOYMENT_PLAN.md](VLLM_DEPLOYMENT_PLAN.md):** Architecture and implementation plan
- **[EXTERNAL_ACCESS_GUIDE.md](EXTERNAL_ACCESS_GUIDE.md):** Network access, firewall config, and security
- **[BATCH_MODE_GUIDE.md](BATCH_MODE_GUIDE.md):** Running Streamlit in background/batch mode
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md):** Quick command reference card

---

## 🎓 Best Practices

### Model Selection
1. Start with small models for testing
2. Increase size based on RAM availability
3. Monitor memory usage before scaling

### Parameter Tuning
1. Begin with conservative settings (4096 context)
2. Increase gradually based on workload
3. Monitor TTFT and TPS for optimization

### Resource Management
1. One model at a time (switch via restart)
2. Use appropriate OMP threads for your CPU count
3. Monitor disk space for model downloads

---

## 🔐 Security Notes

**Current Configuration:**
- Localhost binding (127.0.0.1) - no external access
- No authentication required
- Suitable for testing and development

**For Production:**
- Add API key authentication
- Use reverse proxy with TLS
- Implement rate limiting
- Add audit logging

---

## 🛠️ System Requirements

### Minimum
- IBM Power system (ppc64le architecture)
- AlmaLinux 9 or compatible
- 16GB RAM
- 50GB free disk space
- Podman or Docker

### Recommended
- 32GB+ RAM (for larger models)
- 100GB+ disk space (multiple models)
- 24+ CPU cores
- High-speed storage (NVMe preferred)

---

## 📞 Support

### Common Commands Reference

```bash
# Environment
source ~/vllm-project/venv/bin/activate

# Model management
./scripts/download_model.sh <model-id>
./scripts/vllm_manager.sh list-models

# Container operations
./scripts/vllm_manager.sh start <model-name>
./scripts/vllm_manager.sh status
./scripts/vllm_manager.sh stop
./scripts/vllm_manager.sh logs --follow

# Streamlit
streamlit run vllm_chat.py --server.port 8501
```

---

## 📝 License

This deployment configuration and scripts are provided as-is for testing and evaluation purposes.

vLLM container image (`icr.io/ppc64le-oss/vllm-ppc64le:0.9.1`) is provided by IBM and subject to its licensing terms.

---

## 🏆 Credits

- **vLLM Project:** https://github.com/vllm-project/vllm
- **IBM Power vLLM Container:** IBM Open Source
- **Streamlit Framework:** https://streamlit.io
- **HuggingFace:** https://huggingface.co

---

**Version:** 1.0  
**Last Updated:** 2026-04-09  
**Platform:** IBM Power11 / AlmaLinux 9 / ppc64le  
**Container:** vllm-ppc64le:0.9.1
