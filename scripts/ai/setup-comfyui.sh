#!/usr/bin/env bash
set -euo pipefail

# Установка ComfyUI в /opt/vibecode/comfyui (через venv).
# После установки запускать через scripts/ai/start-sd.sh

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

INSTALL_DIR="/opt/vibecode/comfyui"

echo "[setup-comfyui] Установка системных зависимостей..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  python3 \
  python3-venv \
  python3-pip \
  ca-certificates

mkdir -p "$(dirname "$INSTALL_DIR")"

if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
  echo "[setup-comfyui] Клонирование ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI.git "$INSTALL_DIR"
else
  echo "[setup-comfyui] ComfyUI уже существует, обновление..."
  git -C "$INSTALL_DIR" pull --ff-only || true
fi

echo "[setup-comfyui] Создание venv и установка зависимостей..."
python3 -m venv "${INSTALL_DIR}/.venv"
"${INSTALL_DIR}/.venv/bin/python" -m pip install --upgrade pip setuptools wheel

if [[ -f "${INSTALL_DIR}/requirements.txt" ]]; then
  "${INSTALL_DIR}/.venv/bin/pip" install -r "${INSTALL_DIR}/requirements.txt"
fi

echo "[setup-comfyui] Готово. Модели кладите в ${INSTALL_DIR}/models (см. документацию ComfyUI)."

