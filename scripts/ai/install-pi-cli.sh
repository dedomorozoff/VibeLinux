#!/usr/bin/env bash
set -euo pipefail

# Установка Pi CLI — coding agent CLI с инструментами read/bash/edit/write
# и управлением сессиями (https://pi.dev, пакет @earendil-works/pi-coding-agent).
# Также устанавливает расширение pi-freeflow (https://pi.dev/packages/pi-freeflow?type=extension)
# — тонкий провайдер OMP/Pi со списком моделей и релей-прокси.

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
    echo "[install-pi-cli] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
    exit 1
  fi
}

echo "[install-pi-cli] Установка Node.js и npm..."
install_node_stack

if ! command -v node >/dev/null 2>&1; then
  echo "[install-pi-cli] Node.js не найден после установки."
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [[ "${node_major}" -lt 18 ]]; then
  echo "[install-pi-cli] Требуется Node.js 18+."
  exit 1
fi

echo "[install-pi-cli] Установка @earendil-works/pi-coding-agent (команда pi)..."
npm install -g @earendil-works/pi-coding-agent@latest

echo "[install-pi-cli] Установка расширения pi-freeflow..."
npm install -g pi-freeflow@latest || echo "[install-pi-cli] WARNING: pi-freeflow install failed"

cat <<'EOF'
[install-pi-cli] Готово.

Быстрый старт:
  pi

Pi CLI — автономный coding agent с набором инструментов (read, bash, edit, write)
и управлением сессиями. Работает с моделями через OMP/Pi-провайдер.

Расширение pi-freeflow установлено — тонкий провайдер списка моделей + dumb relay proxy.

Документация:
  https://pi.dev
  https://pi.dev/packages/pi-freeflow?type=extension
EOF
