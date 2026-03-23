#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки минимальных консольных утилит для VibeCode OS Minimal.
# Ожидается, что выполняется в Ubuntu 24.04 (или совместимой) с правами sudo.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[minimal-packages] Включение universe/multiverse в sources.list (если ещё не включены)..."
if [[ -f /etc/apt/sources.list ]]; then
  sed -i 's/^\(deb .*main\)\(.*\)$/\1 universe multiverse restricted\2/' /etc/apt/sources.list || true
fi

echo "[minimal-packages] Обновление списка пакетов..."
apt-get update -y

# БАЗОВАЯ СИСТЕМА: casper, sudo
echo "[minimal-packages] Установка базовой системы..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  casper \
  sudo \
  || true

# СЕТЬ: network-manager, ping, curl, wget, SSL
echo "[minimal-packages] Установка сетевых утилит..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  network-manager \
  iputils-ping \
  curl \
  wget \
  ca-certificates \
  || true

# ТЕРМИНАЛ И ОБОЛОЧКА: zsh, tmux
echo "[minimal-packages] Установка оболочки и терминала..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  zsh \
  tmux \
  || true

# ТЕКСТОВЫЕ РЕДАКТОРЫ: nano, vim-tiny
echo "[minimal-packages] Установка текстовых редакторов..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nano \
  vim-tiny \
  || true

# МОНИТОРИНГ: htop
echo "[minimal-packages] Установка утилит мониторинга..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  htop \
  || true

# АРХИВАТОРЫ: unzip
echo "[minimal-packages] Установка архиваторов..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  unzip \
  || true

# ВИРТУАЛИЗАЦИЯ: virtualbox-guest-utils
echo "[minimal-packages] Установка утилит виртуализации..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  virtualbox-guest-utils \
  || true

echo "[minimal-packages] Базовые серверные утилиты установлены."
echo "[minimal-packages] Готово."
