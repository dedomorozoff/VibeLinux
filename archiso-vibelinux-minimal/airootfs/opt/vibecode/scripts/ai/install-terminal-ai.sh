#!/usr/bin/env bash
set -euo pipefail

# Установка минимальных терминальных AI-инструментов для работы с Ollama.
# Сюда входит установка утилит-зависимостей и размещение `ai-chat` в PATH.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-terminal-ai] Установка зависимостей..."
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed curl ca-certificates jq
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates jq
else
  echo "[install-terminal-ai] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[install-terminal-ai] Установка ai-chat в /usr/local/bin..."
install -m 0755 "${SCRIPT_DIR}/ai-chat" /usr/local/bin/ai-chat

echo '[install-terminal-ai] Готово. Используйте команду: ai-chat "ваш запрос"'
