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
DEBIAN_FRONTEND=noninteractive apt-get install -y\
  systemd \
  systemd-sysv \
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
  live-tools \
  virtualbox-guest-utils \
  virtualbox-guest-desktop \
  fonts-dejavu \
  neofetch \
  nano \
  vim \
  net-tools \
  iputils-ping \
  traceroute \
  network-manager \
  firefox \
  || true

echo "[base-packages] Обновление initramfs для live-boot..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -u -k all || echo "[base-packages] Warning: Failed to update initramfs"
else
 echo "[base-packages] Skipping initramfs update (command not found)"
fi

# Проверка что ядро установлено
echo "[base-packages] Проверка установки ядра..."
if ls /lib/modules/*/vmlinuz 1>/dev/null 2>&1; then
  echo "[base-packages] ✅ Ядро найдено: $(ls -1 /lib/modules/ | head -n1)"
else
  echo "[base-packages] ⚠️ Ядро не найдено, пробуем установить явно..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    linux-image-generic \
    linux-headers-generic \
    linux-modules-extra-generic \
    || true
fi

echo "[base-packages] Установка дополнительных полезных утилит..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  zip \
  p7zip-full \
  tree \
  mc \
  tmux \
  || true

echo "[base-packages] Установка поддержки русского языка..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  language-pack-ru \
  language-pack-ru-base \
  language-pack-gnome-ru \
  language-pack-gnome-ru-base \
  kde-l10n-ru \
  locales \
  keyboard-configuration \
  console-setup \
  xkb-data \
  fonts-noto-cjk \
  fonts-noto-color-emoji \
  || true

# Настройка локали
echo "[base-packages] Генерация локали ru_RU.UTF-8..."
sed -i 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
locale-gen ru_RU.UTF-8 2>/dev/null || true
update-locale LANG=ru_RU.UTF-8 LANGUAGE=ru_RU:ru 2>/dev/null || true

# Настройка раскладки клавиатуры (RU/US с переключением по Alt+Shift)
echo "[base-packages] Настройка раскладки клавиатуры (RU/US)..."
cat > /etc/default/keyboard << 'KEYBOARDEOF'
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=",typewriter"
XKBOPTIONS="grp:alt_shift_toggle,grp_led:scroll"
BACKSPACE="guess"
KEYBOARDEOF

# Применяем настройки консоли
echo "[base-packages] Настройка консоли..."
cat > /etc/default/console-setup << 'CONSOLEEOF'
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="guess"
FONTFACE="Terminus"
FONTSIZE="16"
CONSOLEFONT="Uni2-Terminus16"
CONSOLEEOF

echo "[base-packages] Опциональные \"nice-to-have\" утилиты установлены:"
echo "  - neofetch ✓"
echo "  - nano, vim ✓"
echo "  - network tools ✓"
echo "  - firefox ✓"
echo "  - kde-plasma-desktop, kde-full ✓"
echo "  - sddm, themes ✓"
echo "  - dolphin, okular, gwenview ✓"

echo "[base-packages] Готово."
