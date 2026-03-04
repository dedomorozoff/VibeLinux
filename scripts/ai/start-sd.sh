#!/usr/bin/env bash
set -euo pipefail

# Запуск Stable Diffusion через ComfyUI.

INSTALL_DIR="/opt/vibecode/comfyui"

if [[ ! -d "${INSTALL_DIR}" ]]; then
  echo "[start-sd] ComfyUI не установлен. Запустите: sudo scripts/ai/setup-comfyui.sh"
  exit 1
fi

if [[ ! -x "${INSTALL_DIR}/.venv/bin/python" ]]; then
  echo "[start-sd] Не найден venv. Запустите: sudo scripts/ai/setup-comfyui.sh"
  exit 1
fi

echo "[start-sd] Запуск ComfyUI на 0.0.0.0:8188 ..."
exec "${INSTALL_DIR}/.venv/bin/python" "${INSTALL_DIR}/main.py" --listen 0.0.0.0 --port 8188

