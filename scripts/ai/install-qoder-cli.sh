#!/usr/bin/env bash
set -euo pipefail

# Установка Qoder CLI — автономного AI-агента для кодинга (https://qoder.com/cli).
# Официальный установщик: curl -fsSL https://qoder.com/install | bash

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[install-qoder-cli] curl не найден, устанавливаем..."
  if command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed curl ca-certificates
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates
  else
    echo "[install-qoder-cli] Неподдерживаемый пакетный менеджер."
    exit 1
  fi
fi

echo "[install-qoder-cli] Установка Qoder CLI..."
if curl -fsSL --retry 3 https://qoder.com/install | bash; then
  echo "[install-qoder-cli] Qoder CLI установлен. Команда: qoder"
  echo "[install-qoder-cli] Быстрый старт: qoder auth && qoder"
else
  echo "[install-qoder-cli] WARNING: установка Qoder CLI не удалась (offline?)."
  exit 1
fi
