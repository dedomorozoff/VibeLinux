#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт очистки системы от предустановленного "мусора".
# Задача: показать намерение, а не быть окончательно вылизанным.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[cleanup] Удаление типичных предустановленных пакетов (черновой список)..."

TO_REMOVE=(
  libreoffice-core
  libreoffice-common
  libreoffice-writer
  libreoffice-calc
  libreoffice-impress
  thunderbird
  gnome-games
  ubuntu-games-*
  example-content
  simple-scan
  totem
  cheese
  rhythmbox
  shotwell
)

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "${TO_REMOVE[@]}" || true
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

echo "[cleanup] Очистка кэша APT и временных файлов..."
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache/*
rm -rf /home/vibecode/.cache/* 2>/dev/null || true

echo "[cleanup] Готово."

