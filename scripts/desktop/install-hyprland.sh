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

log "Удаление GNOME/KDE (если есть) для предотвращения конфликтов..."
apt-get remove --purge -y \
  kde-plasma-desktop* \
  kde-full* \
  sddm* \
  gnome-shell \
  gnome-session \
  gnome-software \
  gnome-control-center \
  gdm3 \
  2>/dev/null || true

# Очистка после удаления
apt-get autoremove -y --important 2>/dev/null || true

# ============================================================================
# Установка Hyprland из исходников
# ============================================================================

log "Установка Hyprland из исходников ($PROFILE профиль)..."
log "Внимание: это займёт значительное время (компиляция C++ проекта)..."

# ---------------------------------------------------------------------------
# Шаг 1: Установка системных зависимостей
# ---------------------------------------------------------------------------

log "Шаг 1/5: Установка системных зависимостей..."

# Обновляем компиляторы (Hyprland требует gcc >= 15 или clang >= 19 для C++26)
log "Добавление PPA для свежего gcc..."
add-apt-repository -y ppa:ubuntu-toolchain-r/test -y 2>/dev/null || true
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y gcc-15 g++-15 || {
  warn "gcc-15 недоступен, пробуем clang..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y clang-19 || {
    err "Не удалось установить современный компилятор (gcc-15 или clang-19)"
    err "Hyprland требует C++26, который поддерживается gcc >= 15 или clang >= 19"
    exit 1
  }
  export CC=clang-19
  export CXX=clang++-19
}
export CC=gcc-15
export CXX=g++-15

DEBIAN_FRONTEND=noninteractive apt-get install -y \
  meson wget build-essential ninja-build cmake-extras cmake \
  fontconfig libfontconfig-dev libffi-dev libxml2-dev libdrm-dev \
  libxkbcommon-x11-dev libxkbregistry-dev libxkbcommon-dev \
  libpixman-1-dev libudev-dev libseat-dev seatd \
  libxcb-dri3-dev libegl-dev libgles2 libegl1-mesa-dev \
  glslang-tools libinput-bin libinput-dev libxcb-composite0-dev \
  libavutil-dev libavcodec-dev libavformat-dev \
  libxcb-ewmh2 libxcb-ewmh-dev libxcb-present-dev \
  libxcb-icccm4-dev libxcb-render-util0-dev libxcb-res0-dev \
  libxcb-xinput-dev libtomlplusplus3 libre2-dev \
  pkg-config libpango1.0-dev libcairo2-dev libgtk-3-dev \
  wayland-protocols xdg-desktop-portal-wlr \
  pipewire pipewire-audio pipewire-pulse wireplumber \
  || {
    err "Ошибка установки системных зависимостей"
    exit 1
  }

# ---------------------------------------------------------------------------
# Шаг 2: Сборка внутренних зависимостей hypr*
# ---------------------------------------------------------------------------

log "Шаг 2/5: Сборка внутренних зависимостей Hyprland..."

HYPR_BUILD_DIR="/tmp/hypr-build"
mkdir -p "$HYPR_BUILD_DIR"
cd "$HYPR_BUILD_DIR"

# Порядок сборки: hyprutils → hyprlang → hyprcursor → hyprgraphics → hyprwayland-scanner → aquamarine → Hyprland
HYPR_DEPS=("hyprutils" "hyprlang" "hyprcursor" "hyprgraphics" "hyprwayland-scanner" "aquamarine")

for dep in "${HYPR_DEPS[@]}"; do
  log "Сборка $dep..."
  if [[ -d "$HYPR_BUILD_DIR/$dep" ]]; then
    rm -rf "$HYPR_BUILD_DIR/$dep"
  fi
  
  git clone --recursive "https://github.com/hyprwm/$dep" "$HYPR_BUILD_DIR/$dep" || {
    err "Не удалось клонировать $dep"
    exit 1
  }
  
  cd "$HYPR_BUILD_DIR/$dep"
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -B build || {
    err "Ошибка конфигурации $dep"
    exit 1
  }
  cmake --build ./build --config Release -j$(nproc) || {
    err "Ошибка сборки $dep"
    exit 1
  }
  cmake --install ./build || {
    err "Ошибка установки $dep"
    exit 1
  }
  
  log "✓ $dep установлен"
done

# ---------------------------------------------------------------------------
# Шаг 3: Сборка и установка Hyprland
# ---------------------------------------------------------------------------

log "Шаг 3/5: Сборка и установка Hyprland (это займёт время)..."

cd "$HYPR_BUILD_DIR"
if [[ -d "$HYPR_BUILD_DIR/Hyprland" ]]; then
  rm -rf "$HYPR_BUILD_DIR/Hyprland"
fi

git clone --recursive "https://github.com/hyprwm/Hyprland" "$HYPR_BUILD_DIR/Hyprland" || {
  err "Не удалось клонировать Hyprland"
  exit 1
}

cd "$HYPR_BUILD_DIR/Hyprland"
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -B build || {
  err "Ошибка конфигурации Hyprland"
  exit 1
}
cmake --build ./build --config Release --target all -j$(nproc) || {
  err "Ошибка сборки Hyprland"
  exit 1
}
cmake --install ./build || {
  err "Ошибка установки Hyprland"
  exit 1
}

log "✓ Hyprland установлен"

# ---------------------------------------------------------------------------
# Шаг 4: Очистка временных файлов сборки
# ---------------------------------------------------------------------------

log "Шаг 4/5: Очистка временных файлов..."
rm -rf "$HYPR_BUILD_DIR"

# ---------------------------------------------------------------------------
# Шаг 5: Установка дополнительных компонентов
# ---------------------------------------------------------------------------

log "Шаг 5/5: Установка дополнительных компонентов..."

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
