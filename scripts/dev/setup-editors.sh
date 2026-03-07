#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки редакторов: VSCodium, Neovim, Zed для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${1:-root}"
USER_HOME="/home/${USER_NAME}"

# Проверка доступности интернета
check_network() {
  curl -sf --connect-timeout 5 https://github.com >/dev/null 2>&1
}

echo "[setup-editors] Установка VSCodium..."
if check_network; then
  wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg 2>/dev/null \
    | gpg --dearmor 2>/dev/null \
    | dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null || true

  echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
    | tee /etc/apt/sources.list.d/vscodium.list >/dev/null || true

  apt-get update -y || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y codium 2>/dev/null || true
else
  echo "[setup-editors] Пропуск VSCodium - нет сети"
fi

echo "[setup-editors] Установка Neovim..."
DEBIAN_FRONTEND=noninteractive apt-get install -y neovim 2>/dev/null || true

echo "[setup-editors] Установка AstroNvim для пользователя ${USER_NAME}..."
if check_network; then
  if [ ! -d "$USER_HOME/.config/nvim" ]; then
    su - "$USER_NAME" -c 'git clone --depth 1 https://github.com/AstroNvim/template "$HOME/.config/nvim" 2>/dev/null && rm -rf "$HOME/.config/nvim/.git"' 2>/dev/null || true
  fi
else
  echo "[setup-editors] Пропуск AstroNvim - нет сети"
fi

echo "[setup-editors] Установка Zed..."
if check_network; then
  if ! command -v zed >/dev/null 2>&1; then
    su - "$USER_NAME" -c 'curl -f https://zed.dev/install.sh 2>/dev/null | sh' 2>/dev/null || true
  fi
else
  echo "[setup-editors] Пропуск Zed - нет сети"
fi

echo "[setup-editors] Готово."
