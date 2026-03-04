#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки базового Python AI-стека (CPU-версия).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для системных python/pip пакетов при необходимости)."
  exit 1
fi

echo "[setup-python-ai-stack] Обновление pip..."
python3 -m pip install --upgrade pip setuptools wheel

echo "[setup-python-ai-stack] Установка AI-библиотек (CPU-версии)..."
python3 -m pip install --upgrade \
  torch --index-url https://download.pytorch.org/whl/cpu \
  transformers \
  sentencepiece \
  accelerate \
  langchain \
  llama-index

echo "[setup-python-ai-stack] Готово. Для установки GPU-версии PyTorch см. документацию проекта."

