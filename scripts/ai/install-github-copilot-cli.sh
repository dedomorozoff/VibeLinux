#!/usr/bin/env bash
set -euo pipefail

# Установка GitHub Copilot CLI (проприетарный инструмент, требует GitHub-аккаунт и подписку).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для системных пакетов)."
  exit 1
fi

echo "[install-github-copilot-cli] Установка Node.js и npm (если нужно)..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm ca-certificates

echo "[install-github-copilot-cli] Установка @githubnext/github-copilot-cli глобально..."
npm install -g @githubnext/github-copilot-cli || {
  echo "[install-github-copilot-cli] Не удалось установить GitHub Copilot CLI через npm."
  exit 1
}

cat <<'EOF'
[install-github-copilot-cli] Готово.

Дальнейшие шаги:
  1. Войти в GitHub из CLI (будет предложена авторизация при первом запуске).
  2. Убедиться, что у аккаунта есть доступ к GitHub Copilot.
  3. Использовать команды вида:
     github-copilot-cli git-assist
     github-copilot-cli explain "команда"
EOF

