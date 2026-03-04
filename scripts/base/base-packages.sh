#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки базовых утилит для VibeCode OS.
# Ожидается, что выполняется в Ubuntu 24.04 (или совместимой) с правами sudo.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[base-packages] Обновление списка пакетов..."
apt-get update -y

echo "[base-packages] Установка базовых утилит..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  htop \
  neofetch \
  btop \
  curl \
  wget \
  unzip \
  git \
  build-essential \
  ca-certificates \
  software-properties-common

echo "[base-packages] Готово."

