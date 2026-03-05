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
echo "[1/5] Установка Ollama..."
bash "${ROOT_DIR}/scripts/ai/install-ollama.sh"

# 2. Open WebUI
echo ""
echo "[2/5] Установка Open WebUI..."
bash "${ROOT_DIR}/scripts/ai/install-open-webui.sh"

# 3. Python AI Stack
echo ""
echo "[3/5] Установка Python AI-библиотек..."
bash "${ROOT_DIR}/scripts/ai/setup-python-ai-stack.sh"

# 4. ComfyUI
echo ""
echo "[4/5] Установка ComfyUI..."
bash "${ROOT_DIR}/scripts/ai/setup-comfyui.sh"

# 5. Terminal AI
echo ""
echo "[5/5] Установка ai-chat..."
if [[ ! -f /usr/local/bin/ai-chat ]]; then
  cp "${ROOT_DIR}/scripts/ai/ai-chat" /usr/local/bin/ai-chat
  chmod +x /usr/local/bin/ai-chat
  echo "✓ ai-chat установлен в /usr/local/bin"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   AI Stack установлен!                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Быстрый старт:"
echo "  • Open WebUI:    http://localhost:3000"
echo "  • ComfyUI:       sudo bash scripts/ai/start-sd.sh"
echo "  • Terminal AI:   ai-chat"
echo "  • Python AI:     ai-env (активация окружения)"
echo ""
echo "Загрузка моделей:"
echo "  sudo bash scripts/ai/install-ollama-models.sh"
echo ""
