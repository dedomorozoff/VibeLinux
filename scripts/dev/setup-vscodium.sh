#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки VSCodium после установки

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "[setup-vscodium] Настройка VSCodium..."

# Создаем директорию settings.json
mkdir -p "${USER_HOME}/.config/codium/User"

# Копируем настройки
if [ -f "${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json" ]; then
  cp "${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json" "${USER_HOME}/.config/codium/User/settings.json"
  echo "[setup-vscodium] settings.json настроен"
else
  echo "[setup-vscodium] ERROR: Файл настроек не найден"
  exit 1
fi

# Копируем расширения из списка
bash "${ROOT_DIR}/scripts/dev/utils/install-vscodium-extensions.sh" || echo "[setup-vscodium] Warning: Extension installation failed"

echo "[setup-vscodium] Готово."

