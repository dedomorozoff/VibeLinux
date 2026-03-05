#!/usr/bin/env bash
set -euo pipefail

# Скрипт применения брендинга VibeCode OS

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
mkdir -p "/home/${TARGET_USER}/.config/gtk-3.0"
mkdir -p "/home/${TARGET_USER}/.themes"

# Копируем обои
if [[ -d "${BRANDING_DIR}/wallpapers" ]]; then
  echo "[branding] Копирование обоев..."
  cp -r "${BRANDING_DIR}/wallpapers"/* "/home/${TARGET_USER}/.local/share/backgrounds/" 2>/dev/null || true
  cp -r "${BRANDING_DIR}/wallpapers"/* /usr/share/backgrounds/ 2>/dev/null || true
fi

# Копируем логотипы
if [[ -d "${BRANDING_DIR}/logos" ]]; then
  echo "[branding] Копирование логотипов..."
  mkdir -p /usr/share/pixmaps/vibecodeos
  cp -r "${BRANDING_DIR}/logos"/* /usr/share/pixmaps/vibecodeos/ 2>/dev/null || true
fi

# Настройка темы MATE
echo "[branding] Настройка темы MATE..."

# Устанавливаем популярные темы
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  arc-theme \
  papirus-icon-theme \
  materia-gtk-theme \
  dconf-cli \
  || true

# Применяем настройки напрямую через dconf (для Live-сессии)
echo "[branding] Применение настроек темы для пользователя ${TARGET_USER}..."

# Создаём dconf профиль пользователя
mkdir -p "/home/${TARGET_USER}/.config/dconf"

# Применяем настройки через dconf dump/load
cat > "/tmp/vibecodeos-settings.ini" << 'DCONFEOF'
[org/mate/desktop/interface]
gtk-theme='Arc-Dark'
icon-theme='Papirus-Dark'
monospace-font-name='JetBrains Mono 11'

[org/mate/desktop/background]
picture-filename='/usr/share/backgrounds/vibecode-dark.svg'
picture-options='zoom'
primary-color='#0B1020'
secondary-color='#0B1020'

[org/mate/terminal/profiles/default]
use-system-font=false
font='JetBrains Mono 11'
use-theme-colors=false
background-color='#0B1020'
foreground-color='#4CC9F0'
palette='#0B1020:#FF6B6B:#4CC9F0:#FFE066:#7209B7:#F72585:#2EC4B6:#FFFFFF:#0B1020:#FF6B6B:#4CC9F0:#FFE066:#7209B7:#F72585:#2EC4B6:#FFFFFF'
DCONFEOF

# Копируем настройки в домашнюю директорию пользователя для применения при первом входе
cp /tmp/vibecodeos-settings.ini "/home/${TARGET_USER}/.vibecodeos-settings.ini"
chown "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.vibecodeos-settings.ini"

# Создаём скрипт автонастройки темы при первом входе
cat > "/usr/local/bin/vibecodeos-theme-setup.sh" << 'THEMEEOF'
#!/usr/bin/env bash
# Скрипт настройки темы VibeCode OS при первом входе

MARKER="$HOME/.config/vibecodeos-theme-configured"

# Создаём директорию .config если её нет
mkdir -p "$HOME/.config"

if [[ -f "$MARKER" ]]; then
  exit 0
fi

# Ждём загрузки MATE
sleep 2

# Применяем настройки через dconf если файл существует
if [[ -f "$HOME/.vibecodeos-settings.ini" ]]; then
  dconf load / < "$HOME/.vibecodeos-settings.ini" 2>/dev/null || true
fi

# Настраиваем тему GTK (fallback если dconf не сработал)
gsettings set org.mate.interface gtk-theme 'Arc-Dark' 2>/dev/null || true
gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null || true

# Настраиваем обои
WALLPAPER="/usr/share/backgrounds/vibecode-dark.svg"
if [[ -f "$WALLPAPER" ]]; then
  gsettings set org.mate.background picture-filename "$WALLPAPER" 2>/dev/null || true
  gsettings set org.mate.background picture-options 'zoom' 2>/dev/null || true
  gsettings set org.mate.background primary-color '#0B1020' 2>/dev/null || true
fi

# Настраиваем шрифты
gsettings set org.mate.interface monospace-font-name 'JetBrains Mono 11' 2>/dev/null || true

# Настраиваем терминал
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/default/ use-system-font false 2>/dev/null || true
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/default/ font 'JetBrains Mono 11' 2>/dev/null || true
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/default/ use-theme-colors false 2>/dev/null || true
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/default/ background-color '#0B1020' 2>/dev/null || true
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/default/ foreground-color '#4CC9F0' 2>/dev/null || true

# Отмечаем, что настройка выполнена
touch "$MARKER"
THEMEEOF

chmod +x "/usr/local/bin/vibecodeos-theme-setup.sh"

# Добавляем автозапуск настройки темы
mkdir -p "/home/${TARGET_USER}/.config/autostart"
cat > "/home/${TARGET_USER}/.config/autostart/vibecodeos-theme.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=VibeCode OS Theme Setup
Exec=/usr/local/bin/vibecodeos-theme-setup.sh
Hidden=false
NoDisplay=true
X-MATE-Autostart-enabled=true
EOF

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

# Настройки ASCII-арта
image_backend="ascii"
ascii_distro="auto"
ascii_colors=(6 7 1 8 3 2)
ascii_bold="on"

# Цвета
colors=(6 7 7 6 7 7)
NEOFETCHEOF
fi

# Создаём приветственное сообщение в .bashrc
if [[ ! -f "/home/${TARGET_USER}/.bashrc" ]]; then
  touch "/home/${TARGET_USER}/.bashrc"
fi

# Проверяем, не добавлено ли уже
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

echo "[branding] Брендинг применён."
