#!/usr/bin/env bash
set -euo pipefail

# Установка Ollama в Ubuntu и включение сервиса.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-ollama] Установка зависимостей..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates

if command -v ollama >/dev/null 2>&1; then
  echo "[install-ollama] Ollama уже установлена."
else
  echo "[install-ollama] Установка Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
fi

echo "[install-ollama] Включение и запуск сервиса..."
systemctl enable ollama || true
systemctl restart ollama || true

echo "[install-ollama] Проверка..."
if ollama --version >/dev/null 2>&1; then
  echo "[install-ollama] Готово."
else
  echo "[install-ollama] Установка завершилась, но версия не читается. Проверьте вручную."
  exit 1
fi

