#!/usr/bin/env bash
set -euo pipefail

# Установка OpenAI Codex CLI.

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
    echo "[install-codex-cli] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-codex-cli] Установка Node.js и npm..."
install_node_stack

echo "[install-codex-cli] Установка @openai/codex..."
npm install -g @openai/codex

cat <<'EOF'
[install-codex-cli] Готово.

Быстрый старт:
  codex

Аутентификация:
  - через ChatGPT-план, если CLI предложит логин;
  - или через API-ключ:
      export OPENAI_API_KEY="ваш_ключ"
EOF
