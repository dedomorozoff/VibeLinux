#!/usr/bin/env bash
set -euo pipefail

# Агрегирующий скрипт для установки AI-стека VibeCode OS.
# Устанавливает Ollama, Open WebUI, Python AI-библиотеки, ComfyUI.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "╔════════════════════════════════════════╗"
echo "║   VibeCode OS AI Stack Setup          ║"
echo "╚════════════════════════════════════════╝"
echo ""

# 1. Ollama
echo "[1/6] Установка Ollama..."
bash "${ROOT_DIR}/scripts/ai/install-ollama.sh"

# 2. Open WebUI
echo ""
echo "[2/6] Установка Open WebUI..."
bash "${ROOT_DIR}/scripts/ai/install-open-webui.sh"

# 3. Python AI Stack
echo ""
echo "[3/6] Установка Python AI-библиотек..."
bash "${ROOT_DIR}/scripts/ai/setup-python-ai-stack.sh"

# 4. ComfyUI
echo ""
echo "[4/6] Установка ComfyUI..."
bash "${ROOT_DIR}/scripts/ai/setup-comfyui.sh"

# 5. Terminal AI (ai-chat)
echo ""
echo "[5/6] Установка ai-chat..."
bash "${ROOT_DIR}/scripts/ai/install-terminal-ai.sh"

# 6. Aider (Advanced AI coding agent)
echo ""
echo "[6/6] Установка Aider..."
bash "${ROOT_DIR}/scripts/ai/install-aider.sh"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   AI Stack установлен!                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Быстрый старт:"
echo "  • Open WebUI:    http://localhost:3000"
echo "  • ComfyUI:       sudo bash scripts/ai/start-sd.sh"
echo "  • Terminal AI:   ai-chat"
echo "  • Advanced AI:   aider"
echo "  • Python AI:     ai-env (активация окружения)"
echo "  • Agents (opt):  install-codex-cli.sh / install-claude-code.sh / install-qwen-code.sh"
echo ""
echo "Загрузка моделей:"
echo "  sudo bash scripts/ai/install-ollama-models.sh"
echo ""
