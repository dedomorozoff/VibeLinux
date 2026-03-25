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

if ! command -v node >/dev/null 2>&1; then
  echo "[install-github-copilot-cli] Node.js не найден после установки."
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${node_major}" -lt 22 ]]; then
  echo "[install-github-copilot-cli] Требуется Node.js 22+."
  echo "[install-github-copilot-cli] Установите более новый Node.js и повторите запуск."
  exit 1
fi

echo "[install-github-copilot-cli] Установка @github/copilot глобально..."
npm install -g @github/copilot || {
  echo "[install-github-copilot-cli] Не удалось установить GitHub Copilot CLI через npm."
  exit 1
}

cat <<'EOF'
[install-github-copilot-cli] Готово.

Дальнейшие шаги:
  1. Запустить `copilot` и пройти авторизацию.
  2. Убедиться, что у аккаунта есть доступ к GitHub Copilot.
  3. Использовать команды вида:
     copilot
EOF
