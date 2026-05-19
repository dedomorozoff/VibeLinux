#!/usr/bin/env bash
set -euo pipefail

# Draft script to install KDE Plasma desktop for VibeCode OS.
# Target: Ubuntu 24.04 (noble) or compatible, running with root privileges.
#
# Modes:
#   - minimal  — на базе kde-plasma-desktop (минимальная KDE без лишних приложений).
#   - standard — на базе kde-full (полный KDE Plasma с приложениями, дефолт для alpha).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

PROFILE="${PROFILE:-standard}" # minimal|standard

echo "[desktop/kde] Включение universe/multiverse репозиториев..."
add-apt-repository -y universe 2>/dev/null || true
add-apt-repository -y multiverse 2>/dev/null || true
add-apt-repository -y restricted 2>/dev/null || true

echo "[desktop/kde] Обновление списка пакетов..."
apt-get update -y

echo "[desktop/kde] Удаление GNOME (если есть) для предотвращения конфликтов..."
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

# Не запускаем autoremove сразу — сначала установим KDE, потом очистим
# autoremove может удалить Firefox, если он считается ненужным

echo "[desktop/kde] Установка KDE Plasma (черновой вариант)..."

case "$PROFILE" in
  minimal)
    echo "[desktop/kde] Установка минимального KDE Plasma..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      kde-plasma-desktop \
      sddm \
      || true
    ;;
  standard|*)
    echo "[desktop/kde] Установка полного KDE Plasma desktop..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      kde-full \
      sddm \
      || true
    ;;
esac

echo "[desktop/kde] Настройка SDDM как дисплей-менеджера по умолчанию (при необходимости)..."
if command -v debconf-set-selections >/dev/null 2>&1; then
  echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections || true
fi

echo "[desktop/kde] Установка полной поддержки русского языка..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  language-pack-ru \
  language-pack-ru-base \
  language-pack-gnome-ru \
  language-pack-gnome-ru-base \
  kde-l10n-ru \
  locales \
  || true

# Генерация локали
echo "[desktop/kde] Генерация локали ru_RU.UTF-8..."
sed -i 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
locale-gen ru_RU.UTF-8 || true
update-locale LANG=ru_RU.UTF-8 LANGUAGE=ru_RU:ru || true

# Настройка раскладки клавиатуры (RU/US с переключением по Alt+Shift)
echo "[desktop/kde] Настройка раскладки клавиатуры (RU/US)..."
cat > /etc/default/keyboard << 'KEYBOARDEOF'
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=",typewriter"
XKBOPTIONS="grp:alt_shift_toggle,grp_led:scroll"
BACKSPACE="guess"
KEYBOARDEOF

echo "[desktop/kde] Очистка ненужных пакетов (с защитой systemd)..."
# Используем --important для защиты критических пакетов
apt-get autoremove -y --important

# Проверка что systemd на месте после autoremove
if [ ! -f /lib/systemd/systemd ]; then
    echo "ERROR: systemd был удалён! Восстанавливаем..."
    apt-get install -y systemd systemd-sysv
fi

# Восстанавливаем symlink /sbin/init если нужен
if [ ! -e /sbin/init ]; then
    ln -sf /lib/systemd/systemd /sbin/init
fi

echo "[desktop/kde] Готово. Список пакетов и конфигурация будут уточняться по мере развития alpha-образа."
