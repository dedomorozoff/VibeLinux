#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки оболочки Zsh + Oh My Zsh + Starship для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для установки пакетов)."
  exit 1
fi

USER_NAME="${1:-root}"
USER_HOME="/home/${USER_NAME}"
BRANDING_DIR="/root/branding"

echo "[setup-shell] Установка Zsh..."
apt-get update -y || true
DEBIAN_FRONTEND=noninteractive apt-get install -y zsh curl git wget || true

# Установка Oh My Zsh (без интерактивного режима)
echo "[setup-shell] Установка Oh My Zsh для пользователя ${USER_NAME}..."
if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
  su - "$USER_NAME" -c '
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 2>/dev/null || true
  ' || echo "[setup-shell] Oh My Zsh установка пропущена (может потребоваться сеть)"
else
  echo "[setup-shell] Oh My Zsh уже установлен"
fi

# Установка Starship
echo "[setup-shell] Установка Starship..."
if command -v starship >/dev/null 2>&1; then
  echo "[setup-shell] Starship уже установлен"
else
  curl -fsSL https://starship.rs/install.sh 2>/dev/null | bash -s -- -y 2>/dev/null || true
  # Fallback: установить через apt
  if ! command -v starship >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y starship 2>/dev/null || true
  fi
fi

# Копирование конфигов
echo "[setup-shell] Копирование конфигов..."
mkdir -p "${USER_HOME}/.config"

# Zshrc
if [[ -f "${BRANDING_DIR}/config/zsh/zshrc" ]]; then
  cp "${BRANDING_DIR}/config/zsh/zshrc" "${USER_HOME}/.zshrc"
  echo "[setup-shell] Zshrc скопирован из branding"
elif [[ -f "/root/zshrc" ]]; then
  cp "/root/zshrc" "${USER_HOME}/.zshrc"
else
  echo "[setup-shell] ВНИМАНИЕ: zshrc не найден, используется стандартный Oh My Zsh"
fi
chown "$USER_NAME:$USER_NAME" "${USER_HOME}/.zshrc" 2>/dev/null || true

# Starship
if [[ -f "${BRANDING_DIR}/config/starship/starship.toml" ]]; then
  cp "${BRANDING_DIR}/config/starship/starship.toml" "${USER_HOME}/.config/starship.toml"
  echo "[setup-shell] Starship config скопирован из branding"
elif [[ -f "/root/starship.toml" ]]; then
  cp "/root/starship.toml" "${USER_HOME}/.config/starship.toml"
fi
chown -R "$USER_NAME:$USER_NAME" "${USER_HOME}/.config" 2>/dev/null || true

# Добавление Starship в .zshrc если его там нет
ZSHRC="${USER_HOME}/.zshrc"
if [[ -f "$ZSHRC" ]] && ! grep -q 'starship init' "$ZSHRC" 2>/dev/null; then
  echo '[setup-shell] Добавление Starship в .zshrc...'
  printf '\n# Starship prompt\nif command -v starship >/dev/null 2>&1; then\n  eval "$(starship init zsh)"\nfi\n' >> "$ZSHRC"
fi

# Установка zsh по умолчанию
chsh -s "$(command -v zsh)" "$USER_NAME" 2>/dev/null || true

echo "[setup-shell] Готово."

