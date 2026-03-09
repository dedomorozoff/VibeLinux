#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки редакторов: VSCodium, Neovim, Zed для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[setup-editors] Установка VSCodium..."
# Добавляем репозиторий VSCodium
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
  | gpg --dearmor \
  | dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg

echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
  | tee /etc/apt/sources.list.d/vscodium.list

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y codium

echo "[setup-editors] Установка Neovim..."
DEBIAN_FRONTEND=noninteractive apt-get install -y neovim

echo "[setup-editors] Установка AstroNvim для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" bash -lc '
  if [ ! -d "$HOME/.config/nvim" ]; then
    git clone --depth 1 https://github.com/AstroNvim/template "$HOME/.config/nvim"
    rm -rf "$HOME/.config/nvim/.git"
  fi
'

echo "[setup-editors] Установка Zed..."
# Zed пока устанавливаем через curl (официальный способ)
sudo -u "$USER_NAME" bash -lc '
  if ! command -v zed >/dev/null 2>&1; then
    curl -f https://zed.dev/install.sh | sh
  fi
'

echo "[setup-editors] Настройка VSCodium..."
bash "${ROOT_DIR}/scripts/dev/setup-vscodium.sh"

echo "[setup-editors] Готово."
