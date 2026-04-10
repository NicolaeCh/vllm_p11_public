"""
vllm_chat.py — vLLM Testing Interface
Enterprise-grade chatbot for testing vLLM models on IBM Power11

Features:
  - Model selection from local library
  - In-UI model download from HuggingFace
  - Real-time performance metrics (TTFT, TPS, total time)
  - Configurable inference parameters
  - Conversation history with memory
  - Container management integration
  - System resource monitoring

Run: streamlit run vllm_chat.py --server.port 8501
UI:  http://localhost:8501
"""

import os
import sys
import time
import json
import subprocess
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
import yaml

import streamlit as st
from openai import OpenAI
import requests

# Configuration
PROJECT_DIR = Path.home() / "vllm-project"
MODELS_DIR = PROJECT_DIR / "models"
SCRIPTS_DIR = PROJECT_DIR / "scripts"
CONFIG_FILE = PROJECT_DIR / "streamlit" / "config.yaml"

# Load config
def load_config():
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            return yaml.safe_load(f)
    else:
        # Default configuration
        return {
            "container_port": 8000,
            "host_bind": "127.0.0.1",
            "default_dtype": "bfloat16",
            "default_max_model_len": 4096,
            "default_max_num_batched_tokens": 4096,
            "default_max_num_seqs": 8,
            "omp_num_threads": 16,
            "streamlit_port": 8501,
        }

CONFIG = load_config()
VLLM_BASE_URL = f"http://{CONFIG['host_bind']}:{CONFIG['container_port']}/v1"

# Styling
st.set_page_config(
    page_title="vLLM Testing Interface - IBM Power11",
    page_icon="🚀",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Helper Functions
def get_available_models() -> List[str]:
    """Scan models directory for available models."""
    if not MODELS_DIR.exists():
        return []
    
    models = []
    for model_dir in MODELS_DIR.iterdir():
        if model_dir.is_dir():
            config_file = model_dir / "config.json"
            if config_file.exists():
                models.append(model_dir.name)
    return sorted(models)

def check_vllm_server() -> Dict:
    """Check if vLLM server is running and responsive."""
    try:
        response = requests.get(f"{VLLM_BASE_URL}/models", timeout=2)
        if response.status_code == 200:
            data = response.json()
            return {
                "status": "running",
                "models": data.get("data", []),
                "healthy": True
            }
        else:
            return {"status": "error", "healthy": False}
    except requests.exceptions.RequestException:
        return {"status": "offline", "healthy": False}

def get_container_status() -> Dict:
    """Get vLLM container status using podman/docker."""
    try:
        # Try to determine which container runtime is available
        for cmd in ["podman", "docker"]:
            try:
                result = subprocess.run(
                    [cmd, "ps", "--filter", "name=vllm-test", "--format", "{{.Status}}"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0 and result.stdout.strip():
                    return {
                        "running": True,
                        "status": result.stdout.strip(),
                        "runtime": cmd
                    }
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
        
        return {"running": False, "status": "Not running"}
    except Exception as e:
        return {"running": False, "status": f"Error: {str(e)}"}

def download_model_background(model_id: str, hf_token: Optional[str] = None):
    """Initiate background model download."""
    download_script = SCRIPTS_DIR / "download_model.sh"
    
    if not download_script.exists():
        return False, "Download script not found"
    
    try:
        cmd = ["bash", str(download_script), model_id]
        if hf_token:
            cmd.append(hf_token)
        
        # Start download in background
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        return True, f"Download started for {model_id}"
    except Exception as e:
        return False, f"Failed to start download: {str(e)}"

@st.cache_resource(show_spinner=False)
def get_openai_client():
    """Create OpenAI client for vLLM."""
    return OpenAI(
        base_url=VLLM_BASE_URL,
        api_key="not-needed"  # vLLM doesn't require API key for localhost
    )

def stream_completion(client, messages, model, temperature, max_tokens):
    """Stream completion from vLLM."""
    try:
        stream = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
            stream=True,
        )
        
        for chunk in stream:
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content
                
    except Exception as e:
        yield f"\n\n❌ Error: {str(e)}"

def format_metrics(metrics: Dict) -> str:
    """Format performance metrics for display."""
    lines = []
    if "ttft" in metrics:
        lines.append(f"⚡ TTFT: {metrics['ttft']:.2f}s")
    if "tps" in metrics:
        lines.append(f"📊 TPS: {metrics['tps']:.1f} tokens/s")
    if "total_time" in metrics:
        lines.append(f"⏱ Total: {metrics['total_time']:.2f}s")
    if "tokens" in metrics:
        lines.append(f"🔢 Tokens: {metrics['tokens']}")
    return " | ".join(lines)

# Main Application
def main():
    # Initialize session state
    if "messages" not in st.session_state:
        st.session_state.messages = []
    if "active_model" not in st.session_state:
        st.session_state.active_model = None
    if "performance_log" not in st.session_state:
        st.session_state.performance_log = []

    # Sidebar - Configuration & Management
    with st.sidebar:
        st.title("⚙️ vLLM Testing")
        st.caption("IBM Power11 / AlmaLinux 9")
        
        # Server Status
        st.divider()
        st.subheader("📡 Server Status")
        
        server_status = check_vllm_server()
        container_status = get_container_status()
        
        if server_status["healthy"]:
            st.success("✅ vLLM Server: READY")
            if server_status.get("models"):
                active_model = server_status["models"][0].get("id", "Unknown")
                st.session_state.active_model = active_model
                st.info(f"🎯 Active Model: `{active_model}`")
        else:
            st.error("❌ vLLM Server: OFFLINE")
            st.warning("Start a model to begin testing")
        
        if container_status["running"]:
            st.caption(f"🐳 Container: {container_status['status']}")
        
        # Model Management
        st.divider()
        st.subheader("🎯 Model Management")
        
        available_models = get_available_models()
        
        if available_models:
            st.write(f"**Local Models** ({len(available_models)})")
            selected_model = st.selectbox(
                "Select model to load:",
                available_models,
                key="model_selector"
            )
            
            col1, col2 = st.columns(2)
            with col1:
                if st.button("🚀 Load Model", use_container_width=True):
                    with st.spinner("Starting vLLM container..."):
                        script_path = SCRIPTS_DIR / "vllm_manager.sh"
                        if script_path.exists():
                            try:
                                result = subprocess.run(
                                    ["bash", str(script_path), "restart", selected_model],
                                    capture_output=True,
                                    text=True,
                                    timeout=10
                                )
                                if result.returncode == 0:
                                    st.success(f"Loading {selected_model}...")
                                    st.info("Model is loading. This may take 2-5 minutes.")
                                    st.info("Refresh page when ready.")
                                else:
                                    st.error(f"Failed: {result.stderr}")
                            except Exception as e:
                                st.error(f"Error: {str(e)}")
                        else:
                            st.error("vllm_manager.sh not found")
            
            with col2:
                if st.button("🛑 Stop Server", use_container_width=True):
                    script_path = SCRIPTS_DIR / "vllm_manager.sh"
                    if script_path.exists():
                        subprocess.run(["bash", str(script_path), "stop"])
                        st.success("Server stopped")
                        time.sleep(1)
                        st.rerun()
        else:
            st.warning("No models found in local library")
            st.caption(f"Download models to: `{MODELS_DIR}`")
        
        # Model Download
        st.divider()
        st.subheader("📥 Download Model")
        
        with st.expander("Download from HuggingFace", expanded=False):
            model_id = st.text_input(
                "Model ID",
                placeholder="e.g., ibm-granite/granite-3.3-8b-instruct",
                help="Enter HuggingFace model identifier"
            )
            
            hf_token = st.text_input(
                "HF Token (optional)",
                type="password",
                help="Required for gated/private models"
            )
            
            if st.button("📥 Start Download"):
                if model_id:
                    success, message = download_model_background(model_id, hf_token)
                    if success:
                        st.success(message)
                        st.info("Download running in background. Check terminal for progress.")
                    else:
                        st.error(message)
                else:
                    st.warning("Please enter a model ID")
        
        # Inference Parameters
        st.divider()
        st.subheader("🎛️ Inference Parameters")
        
        temperature = st.slider(
            "Temperature",
            min_value=0.0,
            max_value=2.0,
            value=0.7,
            step=0.1,
            help="Controls randomness. Lower = more focused"
        )
        
        max_tokens = st.slider(
            "Max Tokens",
            min_value=128,
            max_value=4096,
            value=1024,
            step=128,
            help="Maximum tokens to generate"
        )
        
        top_p = st.slider(
            "Top P",
            min_value=0.0,
            max_value=1.0,
            value=0.95,
            step=0.05,
            help="Nucleus sampling threshold"
        )
        
        top_k = st.slider(
            "Top K",
            min_value=0,
            max_value=100,
            value=50,
            step=5,
            help="Top-K sampling (0 = disabled)"
        )
        
        # Advanced Settings
        with st.expander("⚡ Advanced Settings"):
            presence_penalty = st.slider(
                "Presence Penalty",
                min_value=-2.0,
                max_value=2.0,
                value=0.0,
                step=0.1
            )
            
            frequency_penalty = st.slider(
                "Frequency Penalty",
                min_value=-2.0,
                max_value=2.0,
                value=0.0,
                step=0.1
            )
            
            stream_enabled = st.checkbox("Stream responses", value=True)
        
        # Performance Monitoring
        st.divider()
        st.subheader("📊 Performance")
        
        show_metrics = st.checkbox("Show detailed metrics", value=True)
        
        if st.session_state.performance_log:
            recent_metrics = st.session_state.performance_log[-5:]
            avg_ttft = sum(m.get("ttft", 0) for m in recent_metrics) / len(recent_metrics)
            avg_tps = sum(m.get("tps", 0) for m in recent_metrics) / len(recent_metrics)
            
            col1, col2 = st.columns(2)
            col1.metric("Avg TTFT", f"{avg_ttft:.2f}s")
            col2.metric("Avg TPS", f"{avg_tps:.1f}")
        
        # Session Management
        st.divider()
        if st.button("🗑️ Clear Conversation"):
            st.session_state.messages = []
            st.session_state.performance_log = []
            st.rerun()

    # Main Chat Interface
    st.title("🚀 vLLM Testing Interface")
    
    if st.session_state.active_model:
        st.caption(f"Testing: **{st.session_state.active_model}** | Port: {CONFIG['container_port']}")
    else:
        st.caption("⚠️ No model loaded - Start a model from the sidebar")
    
    # Display conversation history
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
            
            # Show metrics if available
            if "metrics" in message and show_metrics:
                st.caption(format_metrics(message["metrics"]))
    
    # Chat input
    if prompt := st.chat_input("Enter your message...", disabled=not server_status["healthy"]):
        # Add user message
        st.session_state.messages.append({"role": "user", "content": prompt})
        
        with st.chat_message("user"):
            st.markdown(prompt)
        
        # Generate assistant response
        with st.chat_message("assistant"):
            if not server_status["healthy"]:
                st.error("Server is not ready. Please start a model first.")
            else:
                # Build messages for API
                messages = [
                    {"role": m["role"], "content": m["content"]} 
                    for m in st.session_state.messages
                ]
                
                # Performance tracking
                start_time = time.time()
                first_token_time = None
                token_count = 0
                
                placeholder = st.empty()
                full_response = ""
                
                try:
                    client = get_openai_client()
                    
                    for token in stream_completion(
                        client,
                        messages,
                        st.session_state.active_model,
                        temperature,
                        max_tokens
                    ):
                        if first_token_time is None:
                            first_token_time = time.time()
                        
                        full_response += token
                        token_count += 1
                        
                        if stream_enabled:
                            placeholder.markdown(full_response + "▌")
                        else:
                            placeholder.markdown(full_response)
                    
                    # Final update
                    placeholder.markdown(full_response)
                    
                    # Calculate metrics
                    end_time = time.time()
                    total_time = end_time - start_time
                    ttft = (first_token_time - start_time) if first_token_time else 0
                    tps = token_count / total_time if total_time > 0 else 0
                    
                    metrics = {
                        "ttft": ttft,
                        "tps": tps,
                        "total_time": total_time,
                        "tokens": token_count,
                        "timestamp": datetime.now().isoformat()
                    }
                    
                    # Display metrics
                    if show_metrics:
                        st.caption(format_metrics(metrics))
                    
                    # Save to session state
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": full_response,
                        "metrics": metrics
                    })
                    
                    st.session_state.performance_log.append(metrics)
                    
                except Exception as e:
                    error_msg = f"❌ Error: {str(e)}"
                    placeholder.error(error_msg)
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": error_msg
                    })

    # Footer with system info
    st.divider()
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.caption(f"🖥️ Models Dir: `{MODELS_DIR}`")
    with col2:
        st.caption(f"📦 Container: vllm-ppc64le:0.9.1")
    with col3:
        st.caption(f"🔧 Scripts: `{SCRIPTS_DIR}`")

if __name__ == "__main__":
    main()
