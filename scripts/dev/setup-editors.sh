#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки редактора: Zed для VibeCode OS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${1:-root}"

check_network() {
  curl -sf --connect-timeout 5 https://github.com >/dev/null 2>&1
}

echo "[setup-editors] Установка Zed..."
if check_network; then
  if ! command -v zed >/dev/null 2>&1; then
    su - "$USER_NAME" -c 'curl -f https://zed.dev/install.sh 2>/dev/null | sh' 2>/dev/null || true
  fi
else
  echo "[setup-editors] Пропуск Zed - нет сети"
fi

echo "[setup-editors] Готово."
