#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки оболочки Zsh + Oh My Zsh + Starship для VibeCode OS.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root (для установки пакетов)."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[setup-shell] Установка Zsh..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y zsh curl git

echo "[setup-shell] Установка Oh My Zsh для пользователя ${USER_NAME}..."
sudo -u "$USER_NAME" sh -c '
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
'

echo "[setup-shell] Установка Starship..."
curl -fsSL https://starship.rs/install.sh | bash -s -- -y

echo "[setup-shell] Копирование конфигов..."
# Копируем шаблон .zshrc
if [[ -f "${ROOT_DIR}/scripts/dev/configs/zshrc.template" ]]; then
  cp "${ROOT_DIR}/scripts/dev/configs/zshrc.template" "${USER_HOME}/.zshrc"
  chown "$USER_NAME:$USER_NAME" "${USER_HOME}/.zshrc"
  echo "[setup-shell] .zshrc скопирован"
fi

# Копируем конфиг Starship
if [[ -f "${ROOT_DIR}/scripts/dev/configs/starship.toml" ]]; then
  mkdir -p "${USER_HOME}/.config"
  cp "${ROOT_DIR}/scripts/dev/configs/starship.toml" "${USER_HOME}/.config/starship.toml"
  chown -R "$USER_NAME:$USER_NAME" "${USER_HOME}/.config"
  echo "[setup-shell] starship.toml скопирован"
fi

ZSHRC="${USER_HOME}/.zshrc"
if ! grep -q "eval \"\$(starship init zsh)\"" "$ZSHRC" 2>/dev/null; then
  echo '[setup-shell] Добавление Starship в .zshrc...'
  printf '\n# Starship prompt\nif command -v starship >/dev/null 2>&1; then\n  eval "$(starship init zsh)"\nfi\n' >> "$ZSHRC"
fi

chsh -s "$(command -v zsh)" "$USER_NAME" || true

echo "[setup-shell] Готово. Требуется ручная полировка конфигов позже."

