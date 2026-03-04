#!/usr/bin/env bash
set -euo pipefail

# Draft script to install MATE desktop for VibeCode OS.
# Target: Ubuntu 24.04 (noble) or compatible, running with root privileges.
#
# Modes:
#   - minimal  — на базе mate-desktop-environment (чистый MATE без полного набора Ubuntu MATE).
#   - standard — на базе ubuntu-mate-desktop (дефолт для alpha).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

PROFILE="${PROFILE:-standard}" # minimal|standard

echo "[desktop/mate] Обновление списка пакетов..."
apt-get update -y

echo "[desktop/mate] Установка MATE (черновой вариант)..."

case "$PROFILE" in
  minimal)
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      mate-desktop-environment \
      lightdm
    ;;
  standard|*)
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ubuntu-mate-desktop \
      lightdm
    ;;
esac

echo "[desktop/mate] Настройка LightDM как дисплей-менеджера по умолчанию (при необходимости)..."
if command -v debconf-set-selections >/dev/null 2>&1; then
  echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections || true
fi

echo "[desktop/mate] Готово. Список пакетов и конфигурация будут уточняться по мере развития alpha-образа."

