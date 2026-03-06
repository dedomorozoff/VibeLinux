#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки базовых утилит для VibeCode OS.
# Ожидается, что выполняется в Ubuntu 24.04 (или совместимой) с правами sudo.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[base-packages] Включение universe/multiverse в sources.list (если ещё не включены)..."
if [[ -f /etc/apt/sources.list ]]; then
  sed -i 's/^\(deb .*main\)\(.*\)$/\1 universe multiverse restricted\2/' /etc/apt/sources.list || true
fi

echo "[base-packages] Обновление списка пакетов..."
apt-get update -y

echo "[base-packages] Установка базовых утилит + VirtualBox guest + шрифты..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  htop \
  curl \
  wget \
  unzip \
  git \
  build-essential \
  ca-certificates \
  software-properties-common \
  linux-image-generic \
  linux-headers-generic \
  initramfs-tools \
  squashfs-tools \
  casper \
  virtualbox-guest-x11 \
  virtualbox-guest-utils \
  fonts-dejavu \
  neofetch \
  nano \
  vim \
  net-tools \
  iputils-ping \
  traceroute \
  network-manager \
  chromium-browser \
  || true

echo "[base-packages] Обновление initramfs для live-boot..."
update-initramfs -u

echo "[base-packages] Установка дополнительных полезных утилит..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  zip \
  p7zip-full \
  tree \
  mc \
  tmux \
  || true

echo "[base-packages] Опциональные \"nice-to-have\" утилиты установлены:"
echo "  - neofetch ✓"
echo "  - nano, vim ✓"
echo "  - network tools ✓"
echo "  - chromium-browser ✓"

echo "[base-packages] Готово."

