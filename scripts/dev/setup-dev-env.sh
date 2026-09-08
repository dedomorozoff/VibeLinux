#!/usr/bin/env bash
set -euo pipefail

# Агрегирующий скрипт для настройки dev-среды VibeCode OS.
# Вызывает базовые скрипты из scripts/dev и scripts/base.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (он устанавливает системные пакеты)."
  exit 1
fi

echo "[setup-dev-env] Установка базовых системных пакетов..."
if command -v pacman >/dev/null 2>&1; then
  # Arch Linux: базовый CLI-набор ставится напрямую через pacman
  pacman -Sy --noconfirm --needed \
    base-devel git curl wget unzip zstd p7zip jq rsync tmux btop fastfetch \
    zsh starship eza bat fd zoxide fzf ripgrep lazygit kitty \
    python python-pip nodejs npm docker docker-compose
elif command -v apt-get >/dev/null 2>&1; then
  # Legacy (Ubuntu): базовый набор из legacy-скриптов
  bash "${ROOT_DIR}/scripts/legacy/base/base-packages.sh"
else
  echo "[setup-dev-env] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

echo "[setup-dev-env] Настройка оболочки..."
bash "${ROOT_DIR}/scripts/dev/setup-shell.sh"

echo "[setup-dev-env] Настройка терминала..."
bash "${ROOT_DIR}/scripts/dev/setup-terminal.sh"

echo "[setup-dev-env] Установка языковых стеков..."
bash "${ROOT_DIR}/scripts/dev/setup-langs.sh"

echo "[setup-dev-env] Установка dev-инструментов (Git, Docker, lazygit)..."
bash "${ROOT_DIR}/scripts/dev/setup-devtools.sh"

echo "[setup-dev-env] Установка редактора (Zed)..."
bash "${ROOT_DIR}/scripts/dev/setup-editors.sh"

echo "[setup-dev-env] Dev-среда настроена."

