#!/usr/bin/env bash
set -euo pipefail

# Установка официального OpenAI CLI (требует OPENAI_API_KEY у пользователя).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для системных пакетов)."
  exit 1
fi

echo "[install-openai-cli] Установка зависимостей..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip ca-certificates

echo "[install-openai-cli] Установка пакета openai..."
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --upgrade openai

cat <<'EOF'
[install-openai-cli] Готово.

Для работы CLI необходимо:
  1. Получить API-ключ OpenAI.
  2. Экспортировать переменную окружения:
     export OPENAI_API_KEY="ваш_ключ"
  3. Использовать команды вида:
     openai chat.completions.create -m gpt-4.1 -g "help me with..."
EOF
