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

echo "[minimal-packages] Установка базовых серверных утилит..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  htop \
  curl \
  wget \
  unzip \
  zip \
  p7zip-full \
  git \
  build-essential \
  ca-certificates \
  software-properties-common \
  linux-image-generic \
  linux-headers-generic \
  initramfs-tools \
  squashfs-tools \
  casper \
  virtualbox-guest-utils \
  neofetch \
  nano \
  vim-tiny \
  net-tools \
  iputils-ping \
  traceroute \
  network-manager \
  tree \
  mc \
  tmux \
  zsh \
  sudo \
  || true

echo "[minimal-packages] Обновление initramfs для live-boot..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u || echo "[minimal-packages] Warning: Failed to update initramfs"
else
  echo "[minimal-packages] Skipping initramfs update (command not found)"
fi

echo "[minimal-packages] Базовые серверные утилиты установлены."
echo "[minimal-packages] Готово."
