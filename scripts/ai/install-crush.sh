#!/usr/bin/env bash
set -euo pipefail

# Установка Crush (Charm — AI coding agent с LSP + MCP).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

install_node_stack() {
  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed nodejs npm ca-certificates
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm ca-certificates
  else
    echo "[install-crush] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-crush] Установка Node.js и npm..."
install_node_stack

echo "[install-crush] Установка @charmland/crush..."
npm install -g @charmland/crush

cat <<'EOF'
[install-crush] Готово.

Быстрый старт:
  crush

Аутентификация:
  - запустите `crush`, нажмите ctrl+l для выбора модели;
  - или задайте ANTHROPIC_API_KEY / OPENAI_API_KEY в окружении.
EOF
