#!/usr/bin/env bash
set -euo pipefail

# Скрипт применения брендинга VibeCode OS для KDE Plasma

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

BRANDING_DIR="${1:-/root/branding}"
TARGET_USER="${2:-vibecode}"

echo "[branding] Применение брендинга VibeCode OS..."

# Установка дополнительных шрифтов для кодинга
echo "[branding] Установка шрифтов для кодинга..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  fonts-jetbrains-mono \
  fonts-firacode \
  || true

# Создаём директории для пользовательских настроек
mkdir -p "/home/${TARGET_USER}/.local/share/backgrounds"
mkdir -p "/home/${TARGET_USER}/.local/share/icons"
mkdir -p "/home/${TARGET_USER}/.config"
mkdir -p "/home/${TARGET_USER}/.themes"

# Копируем обои
if [[ -d "${BRANDING_DIR}/wallpapers" ]]; then
  echo "[branding] Копирование обоев..."
  mkdir -p /usr/share/backgrounds
  cp -r "${BRANDING_DIR}/wallpapers"/* "/home/${TARGET_USER}/.local/share/backgrounds/" 2>/dev/null || true
  cp -r "${BRANDING_DIR}/wallpapers"/* /usr/share/backgrounds/ 2>/dev/null || true
  if [[ -f /usr/share/backgrounds/vibecode-dark.svg ]]; then
    : # already copied
  else
    first_system_wallpaper="$(find /usr/share/backgrounds -maxdepth 1 -type f -name '*.svg' | head -n 1)"
    if [[ -n "${first_system_wallpaper}" ]]; then
      cp "${first_system_wallpaper}" /usr/share/backgrounds/vibecode-dark.svg 2>/dev/null || true
    fi
  fi
fi

# Копируем логотипы
if [[ -d "${BRANDING_DIR}/logos" ]]; then
  echo "[branding] Копирование логотипов..."
  mkdir -p /usr/share/pixmaps/vibecodeos
  cp -r "${BRANDING_DIR}/logos"/* /usr/share/pixmaps/vibecodeos/ 2>/dev/null || true
fi

# Настройка темы KDE Plasma
echo "[branding] Настройка темы KDE Plasma..."

# Устанавливаем популярные темы
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  arc-theme \
  papirus-icon-theme \
  materia-kde \
  plymouth-themes \
  || true

# Настройка Plymouth темы загрузки
echo "[branding] Настройка Plymouth темы загрузки..."
if [[ -d "${BRANDING_DIR}/plymouth" ]]; then
  cp -r "${BRANDING_DIR}/plymouth"/* /usr/share/plymouth/themes/ 2>/dev/null || true
  update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/vibecode/vibecode.plymouth 100 2>/dev/null || true
  update-alternatives --set default.plymouth /usr/share/plymouth/themes/vibecode/vibecode.plymouth 2>/dev/null || true
  plymouth-set-default-theme vibecode 2>/dev/null || true
fi

# Создаём скрипт автонастройки темы при первом входе
cat > "/usr/local/bin/vibecodeos-theme-setup.sh" << 'THEMEEOF'
#!/usr/bin/env bash
# Скрипт настройки темы VibeCode OS при первом входе

MARKER="$HOME/.config/vibecodeos-theme-configured"

mkdir -p "$HOME/.config"

if [[ -f "$MARKER" ]]; then
  exit 0
fi

sleep 3

# KDE Plasma настройки через kwriteconfig5
kwriteconfig5 --file kdeglobals --group General --key AccentColor "#4CC9F0" 2>/dev/null || true
kwriteconfig5 --file kdeglobals --group WM --group Colors --group Active --key BackgroundNormal "#0B1020" 2>/dev/null || true

# Обои KDE Plasma
WALLPAPER="/usr/share/backgrounds/vibecode-dark.svg"
if [[ -f "$WALLPAPER" ]]; then
  kwriteconfig5 --file plasmarc --group Wallpaper --group org.kde.image --group General --key Image "$WALLPAPER" 2>/dev/null || true
fi

# Шрифт KDE
kwriteconfig5 --file kdeglobals --group General --key font "JetBrains Mono,11,-1,5,50,0,0,0,0,0,0,0,0,0,0,1" 2>/dev/null || true
kwriteconfig5 --file kdeglobals --group General --key fixed "JetBrains Mono,11,-1,5,50,0,0,0,0,0,0,0,0,0,0,1" 2>/dev/null || true

touch "$MARKER"
THEMEEOF

chmod +x "/usr/local/bin/vibecodeos-theme-setup.sh"

# Создаём настройки в /etc/skel для live-сессии
echo "[branding] Настройка /etc/skel для live-сессии..."
mkdir -p /etc/skel/.config
mkdir -p /etc/skel/.config/autostart
mkdir -p /etc/skel/.local/share/backgrounds

# Копируем обои в /etc/skel
if [[ -d "${BRANDING_DIR}/wallpapers" ]]; then
  cp -r "${BRANDING_DIR}/wallpapers"/* /etc/skel/.local/share/backgrounds/ 2>/dev/null || true
  if [[ -f "${BRANDING_DIR}/wallpapers"/*.svg ]]; then
    cp "${BRANDING_DIR}/wallpapers"/*.svg /etc/skel/.local/share/backgrounds/vibecode-dark.svg 2>/dev/null || true
  fi
fi

# Добавляем автозапуск настройки темы
mkdir -p "/home/${TARGET_USER}/.config/autostart"
cat > "/home/${TARGET_USER}/.config/autostart/vibecodeos-theme.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=VibeCode OS Theme Setup
Exec=/usr/local/bin/vibecodeos-theme-setup.sh
Hidden=false
NoDisplay=true
X-KDE-autostart-condition=true
EOF

# Копируем autostart в /etc/skel после создания файла
cp "/home/${TARGET_USER}/.config/autostart/vibecodeos-theme.desktop" /etc/skel/.config/autostart/ 2>/dev/null || true

# Настройка neofetch для показа ASCII-логотипа
if [[ -f "${BRANDING_DIR}/logos/ascii-logo.txt" ]]; then
  echo "[branding] Настройка neofetch..."
  mkdir -p "/home/${TARGET_USER}/.config/neofetch"
  
  cat > "/home/${TARGET_USER}/.config/neofetch/config.conf" << 'NEOFETCHEOF'
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "Terminal" term
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info cols
}

image_backend="ascii"
ascii_distro="auto"
ascii_colors=(6 7 1 8 3 2)
ascii_bold="on"
colors=(6 7 7 6 7 7)
NEOFETCHEOF
fi

# Создаём приветственное сообщение в .bashrc
if [[ ! -f "/home/${TARGET_USER}/.bashrc" ]]; then
  touch "/home/${TARGET_USER}/.bashrc"
fi

if ! grep -q "VibeCode OS приветствие" "/home/${TARGET_USER}/.bashrc"; then
  cat >> "/home/${TARGET_USER}/.bashrc" << 'BASHEOF'

# VibeCode OS приветствие
if [[ -f /usr/share/pixmaps/vibecodeos/ascii-logo.txt ]]; then
  cat /usr/share/pixmaps/vibecodeos/ascii-logo.txt
  echo ""
fi
BASHEOF
fi

# Устанавливаем права
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}"

echo "[branding] Готово."
