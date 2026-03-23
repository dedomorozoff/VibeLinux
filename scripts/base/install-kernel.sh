#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки ядра для VibeCode OS Minimal.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-kernel] Обновление списка пакетов..."
apt-get update -y

echo "[install-kernel] Установка ядра Linux..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  linux-image-generic \
  linux-modules-generic \
  initramfs-tools \
  || true

echo "[install-kernel] Обновление initramfs..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u -k all || echo "[install-kernel] Warning: Failed to update initramfs"
else
  echo "[install-kernel] update-initramfs not found"
fi

echo "[install-kernel] Ядро установлено."
