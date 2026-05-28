#!/usr/bin/env bash
set -euo pipefail

# Установка Anthropic Claude Code.

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
    echo "[install-claude-code] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-claude-code] Установка Node.js и npm..."
install_node_stack

if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [[ "${node_major}" -lt 18 ]]; then
    echo "[install-claude-code] Требуется Node.js 18+."
    exit 1
  fi
fi

echo "[install-claude-code] Установка @anthropic-ai/claude-code..."
npm install -g @anthropic-ai/claude-code

cat <<'EOF'
[install-claude-code] Готово.

Быстрый старт:
  claude

Аутентификация:
  - запустите `claude`, затем `/login`;
  - можно использовать Claude.ai аккаунт или Anthropic Console.
EOF
