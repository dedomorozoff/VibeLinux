#!/bin/sh
# VibeBSD — пост-установочный AI-стек (без Docker).
# Выполняется в уже установленной системе пользователем.
#
# Устанавливает: uv, transformers, langchain, llama-index, torch (CPU),
# Open WebUI, ComfyUI.

set -eu

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

# 1) uv (быстрый pip-инсталлер)
if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# 2) Python AI-библиотеки
log "Installing Python AI stack (transformers, langchain, llama-index, torch)..."
uv pip install --system --break-system-packages \
    transformers langchain llama-index torch torchvision torchaudio

# 3) Open WebUI (GUI для Ollama, без Docker)
if ! command -v open-webui >/dev/null 2>&1; then
    log "Installing Open WebUI..."
    uv pip install --system --break-system-packages open-webui
fi

# 4) ComfyUI (генерация изображений)
COMFY_DIR="${COMFY_DIR:-$HOME/ComfyUI}"
if [ ! -d "$COMFY_DIR" ]; then
    log "Cloning ComfyUI into $COMFY_DIR..."
    git clone https://github.com/comfyanonymous/ComfyUI "$COMFY_DIR"
fi

log "Done!"
log "  Ollama:      ollama run qwen2.5-coder"
log "  Open WebUI:  open-webui serve  →  http://localhost:3000"
log "  ComfyUI:     cd ~/ComfyUI && python main.py"
