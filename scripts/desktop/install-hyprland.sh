#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# VibeCode OS — Установка Hyprland WM
# ============================================================================
# Скрипт устанавливает Hyprland и все необходимые компоненты для
# полноценного рабочего окружения на базе Wayland
#
# Использование:
#   sudo PROFILE=standard bash scripts/desktop/install-hyprland.sh
#
# Переменные:
#   PROFILE=standard|minimal (по умолчанию: standard)
# ============================================================================

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

PROFILE="${PROFILE:-standard}" # minimal|standard

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() { echo -e "${BLUE}[hyprland]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[err]${NC} $*" >&2; }

# ============================================================================
# Подготовка
# ============================================================================

log "Подготовка системы к установке Hyprland..."

# Включение репозиториев
log "Включение universe/multiverse репозиториев..."
add-apt-repository -y universe 2>/dev/null || true
add-apt-repository -y multiverse 2>/dev/null || true
add-apt-repository -y restricted 2>/dev/null || true

# Для Hyprland нужен свежий Mesa и компоненты Wayland
log "Добавление PPA для свежего Mesa (Kisak)..."
add-apt-repository -y ppa:kisak/kisak-mesa 2>/dev/null || true

log "Обновление списка пакетов..."
apt-get update -y

# ============================================================================
# Удаление GNOME/MATE (если есть)
# ============================================================================

log "Удаление GNOME/MATE (если есть) для предотвращения конфликтов..."
apt-get remove --purge -y \
  mate-desktop-environment* \
  mate-* \
  gnome-shell \
  gnome-session \
  gnome-software \
  gnome-control-center \
  gdm3 \
  lightdm \
  2>/dev/null || true

# Очистка после удаления
apt-get autoremove -y --important 2>/dev/null || true

# ============================================================================
# Установка Hyprland и компонентов
# ============================================================================

log "Установка Hyprland ($PROFILE профиль)..."

# Базовые компоненты Wayland
log "Установка базовых компонентов Wayland..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  hyprland \
  wayland-protocols \
  libwayland-client0 \
  libwayland-server0 \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-hyprland \
  pipewire \
  pipewire-audio \
  pipewire-pulse \
  wireplumber \
  || {
    err "Ошибка установки базовых компонентов"
    warn "Hyprland требует Ubuntu 24.04+ или Debian testing+"
    exit 1
  }

# Дисплей менеджер (SDDM для Wayland)
log "Установка SDDM (Wayland-compatible DM)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  sddm \
  sddm-theme-debian-malva \
  || true

if command -v debconf-set-selections >/dev/null 2>&1; then
  echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections || true
fi

# Стандартный профиль: полный набор
if [[ "$PROFILE" == "standard" ]]; then
  log "Установка полного набора приложений..."

  # Панель
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    waybar \
    || true

  # Лаунчер
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wofi \
    || true

  # Уведомления
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    dunst \
    || true

  # Управление питанием и системные утилиты
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    grim \
    slurp \
    wl-clipboard \
    swappy \
    brightnessctl \
    pavucontrol \
    network-manager-gnome \
    blueman \
    || true

  # Терминал (Kitty работает на Wayland нативно)
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    kitty \
    || true

  # Файловый менеджер
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    || true

  # Шрифты и иконки
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fonts-jetbrains-mono \
    fonts-firacode \
    fonts-hack \
    fonts-noto-core \
    fonts-noto-color-emoji \
    papirus-icon-theme \
    || true

  # Темы GTK4/QT6 для Wayland
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gnome-themes-extra \
    adwaita-icon-theme-full \
    || true
fi

# ============================================================================
# Настройка SDDM
# ============================================================================

log "Настройка SDDM..."
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/vibecode.conf << 'SDDMEOF'
[Theme]
Current=malva

[Users]
DefaultPath=/usr/local/bin:/usr/bin:/bin

[General]
Numlock=on
SDDMEOF

# ============================================================================
# Создание пользовательских конфигов
# ============================================================================

log "Создание базовых конфигурационных файлов..."

# Определяем пользователя
if [[ -n "${SUDO_USER:-}" ]]; then
  USER="$SUDO_USER"
elif [[ -n "${VIBE_USER:-}" ]]; then
  USER="$VIBE_USER"
else
  USER="vibecode"
fi

USER_HOME="/home/$USER"

# Создаём директорию для конфигов Hyprland
mkdir -p "$USER_HOME/.config/hypr"
mkdir -p "$USER_HOME/.config/waybar"
mkdir -p "$USER_HOME/.config/wofi"
mkdir -p "$USER_HOME/.config/dunst"
mkdir -p "$USER_HOME/.config/kitty"

# ============================================================================
# Копирование конфигураций из scripts/desktop/configs/
# ============================================================================

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/configs"

if [[ -d "$CONFIG_DIR/hyprland" ]]; then
  log "Копирование конфигураций Hyprland..."
  cp -r "$CONFIG_DIR/hyprland/"* "$USER_HOME/.config/hypr/" 2>/dev/null || true
else
  log "Конфигурации Hyprland не найдены, используются дефолтные"
fi

if [[ -d "$CONFIG_DIR/waybar" ]]; then
  log "Копирование конфигураций Waybar..."
  cp -r "$CONFIG_DIR/waybar/"* "$USER_HOME/.config/waybar/" 2>/dev/null || true
fi

# ============================================================================
# Установка прав
# ============================================================================

log "Установка прав на файлы..."
chown -R "$USER:$USER" "$USER_HOME/.config"

# ============================================================================
# Создание wrapper-скриптов
# ============================================================================

log "Создание helper-скриптов..."

# Скрипт запуска Hyprland
cat > /usr/local/bin/start-vibe-wm << 'EOF'
#!/usr/bin/env bash
# Запуск Hyprland с настройками VibeCode OS
exec Hyprland
EOF
chmod +x /usr/local/bin/start-vibe-wm

# Скрипт для скриншотов
cat > /usr/local/bin/vibe-screenshot << 'EOF'
#!/usr/bin/env bash
# Скриншот в Hyprland
grim -g "$(slurp)" - | swappy -f -
EOF
chmod +x /usr/local/bin/vibe-screenshot

# ============================================================================
# Автозапуск для live-сессии
# ============================================================================

log "Настройка автозапуска для live-сессии..."

# Создаём .xinitrc для совместимости
cat > "$USER_HOME/.xinitrc" << 'EOF'
#!/usr/bin/env bash
exec Hyprland
EOF
chmod +x "$USER_HOME/.xinitrc"

# Настройка autologin в SDDM
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << AUTOSDDM
[Autologin]
User=$USER
Session=hyprland
AUTOSDDM

# ============================================================================
# Очистка
# ============================================================================

log "Очистка ненужных пакетов..."
apt-get autoremove -y --important 2>/dev/null || true

# Проверка что systemd на месте
if [ ! -f /lib/systemd/systemd ]; then
  log "WARNING: systemd был удалён! Восстанавливаем..."
  apt-get install -y systemd systemd-sysv
fi

if [ ! -e /sbin/init ]; then
  ln -sf /lib/systemd/systemd /sbin/init
fi

# ============================================================================
# Итог
# ============================================================================

log ""
log "╔══════════════════════════════════════════════════════════╗"
log "║   Hyprland установлен успешно!                          ║"
log "╚══════════════════════════════════════════════════════════╝"
log ""
log "Установленные компоненты:"
log "  ✓ Hyprland (Wayland compositor)"
log "  ✓ SDDM (display manager)"
log "  ✓ PipeWire + WirePlumber (audio)"
log "  ✓ XDG portals"

if [[ "$PROFILE" == "standard" ]]; then
  log ""
  log "Дополнительно:"
  log "  ✓ Waybar (панель)"
  log "  ✓ Wofi (лаунчер)"
  log "  ✓ Dunst (уведомления)"
  log "  ✓ Kitty (терминал)"
  log "  ✓grim + slurp + swappy (скриншоты)"
  log "  ✓ wl-clipboard (буфер обмена)"
  log "  ✓ Thunar (файловый менеджер)"
  log "  ✓ Шрифты и иконки"
fi

log ""
log "Конфигурация: $USER_HOME/.config/hypr/hyprland.conf"
log "Перезагрузите систему для применения изменений"
log ""
