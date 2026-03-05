#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки и настройки установщика Ubuntu (ubiquity) для VibeCode OS

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[installer] Установка ubiquity и зависимостей..."

# Устанавливаем ubiquity и необходимые компоненты
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ubiquity \
  ubiquity-frontend-gtk \
  ubiquity-slideshow-ubuntu \
  ubiquity-ubuntu-artwork \
  gparted \
  || true

echo "[installer] Создание ярлыка установщика на рабочем столе..."

# Создаём директорию Desktop для пользователя vibecode
mkdir -p /home/vibecode/Desktop

# Создаём ярлык установщика
cat > /home/vibecode/Desktop/ubiquity.desktop << 'EOF'
[Desktop Entry]
Name=Установить VibeCode OS
Name[en]=Install VibeCode OS
Comment=Установить систему на жёсткий диск
Comment[en]=Install the system to hard disk
Exec=ubiquity gtk_ui
Icon=system-software-install
Terminal=false
Type=Application
Categories=System;Settings;
StartupNotify=true
EOF

# Делаем ярлык исполняемым и доверенным
chmod +x /home/vibecode/Desktop/ubiquity.desktop

# Устанавливаем права
chown -R vibecode:vibecode /home/vibecode/Desktop

# Настраиваем автозапуск установщика (опционально, закомментировано)
# mkdir -p /home/vibecode/.config/autostart
# cp /home/vibecode/Desktop/ubiquity.desktop /home/vibecode/.config/autostart/
# chown -R vibecode:vibecode /home/vibecode/.config/autostart

echo "[installer] Настройка ubiquity для VibeCode OS..."

# Создаём кастомный конфиг для ubiquity
mkdir -p /etc/ubiquity

cat > /etc/ubiquity/vibecode.conf << 'UBIQUITYEOF'
# VibeCode OS ubiquity configuration

# Название дистрибутива
DISTRIB_ID="VibeCodeOS"
DISTRIB_RELEASE="alpha"
DISTRIB_CODENAME="vibecode"
DISTRIB_DESCRIPTION="VibeCode OS alpha"

# Настройки установщика
UBIQUITY_AUTOMATIC=false
UBIQUITY_ONLY=false
UBIQUITYEOF

echo "[installer] Установщик настроен."
