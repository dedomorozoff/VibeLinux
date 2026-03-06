#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки терминала Kitty для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[setup-terminal] Установка Kitty..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y kitty

echo "[setup-terminal] Копирование конфигов..."
# Копируем конфиг Kitty
if [[ -f "${ROOT_DIR}/scripts/dev/configs/kitty.conf" ]]; then
  mkdir -p "${USER_HOME}/.config/kitty"
  cp "${ROOT_DIR}/scripts/dev/configs/kitty.conf" "${USER_HOME}/.config/kitty/kitty.conf"
  chown -R "$USER_NAME:$USER_NAME" "${USER_HOME}/.config/kitty"
  echo "[setup-terminal] kitty.conf скопирован"
fi

echo "[setup-terminal] Установка шрифтов для кодинга..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  fonts-jetbrains-mono \
  fonts-fira-code \
  fonts-cascadia-code \
  || true

echo "[setup-terminal] Готово."

