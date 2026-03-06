#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки расширений VSCodium для VibeCode OS

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

EXTENSIONS_FILE="${ROOT_DIR}/scripts/dev/configs/vscodium-extensions.txt"

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
    sudo -u "$USER_NAME" bash -lc "codium --install-extension '$extension_id' 2>/dev/null || true"
  fi
done < "$EXTENSIONS_FILE"

echo "[install-vscodium-extensions] Готово."
