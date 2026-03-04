#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки менеджеров версий и базовых языковых стеков.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для системных пакетов)."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "[setup-langs] Установка зависимостей..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential \
  curl \
  git \
  ca-certificates \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  wget \
  llvm \
  libncursesw5-dev \
  xz-utils \
  tk-dev \
  libxml2-dev \
  libxmlsec1-dev \
  libffi-dev \
  liblzma-dev

echo "[setup-langs] Установка pyenv для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" bash -lc '
  if [ ! -d "$HOME/.pyenv" ]; then
    curl https://pyenv.run | bash
  fi
'

echo "[setup-langs] Установка nvm для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" bash -lc '
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  fi
'

echo "[setup-langs] Установка rustup для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" bash -lc '
  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
'

echo "[setup-langs] Установка SDKMAN! для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" bash -lc '
  if [ ! -d "$HOME/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
  fi
'

echo "[setup-langs] Готово. Конкретные версии языков будут добавлены позже."

