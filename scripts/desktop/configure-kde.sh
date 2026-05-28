#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки KDE Plasma для VibeCode OS
# Настраивает панель задач, часы и базовый layout

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

TARGET_USER="${1:-vibecode}"

echo "[kde] Настройка KDE Plasma для пользователя ${TARGET_USER}..."

# Создаём директории для настроек
mkdir -p "/home/${TARGET_USER}/.config"
mkdir -p "/home/${TARGET_USER}/.config/autostart"

# Создаём скрипт автонастройки KDE при первом входе
cat > "/home/${TARGET_USER}/.config/autostart/kde-setup.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=KDE Plasma Setup
Exec=/usr/local/bin/kde-first-run.sh
Hidden=false
NoDisplay=true
X-KDE-autostart-condition=true
EOF

# Создаём скрипт первого запуска
cat > "/usr/local/bin/kde-first-run.sh" << 'SETUPEOF'
#!/usr/bin/env bash
# Скрипт выполняется при первом входе пользователя

MARKER="$HOME/.config/kde-configured"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

sleep 5

# Настраиваем панель задач через kwriteconfig5
kwriteconfig5 --file plasmarc --group Panels --group Values --key Height 48 2>/dev/null || true
kwriteconfig5 --file plasmarc --group Panels --group Values --key Length 100 2>/dev/null || true
kwriteconfig5 --file plasmarc --group Panels --group Values --key Floating true 2>/dev/null || true

# Настраиваем часы
kwriteconfig5 --file plasmashellrc --group General --key showDate 1 2>/dev/null || true
kwriteconfig5 --file plasmashellrc --group General --key showSeconds 0 2>/dev/null || true

# Перезапускаем Plasma
killall plasmashell 2>/dev/null || true
sleep 1
kstart5 plasmashell 2>/dev/null || true

touch "$MARKER"

rm -f "$HOME/.config/autostart/kde-setup.desktop" 2>/dev/null || true
SETUPEOF

chmod +x "/usr/local/bin/kde-first-run.sh"

# Устанавливаем права
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config"

echo "[kde] Настройка завершена. Панель появится после первого входа пользователя."
