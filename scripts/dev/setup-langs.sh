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
    
    # Добавляем в shell конфиг если ещё не добавлено
    if [ -f "$HOME/.zshrc" ] && ! grep -q "pyenv init" "$HOME/.zshrc"; then
      echo "" >> "$HOME/.zshrc"
      echo "# pyenv" >> "$HOME/.zshrc"
      echo "export PYENV_ROOT=\"\$HOME/.pyenv\"" >> "$HOME/.zshrc"
      echo "[[ -d \$PYENV_ROOT/bin ]] && export PATH=\"\$PYENV_ROOT/bin:\$PATH\"" >> "$HOME/.zshrc"
      echo "eval \"\$(pyenv init -)\"" >> "$HOME/.zshrc"
    fi
    
    if [ -f "$HOME/.bashrc" ] && ! grep -q "pyenv init" "$HOME/.bashrc"; then
      echo "" >> "$HOME/.bashrc"
      echo "# pyenv" >> "$HOME/.bashrc"
      echo "export PYENV_ROOT=\"\$HOME/.pyenv\"" >> "$HOME/.bashrc"
      echo "[[ -d \$PYENV_ROOT/bin ]] && export PATH=\"\$PYENV_ROOT/bin:\$PATH\"" >> "$HOME/.bashrc"
      echo "eval \"\$(pyenv init -)\"" >> "$HOME/.bashrc"
    fi
  fi
'

echo "[setup-langs] Установка Python версий через pyenv..."
sudo -u "$USER_NAME" bash -lc '
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  
  # Устанавливаем популярные версии
  pyenv install -s 3.11.11 || true
  pyenv install -s 3.12.8 || true
  pyenv global 3.12.8 || true
'

echo "[setup-langs] Установка nvm для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" bash -lc '
  if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
  fi
'

echo "[setup-langs] Установка Node.js версий через nvm..."
sudo -u "$USER_NAME" bash -lc '
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  
  # Устанавливаем LTS и latest
  nvm install --lts || true
  nvm install node || true
  nvm alias default lts/* || true
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

echo "[setup-langs] Установка Java через SDKMAN!..."
sudo -u "$USER_NAME" bash -lc '
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
  
  # Устанавливаем последний LTS Java
  sdk install java 21.0.5-tem || true
  sdk default java 21.0.5-tem || true
'

echo "[setup-langs] Установка Go..."
DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go || true

echo "[setup-langs] Готово."

