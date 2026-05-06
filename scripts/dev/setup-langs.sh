#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки менеджеров версий и базовых языковых стеков.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для системных пакетов)."
  exit 1
fi

USER_NAME="${1:-root}"
USER_HOME=""
if command -v getent >/dev/null 2>&1; then
  USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
fi
if [[ -z "${USER_HOME}" ]]; then
  if [[ "${USER_NAME}" == "root" ]]; then
    USER_HOME="/root"
  else
    USER_HOME="/home/${USER_NAME}"
  fi
fi

echo "[setup-langs] Установка зависимостей..."
apt-get update -y || true
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
  liblzma-dev \
  || true

# Проверка доступности интернета
check_network() {
  curl -sf --connect-timeout 5 https://github.com >/dev/null 2>&1
}

echo "[setup-langs] Установка pyenv для пользователя ${USER_NAME}..."
if check_network; then
  if [ ! -d "$USER_HOME/.pyenv" ]; then
    su - "$USER_NAME" -c 'curl -fsSL https://pyenv.run | bash' 2>/dev/null || true
    if [ -f "$USER_HOME/.zshrc" ] && ! grep -q "pyenv init" "$USER_HOME/.zshrc"; then
      printf '\n# pyenv\nexport PYENV_ROOT="$HOME/.pyenv"\n[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"\neval "$(pyenv init -)"\n' >> "$USER_HOME/.zshrc"
    fi
  fi

  echo "[setup-langs] Установка Python версий через pyenv..."
  su - "$USER_NAME" -c '
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)" 2>/dev/null || true
    pyenv install -s 3.11.11 2>/dev/null || true
    pyenv install -s 3.12.8 2>/dev/null || true
    pyenv global 3.12.8 2>/dev/null || true
  ' || true
else
  echo "[setup-langs] Пропуск pyenv - нет сети"
fi

echo "[setup-langs] Установка nvm для пользователя ${USER_NAME}..."
if check_network; then
  if [ ! -d "$USER_HOME/.nvm" ]; then
    su - "$USER_NAME" -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash' 2>/dev/null || true
  fi

  echo "[setup-langs] Установка Node.js версий через nvm..."
  su - "$USER_NAME" -c '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true
    nvm install --lts 2>/dev/null || true
    nvm install node 2>/dev/null || true
  ' || true
else
  echo "[setup-langs] Пропуск nvm - нет сети"
fi

echo "[setup-langs] Установка rustup для пользователя ${USER_NAME}..."
if check_network; then
  if [ ! -d "$USER_HOME/.cargo" ]; then
    su - "$USER_NAME" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' 2>/dev/null || true
  fi
else
  echo "[setup-langs] Пропуск rustup - нет сети"
fi

echo "[setup-langs] Установка SDKMAN! для пользователя ${USER_NAME}..."
if check_network; then
  if [ ! -d "$USER_HOME/.sdkman" ]; then
    su - "$USER_NAME" -c 'curl -s "https://get.sdkman.io" | bash' 2>/dev/null || true
  fi
else
  echo "[setup-langs] Пропуск SDKMAN! - нет сети"
fi

# Go (установка свежей версии)
echo "[setup-langs] Установка Go..."
if check_network; then
  if ! command -v go >/dev/null 2>&1 || [[ "$(go version 2>/dev/null)" != *"go1.2"* ]]; then
    su - "$USER_NAME" -c '
      set -e
      go_version="1.26.1"
      wget -q "https://go.dev/dl/go${go_version}.linux-amd64.tar.gz" -O /tmp/go.tar.gz 2>/dev/null || true
      if [ -f /tmp/go.tar.gz ]; then
        rm -rf "$HOME/go"
        tar -C "$HOME" -xzf /tmp/go.tar.gz 2>/dev/null || true
        rm /tmp/go.tar.gz
      fi
    ' || true
  fi
else
  apt-get install -y golang-go 2>/dev/null || true
fi

# Добавляем Go в PATH пользователя
if [ -f "$USER_HOME/.zshrc" ] && ! grep -q 'export GOPATH' "$USER_HOME/.zshrc"; then
  printf '\n# Go\nexport GOPATH="$HOME/go"\nexport PATH="$HOME/go/bin:$PATH"\n' >> "$USER_HOME/.zshrc"
fi

# PHP
echo "[setup-langs] Установка PHP..."
apt-get install -y \
  php \
  php-cli \
  php-common \
  php-curl \
  php-mbstring \
  php-xml \
  php-zip \
  php-sqlite3 \
  php-mysql \
  php-pgsql \
  php-json \
  php-intl \
  php-bcmath \
  2>/dev/null || echo "[setup-langs] WARNING: PHP install failed"

# Composer (менеджер зависимостей PHP)
if check_network; then
  if ! command -v composer >/dev/null 2>&1; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 2>/dev/null || echo "[setup-langs] WARNING: Composer install failed"
  fi
fi

echo "[setup-langs] Готово."
