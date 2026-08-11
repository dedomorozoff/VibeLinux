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
  linux-generic \
  initramfs-tools \
  linux-firmware

echo "[install-kernel] Обновление initramfs..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u -k all
else
  echo "[install-kernel] ERROR: update-initramfs not found"
  exit 1
fi

if ! ls /boot/vmlinuz-* >/dev/null 2>&1; then
  echo "[install-kernel] ERROR: После установки не найдено ядро в /boot"
  exit 1
fi

if ! ls /boot/initrd.img-* >/dev/null 2>&1; then
  echo "[install-kernel] ERROR: После установки не найден initrd в /boot"
  exit 1
fi

echo "[install-kernel] Ядро и initrd успешно установлены."
