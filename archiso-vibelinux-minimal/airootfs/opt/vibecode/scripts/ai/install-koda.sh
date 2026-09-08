#!/usr/bin/env bash
set -euo pipefail

# Установка Koda CLI (ООО «Кода», AI coding assistant, форк gemini-cli).
# Требуется Node.js 20+.

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
    echo "[install-koda] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-koda] Установка Node.js и npm (если нужно)..."
install_node_stack

if ! command -v node >/dev/null 2>&1; then
  echo "[install-koda] Node.js не найден после установки."
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${node_major}" -lt 20 ]]; then
  echo "[install-koda] Требуется Node.js 20+."
  echo "[install-koda] Установите более новый Node.js и повторите запуск."
  exit 1
fi

echo "[install-koda] Установка @kodadev/koda-cli глобально..."
npm install -g @kodadev/koda-cli || {
  echo "[install-koda] Не удалось установить Koda CLI через npm."
  exit 1
}

cat <<'EOF'
[install-koda] Готово.

Дальнейшие шаги:
  1. Запустить `koda` и пройти авторизацию.
  2. Документация: https://kodacode.ru/docs
EOF