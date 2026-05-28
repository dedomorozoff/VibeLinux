#!/usr/bin/env bash
set -euo pipefail

# Установка официального OpenAI CLI (требует OPENAI_API_KEY у пользователя).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для системных пакетов)."
  exit 1
fi

install_python_stack() {
  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed python python-pip ca-certificates
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip ca-certificates
  else
    echo "[install-openai-cli] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-openai-cli] Установка зависимостей..."
install_python_stack

echo "[install-openai-cli] Установка пакета openai..."
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --upgrade openai

cat <<'EOF'
[install-openai-cli] Готово.

Для работы CLI необходимо:
  1. Получить API-ключ OpenAI.
  2. Экспортировать переменную окружения:
     export OPENAI_API_KEY="ваш_ключ"
  3. Использовать OpenAI CLI для запросов к API или установить Codex CLI:
     sudo ./scripts/ai/install-codex-cli.sh
EOF
