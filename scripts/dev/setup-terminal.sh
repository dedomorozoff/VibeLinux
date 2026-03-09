#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки терминала Kitty для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${1:-root}"
USER_HOME="/home/${USER_NAME}"
BRANDING_DIR="/root/branding"

echo "[setup-terminal] Установка Kitty..."
apt-get update -y || true
DEBIAN_FRONTEND=noninteractive apt-get install -y kitty || true

echo "[setup-terminal] Копирование конфигов..."
mkdir -p "${USER_HOME}/.config/kitty"

# Копируем из branding если есть
if [[ -f "${BRANDING_DIR}/config/kitty/kitty.conf" ]]; then
  cp "${BRANDING_DIR}/config/kitty/kitty.conf" "${USER_HOME}/.config/kitty/kitty.conf"
  echo "[setup-terminal] Конфиг скопирован из branding"
elif [[ -f "/root/kitty.conf" ]]; then
  cp "/root/kitty.conf" "${USER_HOME}/.config/kitty/kitty.conf"
  echo "[setup-terminal] Конфиг скопирован из /root"
else
  echo "[setup-terminal] ВНИМАНИЕ: kitty.conf не найден, используется стандартный"
fi
chown -R "$USER_NAME:$USER_NAME" "${USER_HOME}/.config/kitty" 2>/dev/null || true

echo "[setup-terminal] Установка шрифтов для кодинга..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  fonts-jetbrains-mono \
  fonts-fira-code \
  fonts-cascadia-code \
  fonts-hack \
  || true

echo "[setup-terminal] Готово."

