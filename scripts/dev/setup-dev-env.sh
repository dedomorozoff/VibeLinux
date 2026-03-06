#!/usr/bin/env bash
set -euo pipefail

# Агрегирующий скрипт для настройки dev-среды VibeCode OS.
# Вызывает базовые скрипты из scripts/dev и scripts/base.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (он вызывает apt и системные изменения)."
  exit 1
fi

echo "[setup-dev-env] Запуск базовой установки пакетов..."
bash "${ROOT_DIR}/scripts/base/base-packages.sh"

echo "[setup-dev-env] Настройка оболочки..."
bash "${ROOT_DIR}/scripts/dev/setup-shell.sh"

echo "[setup-dev-env] Настройка терминала..."
bash "${ROOT_DIR}/scripts/dev/setup-terminal.sh"

echo "[setup-dev-env] Установка языковых стеков..."
bash "${ROOT_DIR}/scripts/dev/setup-langs.sh"

echo "[setup-dev-env] Установка dev-инструментов (Git, Docker, lazygit)..."
bash "${ROOT_DIR}/scripts/dev/setup-devtools.sh"

echo "[setup-dev-env] Установка редакторов (VSCodium, Neovim, Zed)..."
bash "${ROOT_DIR}/scripts/dev/setup-editors.sh"

echo "[setup-dev-env] Проверка установки..."
bash "${ROOT_DIR}/scripts/dev/utils/check-install.sh"

echo "[setup-dev-env] Валидация среды..."
bash "${ROOT_DIR}/scripts/dev/utils/validate-env.sh"

echo "[setup-dev-env] Dev-среда настроена."

