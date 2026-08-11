#!/usr/bin/env bash
set -euo pipefail

# Агрегирующий скрипт для установки AI-стека VibeCode OS.
# Устанавливает Ollama, Open WebUI, Python AI-библиотеки, ComfyUI.
# Работает и из репозитория, и из установленной системы (/opt/vibecode/scripts/ai).

# Пути к скриптам берём относительно СВОЕГО расположения, чтобы скрипт
# одинаково работал из git-репо (scripts/ai/) и из /opt/vibecode/scripts/ai/
# на установленной системе.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

# Live-сессия (archiso): корень — overlay в RAM, тяжёлые компоненты не влезут.
if [[ -d /run/archiso/bootmnt ]]; then
  echo "Это live-сессия: корень работает в RAM, тяжёлый AI-стек сюда не поместится."
  echo "Установите VibeLinux на диск, затем запустите:"
  echo "  sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh"
  exit 1
fi

echo "╔════════════════════════════════════════╗"
echo "║   VibeCode OS AI Stack Setup          ║"
echo "╚════════════════════════════════════════╝"
echo ""

# 1. Ollama
echo "[1/6] Установка Ollama..."
bash "${SCRIPT_DIR}/install-ollama.sh"

# 2. Open WebUI
echo ""
echo "[2/6] Установка Open WebUI..."
bash "${SCRIPT_DIR}/install-open-webui.sh"

# 3. Python AI Stack
echo ""
echo "[3/6] Установка Python AI-библиотек..."
bash "${SCRIPT_DIR}/setup-python-ai-stack.sh"

# 4. ComfyUI
echo ""
echo "[4/6] Установка ComfyUI..."
bash "${SCRIPT_DIR}/setup-comfyui.sh"

# 5. Terminal AI (ai-chat)
echo ""
echo "[5/6] Установка ai-chat..."
bash "${SCRIPT_DIR}/install-terminal-ai.sh"

# 6. Aider (Advanced AI coding agent)
echo ""
echo "[6/6] Установка Aider..."
bash "${SCRIPT_DIR}/install-aider.sh"

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
