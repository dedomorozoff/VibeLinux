#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки терминала Kitty для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${1:-root}"
USER_HOME=""
if command -v getent >/dev/null 2>&1; then
  USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
fi
if [[ -z "${USER_HOME}" ]]; then
  if [[ "${USER_NAME}" == "root" ]]; then
    USER_HOME="/root"
  else
    USER_HOME="/home/${USER_NAME}"
  fi
fi
BRANDING_DIR="/root/branding"

echo "[setup-terminal] Установка Kitty и шрифтов для кодинга..."
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed \
    kitty \
    ttf-jetbrains-mono \
    ttf-fira-code \
    ttf-cascadia-code \
    ttf-hack
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y kitty || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fonts-jetbrains-mono \
    fonts-firacode \
    fonts-cascadia-code \
    fonts-hack \
    || true
else
  echo "[setup-terminal] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

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

echo "[setup-terminal] Готово."

