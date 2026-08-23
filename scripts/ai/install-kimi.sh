#!/usr/bin/env bash
set -euo pipefail

# Установка Kimi Code CLI (Moonshot AI).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

install_node_stack() {
  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed nodejs npm ca-certificates
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm ca-certificates || true
  else
    echo "[install-kimi] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-kimi] Установка Node.js и npm..."
install_node_stack

echo "[install-kimi] Установка @moonshot-ai/kimi-code..."
npm install -g @moonshot-ai/kimi-code

cat <<'EOF'
[install-kimi] Готово.

Быстрый старт:
  kimi

Аутентификация:
  - запустите `kimi`, затем `/login`;
  - можно использовать Kimi OAuth или API-ключ Moonshot AI.
EOF
