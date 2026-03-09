#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки dev-среды внутри chroot для VibeCode OS

echo "[install-dev-stack] Установка базовых утилит..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \
  git \
  wget \
  unzip \
  tree \
  ca-certificates \
  gnupg \
  lsb-release

echo "[install-dev-stack] Установка Kitty..."
DEBIAN_FRONTEND=noninteractive apt-get install -y kitty

echo "[install-dev-stack] Настройка Kitty..."
mkdir -p /root/.config/kitty
cp /root/dev-configs/kitty.conf /root/.config/kitty/

echo "[install-dev-stack] Установка Python, Node.js, Rust, Go, Java..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 \
  python3-pip \
  python3-venv \
  nodejs \
  npm \
  rustc \
  cargo \
  golang-go \
  sdkman || true

echo "[install-dev-stack] Установка Git, lazygit, Docker..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  lazygit \
  docker.io \
  docker-compose-plugin || true

echo "[install-dev-stack] Установка VSCodium..."
DEBIAN_FRONTEND=noninteractive apt-get install -y codium || true

echo "[install-dev-stack] Установка Neovim..."
DEBIAN_FRONTEND=noninteractive apt-get install -y neovim || true

echo "[install-dev-stack] Настройка AstroNvim..."
if [ ! -d "/root/.config/nvim" ]; then
  git clone --depth 1 https://github.com/AstroNvim/template /root/.config/nvim
  rm -rf /root/.config/nvim/.git
fi

echo "[install-dev-stack] Установка Zed..."
if ! command -v zed >/dev/null 2>&1; then
  curl -f https://zed.dev/install.sh | sh || true
fi

echo "[install-dev-stack] Настройка VSCodium..."
mkdir -p /root/.config/codium/User
cp /root/dev-configs/vscodium-settings.json /root/.config/codium/User/settings.json

echo "[install-dev-stack] Установка расширений VSCodium..."
if [ -f "/root/dev-configs/vscodium-extensions.txt" ]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    extension_id=$(echo "$line" | awk '{print $1}')
    if [[ -n "$extension_id" ]]; then
      codium --install-extension "$extension_id" 2>/dev/null || true
    fi
  done < /root/dev-configs/vscodium-extensions.txt
fi

echo "[install-dev-stack] Готово."
