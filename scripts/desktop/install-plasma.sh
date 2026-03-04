#!/usr/bin/env bash
set -euo pipefail

# Draft script to install KDE Plasma desktop for VibeCode OS.
# Target: Ubuntu 24.04 (noble) or compatible, running with root privileges.
#
# Modes (future use):
#   - minimal  — based on kde-plasma-desktop meta-package
#   - standard — based on kde-standard meta-package (default target for alpha)

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

PROFILE="${PROFILE:-standard}" # minimal|standard (пока только описывается)

echo "[desktop/plasma] Обновление списка пакетов..."
apt-get update -y

echo "[desktop/plasma] Установка KDE Plasma (черновой вариант)..."

case "$PROFILE" in
  minimal)
    # Минимальный Plasma без большого набора приложений.
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      kde-plasma-desktop \
      sddm
    ;;
  standard|*)
    # Базовый сбалансированный набор для alpha: Plasma + стандартные приложения.
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      kde-standard \
      sddm
    ;;
esac

echo "[desktop/plasma] Настройка SDDM как дисплей-менеджера по умолчанию (при необходимости)..."
if command -v debconf-set-selections >/dev/null 2>&1; then
  echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections || true
fi

echo "[desktop/plasma] Готово. Список пакетов и конфигурация будут уточняться по мере развития alpha-образа."

