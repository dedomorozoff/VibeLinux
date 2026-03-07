#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки панели MATE для VibeCode OS
# Исправляет проблему с отсутствующими часами и настраивает базовый layout панели

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

TARGET_USER="${1:-vibecode}"

echo "[mate-panel] Настройка панели MATE для пользователя ${TARGET_USER}..."

# Создаём директории для настроек
mkdir -p "/home/${TARGET_USER}/.config/dconf"
mkdir -p "/home/${TARGET_USER}/.config/autostart"

# Создаём скрипт автонастройки панели при первом входе
cat > "/home/${TARGET_USER}/.config/autostart/mate-panel-setup.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=MATE Panel Setup
Exec=/usr/local/bin/mate-panel-first-run.sh
Hidden=false
NoDisplay=true
X-MATE-Autostart-enabled=true
EOF

# Создаём скрипт первого запуска
cat > "/usr/local/bin/mate-panel-first-run.sh" << 'SETUPEOF'
#!/usr/bin/env bash
# Скрипт выполняется при первом входе пользователя

# Проверяем, что это первый запуск
MARKER="$HOME/.config/mate-panel-configured"
if [[ -f "$MARKER" ]]; then
  exit 0
fi

# Ждём, пока панель полностью загрузится
sleep 5

# Сбрасываем настройки панели к дефолтным
dconf reset -f /org/mate/panel/ 2>/dev/null || true

# Создаём объекты панели заново
dconf write /org/mate/panel/objects/toplevels/bottom/orientation "'bottom'" 2>/dev/null || true
dconf write /org/mate/panel/objects/toplevels/bottom/size 24 2>/dev/null || true
dconf write /org/mate/panel/objects/toplevels/bottom/expand true 2>/dev/null || true
dconf write /org/mate/panel/objects/toplevels/bottom/auto-hide false 2>/dev/null || true

# Добавляем апплет меню (MATE Menu)
dconf write /org/mate/panel/objects/object-0/toplevel "'bottom'" 2>/dev/null || true
dconf write /org/mate/panel/objects/object-0/position 0 2>/dev/null || true
dconf write /org/mate/panel/objects/object-0/panel-right true 2>/dev/null || true
dconf write /org/mate/panel/objects/object-0/applet-iid "'MateMenuFactory::MateMenu'" 2>/dev/null || true

# Добавляем апплет часов
dconf write /org/mate/panel/objects/object-1/toplevel "'bottom'" 2>/dev/null || true
dconf write /org/mate/panel/objects/object-1/position 1000 2>/dev/null || true
dconf write /org/mate/panel/objects/object-1/applet-iid "'ClockAppletFactory::ClockApplet'" 2>/dev/null || true

# Настраиваем часы на панели
dconf write /org/mate/panel/objects/object-1/prefs/format "'24-hour'" 2>/dev/null || true
dconf write /org/mate/panel/objects/object-1/prefs/show-date true 2>/dev/null || true
dconf write /org/mate/panel/objects/object-1/prefs/show-seconds false 2>/dev/null || true
dconf write /org/mate/panel/objects/object-1/prefs/show-weather false 2>/dev/null || true

# Перезапускаем панель
pkill mate-panel || true
sleep 1
mate-panel --replace &

# Отмечаем, что настройка выполнена
touch "$MARKER"

# Удаляем автозапуск этого скрипта
rm -f "$HOME/.config/autostart/mate-panel-setup.desktop" 2>/dev/null || true
SETUPEOF

chmod +x "/usr/local/bin/mate-panel-first-run.sh"

# Устанавливаем права
chown -R "${TARGET_USER}:${TARGET_USER}" "/home/${TARGET_USER}/.config"

echo "[mate-panel] Настройка завершена. Часы появятся после первого входа пользователя."
