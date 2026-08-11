#!/usr/bin/env bash
# Скрипт проверки содержимого собранного образа

set -euo pipefail

CHROOT_DIR="${1:-build/chroot}"

echo "=== Проверка содержимого образа ==="
echo ""

if [[ ! -d "$CHROOT_DIR" ]]; then
  echo "❌ Директория $CHROOT_DIR не найдена"
  exit 1
fi

echo "✓ Chroot найден: $CHROOT_DIR"
echo ""

# Проверка информации о дистрибутиве
echo "--- Информация о дистрибутиве ---"
if [[ -f "$CHROOT_DIR/etc/lsb-release" ]]; then
  echo "✓ /etc/lsb-release:"
  cat "$CHROOT_DIR/etc/lsb-release" | sed 's/^/  /'
else
  echo "❌ /etc/lsb-release не найден"
fi
echo ""

# Проверка установщика
echo "--- Установщик ---"
if command -v chroot >/dev/null 2>&1; then
  if chroot "$CHROOT_DIR" dpkg -l ubiquity 2>/dev/null | grep -q "^ii"; then
    echo "✓ Ubiquity установлен"
  else
    echo "❌ Ubiquity не установлен"
  fi
fi

if [[ -f "$CHROOT_DIR/home/vibecode/Desktop/ubiquity.desktop" ]]; then
  echo "✓ Ярлык установщика на рабочем столе"
else
  echo "❌ Ярлык установщика не найден"
fi
echo ""

# Проверка брендинга
echo "--- Брендинг ---"
if [[ -d "$CHROOT_DIR/usr/share/pixmaps/vibecodeos" ]]; then
  echo "✓ Логотипы скопированы:"
  ls -1 "$CHROOT_DIR/usr/share/pixmaps/vibecodeos/" | sed 's/^/  - /'
else
  echo "❌ Логотипы не найдены"
fi

if [[ -d "$CHROOT_DIR/usr/share/backgrounds" ]]; then
  echo "✓ Обои скопированы:"
  ls -1 "$CHROOT_DIR/usr/share/backgrounds/" | grep -i vibe | sed 's/^/  - /' || echo "  ❌ Обои VibeCode не найдены"
else
  echo "❌ Директория обоев не найдена"
fi

if command -v chroot >/dev/null 2>&1; then
  if chroot "$CHROOT_DIR" dpkg -l arc-theme 2>/dev/null | grep -q "^ii"; then
    echo "✓ Arc-Dark тема установлена"
  else
    echo "❌ Arc-Dark тема не установлена"
  fi
  
  if chroot "$CHROOT_DIR" dpkg -l papirus-icon-theme 2>/dev/null | grep -q "^ii"; then
    echo "✓ Papirus иконки установлены"
  else
    echo "❌ Papirus иконки не установлены"
  fi
  
  if chroot "$CHROOT_DIR" dpkg -l fonts-jetbrains-mono 2>/dev/null | grep -q "^ii"; then
    echo "✓ JetBrains Mono шрифт установлен"
  else
    echo "❌ JetBrains Mono шрифт не установлен"
  fi
fi
echo ""

# Проверка утилит
echo "--- Дополнительные утилиты ---"
UTILS=("firefox" "neofetch" "vim" "network-manager")
for util in "${UTILS[@]}"; do
  if command -v chroot >/dev/null 2>&1; then
    if chroot "$CHROOT_DIR" dpkg -l "$util" 2>/dev/null | grep -q "^ii"; then
      echo "✓ $util установлен"
    else
      echo "❌ $util не установлен"
    fi
  fi
done
echo ""

# Проверка пользователя
echo "--- Пользователь ---"
if [[ -d "$CHROOT_DIR/home/vibecode" ]]; then
  echo "✓ Пользователь vibecode создан"
  echo "  Содержимое /home/vibecode:"
  ls -la "$CHROOT_DIR/home/vibecode/" | tail -n +4 | sed 's/^/    /'
else
  echo "❌ Пользователь vibecode не создан"
fi
echo ""

# Проверка автозапуска
echo "--- Автозапуск ---"
if [[ -d "$CHROOT_DIR/home/vibecode/.config/autostart" ]]; then
  echo "✓ Директория autostart существует:"
  ls -1 "$CHROOT_DIR/home/vibecode/.config/autostart/" 2>/dev/null | sed 's/^/  - /' || echo "  (пусто)"
else
  echo "❌ Директория autostart не найдена"
fi
echo ""

echo "=== Проверка завершена ==="
