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

# Базовый набор нужен для live-сессии и дальнейшей настройки chroot.
echo "[minimal-packages] Установка обязательных пакетов..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  systemd \
  systemd-sysv \
  casper \
  live-config \
  live-config-doc \
  sudo \
  network-manager \
  iputils-ping \
  curl \
  wget \
  ca-certificates \
  zsh \
  tmux \
  nano \
  vim-tiny \
  htop \
  unzip \
  squashfs-tools

# VirtualBox guest tools не должны ломать сборку ISO, если пакет недоступен
# или его postinst ведёт себя нестабильно в chroot.
echo "[minimal-packages] Установка опциональных утилит виртуализации..."
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  virtualbox-guest-utils \
; then
  echo "[minimal-packages] WARNING: virtualbox-guest-utils не установился, продолжаем без него"
fi

echo "[minimal-packages] Базовые серверные утилиты установлены."
echo "[minimal-packages] Готово."
