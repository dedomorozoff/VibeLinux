#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки расширений VSCodium для VibeCode OS

USER_NAME="${SUDO_USER:-$USER}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTENSIONS_FILE="${VSCODIUM_EXTENSIONS_FILE:-${DEV_DIR}/configs/vscodium-extensions.txt}"

if [[ ! -f "$EXTENSIONS_FILE" ]]; then
  echo "[install-vscodium-extensions] ERROR: Файл расширений не найден: $EXTENSIONS_FILE"
  exit 1
fi

echo "[install-vscodium-extensions] Установка расширений VSCodium..."

# Считываем расширения из файла (игнорируем комментарии и пустые строки)
while IFS= read -r line || [[ -n "$line" ]]; do
  # Пропускаем комментарии и пустые строки
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  
  # Извлекаем ID расширения (до пробела или таба)
  extension_id=$(echo "$line" | awk '{print $1}')
  
  if [[ -n "$extension_id" ]]; then
    echo "[install-vscodium-extensions] Установка: $extension_id"
    su - "$USER_NAME" -c "codium --install-extension '$extension_id'" 2>/dev/null || true
  fi
done < "$EXTENSIONS_FILE"

echo "[install-vscodium-extensions] Готово."
