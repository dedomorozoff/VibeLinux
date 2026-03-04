#!/usr/bin/env bash
set -euo pipefail

# Установка минимальных терминальных AI-инструментов для работы с Ollama.
# Сюда входит установка утилит-зависимостей и размещение `ai-chat` в PATH.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-terminal-ai] Установка зависимостей..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates jq

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[install-terminal-ai] Установка ai-chat в /usr/local/bin..."
install -m 0755 "${SCRIPT_DIR}/ai-chat" /usr/local/bin/ai-chat

echo "[install-terminal-ai] Готово. Используйте команду: ai-chat \"ваш запрос\""

