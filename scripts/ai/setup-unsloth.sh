#!/usr/bin/env bash
set -euo pipefail

# Установка Unsloth Studio (web UI для fine-tuning LLM).
# https://unsloth.ai — GUI для тренировки моделей (LoRA, GRPO RL и т.д.)
# По умолчанию ставит Unsloth Studio. Для GPU нужен NVIDIA/CUDA.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_HOME="${USER_HOME:-/home/$USER_NAME}"

echo "[setup-unsloth] Проверка системных зависимостей..."
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed \
    git \
    curl \
    python \
    python-pip \
    python-virtualenv \
    ca-certificates
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    curl \
    python3 \
    python3-venv \
    python3-pip \
    ca-certificates
else
  echo "[setup-unsloth] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

INSTALL_DIR="/opt/vibecode/unsloth"
mkdir -p "$INSTALL_DIR"

echo "[setup-unsloth] Установка Unsloth Studio..."
if curl -fsSL https://unsloth.ai/install.sh | sh; then
  echo ""
  echo "[setup-unsloth] ✓ Unsloth Studio установлен"
else
  echo "[setup-unsloth] Ошибка установки — попробуйте вручную:"
  echo "  curl -fsSL https://unsloth.ai/install.sh | sh"
  exit 1
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Unsloth Studio готов к работе!"
echo "══════════════════════════════════════════════════════"
echo ""
echo "Запуск web UI:"
echo "  unsloth studio -H 0.0.0.0 -p 8888"
echo ""
echo "Откройте в браузере: http://localhost:8888"
echo ""
echo "Для GPU-поддержки (NVIDIA):"
echo "  Убедитесь, что установлен NVIDIA Driver + CUDA toolkit"
echo "  Unsloth автоматически определит GPU при запуске"
echo ""
echo "Для обновления:"
echo "  curl -fsSL https://unsloth.ai/install.sh | sh"
echo ""
echo "Для удаления:"
echo "  curl -fsSL https://raw.githubusercontent.com/unslothai/unsloth/main/scripts/uninstall.sh | sh"
