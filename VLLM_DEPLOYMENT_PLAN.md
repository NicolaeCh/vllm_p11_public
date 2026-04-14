# vLLM Deployment Plan for IBM Power11 - AlmaLinux
## Complete Implementation Guide

---

## 1. OVERVIEW

**Objective:** Deploy IBM vLLM container on AlmaLinux Power11 with a Streamlit test interface for model evaluation.

**Architecture:**
- Single vLLM container serving one model at a time
- Container restarts to switch models
- Streamlit UI for testing and model management
- Local model storage in user directory
- No authentication (localhost only)

**Key Features:**
- Model selection from local library
- In-UI model download from HuggingFace
- Real-time performance metrics
- Configurable inference parameters
- Conversation history
- Container lifecycle management

---

## 2. DIRECTORY STRUCTURE

```
/home/<username>/
├── vllm-project/
│   ├── models/                    # Downloaded models
│   │   ├── granite-3.3-8b/
│   │   ├── llama-2-7b/
│   │   └── ...
│   ├── cache/                     # HuggingFace cache
│   │   └── huggingface/
│   ├── scripts/                   # Management scripts
│   │   ├── vllm_manager.sh
│   │   ├── download_model.sh
│   │   └── check_models.sh
│   ├── streamlit/                 # Streamlit application
│   │   ├── vllm_chat.py
│   │   ├── requirements.txt
│   │   └── config.yaml
│   └── logs/                      # Container and app logs
│       ├── vllm_container.log
│       └── streamlit.log
```

---

## 3. PREREQUISITES CHECK

### 3.1 System Requirements
- IBM Power11 system with ppc64le architecture
- AlmaLinux 9
- Minimum 32GB RAM (64GB+ recommended for larger models)
- Sufficient disk space (100GB+ for models)

### 3.2 Required Software
- Podman or Docker
- Python 3.9+
- Internet access for initial setup

---

## 4. IMPLEMENTATION STEPS

### Phase 1: System Preparation (30 minutes)
1. Install Podman/Docker
2. Create directory structure
3. Set up Python environment
4. Install dependencies

### Phase 2: vLLM Container Setup (20 minutes)
1. Pull container image
2. Create management scripts
3. Test container startup
4. Validate API endpoints

### Phase 3: Model Management (varies)
1. Set up model download scripts
2. Download initial test model
3. Configure model registry
4. Test model loading

### Phase 4: Streamlit Development (1 hour)
1. Create chatbot application
2. Implement model selection
3. Add download functionality
4. Configure parameters UI
5. Add performance monitoring

### Phase 5: Integration Testing (30 minutes)
1. End-to-end testing
2. Performance benchmarking
3. Error handling validation
4. Documentation finalization

**Total Estimated Time: 3-4 hours**

---

## 5. DETAILED IMPLEMENTATION

See accompanying scripts and code files for complete implementation.

### Key Files to Create:
1. `setup_environment.sh` - Initial system setup
2. `vllm_manager.sh` - Container lifecycle management
3. `download_model.sh` - Model download utility
4. `vllm_chat.py` - Streamlit chatbot application
5. `requirements.txt` - Python dependencies
6. `config.yaml` - Configuration settings

---

## 6. OPERATIONAL PROCEDURES

### Starting a Model Server:
```bash
./scripts/vllm_manager.sh start <model-name>
```

### Stopping the Server:
```bash
./scripts/vllm_manager.sh stop
```

### Switching Models:
```bash
./scripts/vllm_manager.sh switch <new-model-name>
```

### Launching Streamlit UI:
```bash
streamlit run streamlit/vllm_chat.py --server.port 8501
```

---

## 7. PERFORMANCE TUNING

### Key Parameters to Tune:
- `OMP_NUM_THREADS`: Match to physical cores
- `VLLM_CPU_OMP_THREADS_BIND`: CPU affinity
- `max-model-len`: Context window size
- `max-num-batched-tokens`: Throughput control
- `dtype`: Precision (bfloat16 recommended)

### Monitoring Points:
- Time to first token (TTFT)
- Tokens per second (TPS)
- Memory utilization
- CPU utilization
- Request latency

---

## 8. TROUBLESHOOTING

### Common Issues:
1. Container fails to start → Check logs, verify model path
2. Out of memory → Reduce context length, use smaller model
3. Slow performance → Tune OMP threads, check CPU binding
4. Model not found → Verify model directory structure
5. API connection refused → Check port mapping, firewall

---

## 9. SECURITY CONSIDERATIONS

Since this is localhost testing only:
- Bind to 127.0.0.1 only
- No firewall exposure needed
- Keep API key simple or omit
- Monitor resource usage

For production:
- Add proper authentication
- Use reverse proxy with TLS
- Implement rate limiting
- Add audit logging

---

## 10. NEXT STEPS AFTER DEPLOYMENT

1. Benchmark multiple models
2. Document performance characteristics
3. Test different parameter combinations
4. Create model selection guidelines
5. Build automated testing suite

---

## 11. MAINTENANCE

### Regular Tasks:
- Clean up old model downloads
- Monitor disk usage
- Review performance logs
- Update container image
- Backup configuration

### Weekly:
- Review resource utilization
- Test new models
- Update documentation

---

## 12. RESOURCES

- IBM vLLM Documentation: Container manual from IBM
- vLLM Official Docs: https://docs.vllm.ai/
- HuggingFace Hub: https://huggingface.co/models
- Streamlit Docs: https://docs.streamlit.io/

---

**Document Version:** 1.0  
**Last Updated:** 2026-04-09  
**Platform:** IBM Power11 / AlmaLinux 9 / ppc64le
