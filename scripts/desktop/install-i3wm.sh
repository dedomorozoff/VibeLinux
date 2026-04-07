#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# VibeCode OS — Установка i3wm (тайловый оконный менеджер)
# ============================================================================
# Скрипт устанавливает i3wm и все необходимые компоненты для
# полноценного рабочего окружения на базе X11
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

log() { echo -e "${BLUE}[i3wm]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[err]${NC} $*" >&2; }

# ============================================================================
# Подготовка
# ============================================================================

log "Подготовка системы к установке i3wm..."

# Включение репозиториев
log "Включение universe/multiverse репозиториев..."
add-apt-repository -y universe 2>/dev/null || true
add-apt-repository -y multiverse 2>/dev/null || true
add-apt-repository -y restricted 2>/dev/null || true

apt-get update -y

# ============================================================================
# Шаг 1: Установка i3wm и базовых зависимостей
# ============================================================================

log "Шаг 1/3: Установка i3wm и зависимостей..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
  i3 \
  i3lock \
  i3status \
  dmenu \
  xorg \
  xserver-xorg-core \
  xserver-xorg-input-all \
  xserver-xorg-video-all \
  || {
    err "Ошибка установки i3wm"
    exit 1
  }

# Дополнительные утилиты для standard профиля
if [[ "$PROFILE" == "standard" ]]; then
  log "Шаг 2/3: Установка дополнительных утилит (standard профиль)..."

  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    feh \
    picom \
    lxappearance \
    pavucontrol \
    network-manager-gnome \
    xfce4-power-manager \
    lxqt-policykit \
    fonts-font-awesome \
    || {
      err "Ошибка установки дополнительных утилит"
      exit 1
    }
else
  log "Шаг 2/3: Пропуск дополнительных утилит (minimal профиль)"
fi

# ============================================================================
# Шаг 3: Настройка конфигурационных файлов
# ============================================================================

log "Шаг 3/3: Создание конфигурационных файлов..."

# Создаём шаблон конфига i3
I3_CONFIG_DIR="/etc/skel/.config/i3"
mkdir -p "$I3_CONFIG_DIR"

cat > "$I3_CONFIG_DIR/config" << 'I3EOF'
# i3wm config для VibeCode OS
# Версия: 1.0

# Mod key: Mod4 (Super/Windows key)
set $mod Mod4

# Шрифт
font pango:JetBrains Mono 10

# Запуск терминала
bindsym $mod+Return exec xfce4-terminal
bindsym $mod+d exec dmenu_run

# Запуск файлового менеджера
bindsym $mod+e exec thunar

# Перезапуск i3
bindsym $mod+Shift+r restart

# Блокировка экрана
bindsym $mod+Shift+l exec i3lock -c 000000

# Запуск dmenu для приложений
bindsym $mod+r mode "resize"

# Закрытие окна
bindsym $mod+q kill

# Разделение окон
bindsym $mod+h split h
bindsym $mod+v split v

# Полноэкранный режим
bindsym $mod+f fullscreen toggle

# Переключение фокуса
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# Перемещение окон
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# Рабочие столы
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+4 workspace 4
bindsym $mod+5 workspace 5
bindsym $mod+6 workspace 6
bindsym $mod+7 workspace 7
bindsym $mod+8 workspace 8
bindsym $mod+9 workspace 9
bindsym $mod+0 workspace 10

# Перемещение окна на рабочий стол
bindsym $mod+Shift+1 move container to workspace 1
bindsym $mod+Shift+2 move container to workspace 2
bindsym $mod+Shift+3 move container to workspace 3
bindsym $mod+Shift+4 move container to workspace 4
bindsym $mod+Shift+5 move container to workspace 5
bindsym $mod+Shift+6 move container to workspace 6
bindsym $mod+Shift+7 move container to workspace 7
bindsym $mod+Shift+8 move container to workspace 8
bindsym $mod+Shift+9 move container to workspace 9
bindsym $mod+Shift+0 move container to workspace 10

# Режим resize
mode "resize" {
    bindsym j resize shrink width 10 px or 10 ppt
    bindsym k resize grow height 10 px or 10 ppt
    bindsym l resize shrink height 10 px or 10 ppt
    bindsym semicolon resize grow width 10 px or 10 ppt

    bindsym Left resize shrink width 10 px or 10 ppt
    bindsym Down resize grow height 10 px or 10 ppt
    bindsym Up resize shrink height 10 px or 10 ppt
    bindsym Right resize grow width 10 px or 10 ppt

    bindsym Return mode "default"
    bindsym Escape mode "default"
}

# Автозапуск приложений
exec --no-startup-id xfce4-power-manager
exec --no-startup-id nm-applet
exec --no-startup-id picom -b
exec --no-startup-id feh --bg-fill /usr/share/backgrounds/vibecode/default.jpg
exec --no-startup-id i3status

# Цветовая схема
client.focused          #4c7899 #4c7899 #ffffff #4c7899   #4c7899
client.focused_inactive #333333 #5f676a #ffffff #484e50   #5f676a
client.unfocused        #333333 #222222 #888888 #292d2e   #222222
client.urgent           #2f343a #900000 #ffffff #900000   #900000
client.placeholder      #000000 #0c0c0c #ffffff #000000   #0c0c0c
I3EOF

log "Конфиг i3wm создан в $I3_CONFIG_DIR/config"

# Создание .xinitrc для запуска через startx
cat > "/etc/skel/.xinitrc" << 'XEOF'
#!/bin/bash
exec i3
XEOF

chmod +x "/etc/skel/.xinitrc"

# ============================================================================
# Очистка
# ============================================================================

log "Очистка кэша пакетов..."
apt-get clean
rm -rf /var/lib/apt/lists/*

log "✅ i3wm успешно установлен!"
log ""
log "📋 Что установлено:"
log "  • i3wm — тайловый оконный менеджер"
log "  • dmenu — лаунчер приложений"
log "  • i3lock — блокировка экрана"
log "  • i3status — статусная строка"
log "  • picom — композитор (прозрачность, тени)"
log "  • feh — установка обоев"
log ""
log "🚀 Как использовать:"
log "  1. Выберите i3 при входе в систему (display manager)"
log "  2. Или запустите: startx (из консоли)"
log "  3. Mod4 (Win) + Enter — открыть терминал"
log "  4. Mod4 + d — запустить dmenu"
log "  5. Mod4 + h/v — горизонтальное/вертикальное разделение"
log ""
log "📖 Документация: https://i3wm.org/docs/userguide.html"
