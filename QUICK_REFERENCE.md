# vLLM Testing Environment - Quick Reference Card

## 🚀 ESSENTIAL COMMANDS

### First-Time Setup
```bash
bash setup_environment.sh
cd ~/vllm-project
source venv/bin/activate
```

### Download Models
```bash
# Public model
./scripts/download_model.sh ibm-granite/granite-3.3-8b-instruct

# Gated model (needs token)
./scripts/download_model.sh meta-llama/Llama-2-7b-chat-hf hf_xxxxx
```

### Start vLLM Server
```bash
# Basic start
./scripts/vllm_manager.sh start granite-3.3-8b-instruct

# With custom parameters
./scripts/vllm_manager.sh start granite-3.3-8b-instruct \
    --max-model-len 8192 \
    --omp-threads 32 \
    --dtype bfloat16
```

### Monitor Server
```bash
./scripts/vllm_manager.sh status           # Check status
./scripts/vllm_manager.sh logs             # View logs
./scripts/vllm_manager.sh logs --follow    # Stream logs
```

### Switch Models
```bash
./scripts/vllm_manager.sh stop                    # Stop current
./scripts/vllm_manager.sh restart new-model-name  # Switch to new
```

### Manage Streamlit UI (Background Mode)
```bash
# Start in background
./scripts/streamlit_manager.sh start

# Check status
./scripts/streamlit_manager.sh status

# View logs
./scripts/streamlit_manager.sh logs --follow

# Stop
./scripts/streamlit_manager.sh stop

# Restart
./scripts/streamlit_manager.sh restart
```

### Start Streamlit UI
```bash
cd ~/vllm-project
source venv/bin/activate

# Option 1: Interactive mode (blocks terminal)
cd streamlit
streamlit run vllm_chat.py --server.port 8501

# Option 2: Background mode (RECOMMENDED)
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs --follow
```

### Test API Directly
```bash
# Health check
curl http://127.0.0.1:8000/health

# List models
curl http://127.0.0.1:8000/v1/models

# Chat completion
curl -X POST http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "granite-3.3-8b-instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
```

## 📁 DIRECTORY STRUCTURE
```
~/vllm-project/
├── models/          # Downloaded models
├── scripts/         # Management scripts
├── streamlit/       # UI application
├── cache/           # HuggingFace cache
├── logs/            # Log files
└── venv/            # Python environment
```

## 🎛️ KEY PARAMETERS

### vLLM Container
- `--dtype`: bfloat16, float16, auto
- `--max-model-len`: Context length (default: 4096)
- `--max-batched-tokens`: Batch size (default: 4096)
- `--max-seqs`: Concurrent sequences (default: 8)
- `--omp-threads`: CPU threads (default: 16)

### Inference (Streamlit UI)
- Temperature: 0.0-2.0 (randomness)
- Max Tokens: 128-4096 (response length)
- Top P: 0.0-1.0 (nucleus sampling)
- Top K: 0-100 (vocabulary filtering)

## 🔧 TROUBLESHOOTING

### Container Won't Start
```bash
./scripts/vllm_manager.sh logs              # Check error logs
ls ~/vllm-project/models/                   # Verify model exists
./scripts/vllm_manager.sh start model --max-model-len 2048  # Reduce memory
```

### Out of Memory
```bash
./scripts/vllm_manager.sh start model \
    --max-model-len 2048 \
    --max-seqs 4
```

### Slow Performance
```bash
./scripts/vllm_manager.sh start model --omp-threads 32  # More threads
htop                                                     # Check CPU usage
```

### Streamlit Connection Failed
```bash
./scripts/vllm_manager.sh status            # Check vLLM running
curl http://127.0.0.1:8000/health          # Test API
cat ~/vllm-project/streamlit/config.yaml   # Check config
```

## 📊 PERFORMANCE TIPS

### For Maximum Throughput
```bash
./scripts/vllm_manager.sh start model \
    --max-batched-tokens 16384 \
    --max-seqs 32 \
    --omp-threads 32
```

### For Minimum Latency
```bash
./scripts/vllm_manager.sh start model \
    --max-model-len 4096 \
    --max-batched-tokens 4096 \
    --max-seqs 4
```

### For Memory Efficiency
```bash
./scripts/vllm_manager.sh start model \
    --max-model-len 2048 \
    --max-batched-tokens 2048 \
    --max-seqs 4 \
    --dtype bfloat16
```

## 🌐 ACCESS POINTS
- vLLM API: http://127.0.0.1:8000
- Streamlit UI: http://127.0.0.1:8501
- API Docs: http://127.0.0.1:8000/docs (when enabled)

## 📚 DOCUMENTATION FILES
- README.md - Overview and quick start
- DEPLOYMENT_GUIDE.md - Complete deployment instructions
- VLLM_DEPLOYMENT_PLAN.md - Architecture and planning
- ibm_vllm_container_manual.md - Container reference

## 🎯 RECOMMENDED MODELS
- Small (8GB): TinyLlama/TinyLlama-1.1B-Chat-v1.0
- Medium (16GB): ibm-granite/granite-3.3-8b-instruct
- Large (32GB+): ibm-granite/granite-20b-code-instruct

## ⚡ QUICK WORKFLOW

1. **Setup** (one-time)
   ```bash
   bash setup_environment.sh
   ```

2. **Download model**
   ```bash
   source ~/vllm-project/venv/bin/activate
   ./scripts/download_model.sh ibm-granite/granite-3.3-8b-instruct
   ```

3. **Start vLLM server**
   ```bash
   ./scripts/vllm_manager.sh start granite-3.3-8b-instruct
   ```

4. **Launch UI (batch mode)**
   ```bash
   cd ~/vllm-project
   ./scripts/streamlit_manager.sh start
   # Access at http://localhost:8501
   ```

5. **Test and iterate**
   - Open browser to http://localhost:8501
   - Adjust parameters in UI
   - Monitor performance
   - Switch models as needed

6. **Stop services when done**
   ```bash
   ./scripts/streamlit_manager.sh stop
   ./scripts/vllm_manager.sh stop
   ```

---
**Keep this card handy for daily operations!**
