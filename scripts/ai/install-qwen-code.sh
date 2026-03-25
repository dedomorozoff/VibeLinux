#!/usr/bin/env bash
set -euo pipefail

# Установка Qwen Code.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-qwen-code] Установка Node.js и npm..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm ca-certificates

if ! command -v node >/dev/null 2>&1; then
  echo "[install-qwen-code] Node.js не найден после установки."
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${node_major}" -lt 20 ]]; then
  echo "[install-qwen-code] Требуется Node.js 20+."
  echo "[install-qwen-code] Установите более новый Node.js и повторите запуск."
  exit 1
fi

echo "[install-qwen-code] Установка @qwen-code/qwen-code..."
npm install -g @qwen-code/qwen-code@latest

cat <<'EOF'
[install-qwen-code] Готово.

Быстрый старт:
  qwen

Аутентификация:
  - внутри CLI выполните `/auth`;
  - можно использовать Qwen OAuth или API-ключ совместимого провайдера.
EOF
