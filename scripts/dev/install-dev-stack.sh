#!/usr/bin/env bash
set -euo pipefail

# ⚠️ DEPRECATED: Этот скрипт устарел и не используется.
# Вместо него используйте отдельные скрипты:
#   - setup-terminal.sh — Kitty
#   - setup-shell.sh — Zsh + Oh My Zsh + Starship
#   - setup-langs.sh — Python, Node.js, Rust, Go, Java
#   - setup-editors.sh — VSCodium, Neovim, Zed
#   - setup-devtools.sh — Git, Docker, lazygit
#
# Скрипт будет удалён в версии v1.0.0

echo "[install-dev-stack] ⚠️ WARNING: Скрипт устарел (deprecated)"
echo "[install-dev-stack] Используйте setup-dev-env.sh для полной установки"

# Проверка доступности интернета
check_network() {
  curl -sf --connect-timeout 5 https://github.com >/dev/null 2>&1
}

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

echo "[install-dev-stack] Установка Python, Node.js, Rust, Go..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 \
  python3-pip \
  python3-venv \
  nodejs \
  npm \
  rustc \
  cargo \
  golang-go || true

# ⚠️ sdkman не устанавливается через apt - только через curl-скрипт
echo "[install-dev-stack] ⚠️ SDKMAN! требует ручной установки через curl"

echo "[install-dev-stack] Установка Git, lazygit, Docker..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  lazygit \
  docker.io \
  docker-compose-plugin || true

echo "[install-dev-stack] Установка VSCodium..."
if check_network; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y codium 2>/dev/null || true
else
  echo "[install-dev-stack] Пропуск VSCodium - нет сети"
fi

echo "[install-dev-stack] Установка Neovim..."
DEBIAN_FRONTEND=noninteractive apt-get install -y neovim || true

echo "[install-dev-stack] ⚠️ AstroNvim и Zed требуют setup-editors.sh"

echo "[install-dev-stack] Готово (базовая установка)."
echo "[install-dev-stack] Для полной настройки запустите setup-dev-env.sh"
