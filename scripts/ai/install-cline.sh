#!/usr/bin/env bash
set -euo pipefail

# Установка Cline CLI (Autonomous AI coding agent).

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
    echo "[install-cline] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-cline] Установка Node.js и npm..."
install_node_stack

if ! command -v node >/dev/null 2>&1; then
  echo "[install-cline] Node.js не найден после установки."
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${node_major}" -lt 18 ]]; then
  echo "[install-cline] Требуется Node.js 18+."
  exit 1
fi

echo "[install-cline] Установка cline..."
npm install -g cline@latest

cat <<'EOF'
[install-cline] Готово.

Быстрый старт:
  cline

Аутентификация и настройка:
  cline auth
  cline --help
EOF
