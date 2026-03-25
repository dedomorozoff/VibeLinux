#!/usr/bin/env bash
set -euo pipefail

# Установка OpenAI Codex CLI.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-codex-cli] Установка Node.js и npm..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm ca-certificates

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
