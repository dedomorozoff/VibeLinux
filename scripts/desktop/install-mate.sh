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

echo "[desktop/mate] Включение universe/multiverse репозиториев..."
add-apt-repository -y universe 2>/dev/null || true
add-apt-repository -y multiverse 2>/dev/null || true
add-apt-repository -y restricted 2>/dev/null || true

echo "[desktop/mate] Обновление списка пакетов..."
apt-get update -y

echo "[desktop/mate] Удаление GNOME (если есть) для предотвращения конфликтов..."
apt-get remove --purge -y \
  gnome-shell \
  gnome-session \
  gnome-software \
  gnome-control-center \
  gnome-terminal \
  gnome-calculator \
  gnome-calendar \
  gnome-contacts \
  gnome-disk-utility \
  gnome-font-viewer \
  gnome-logs \
  gnome-maps \
  gnome-screenshot \
  gnome-system-monitor \
  gnome-text-editor \
  gnome-weather \
  nautilus \
  eog \
  evince \
  totem \
  cheese \
  simple-scan \
  yelp \
  2>/dev/null || true
apt-get autoremove -y

echo "[desktop/mate] Установка MATE (черновой вариант)..."

case "$PROFILE" in
  minimal)
    echo "[desktop/mate] Установка минимального MATE..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      mate-desktop-environment-core \
      lightdm \
      lightdm-gtk-greeter \
      || true
    ;;
  standard|*)
    echo "[desktop/mate] Установка полного MATE desktop..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      mate-desktop-environment \
      mate-desktop-environment-extras \
      lightdm \
      lightdm-gtk-greeter \
      ubuntu-mate-themes \
      mate-themes \
      || true
    ;;
esac

echo "[desktop/mate] Настройка LightDM как дисплей-менеджера по умолчанию (при необходимости)..."
if command -v debconf-set-selections >/dev/null 2>&1; then
  echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections || true
fi

echo "[desktop/mate] Установка русской локали..."
DEBIAN_FRONTEND=noninteractive apt-get install -y language-pack-ru-base
locale-gen ru_RU.UTF-8 || true
update-locale LANG=ru_RU.UTF-8 || true

echo "[desktop/mate] Готово. Список пакетов и конфигурация будут уточняться по мере развития alpha-образа."

