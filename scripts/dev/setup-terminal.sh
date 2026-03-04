#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки терминала Kitty.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[setup-terminal] Установка Kitty..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y kitty

echo "[setup-terminal] Готово. Конфигурация терминала будет добавлена отдельно."

