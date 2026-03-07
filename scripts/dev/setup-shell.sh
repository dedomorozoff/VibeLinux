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

export DEBIAN_FRONTEND=noninteractive

echo "[setup-shell] Установка Zsh..."
apt-get update -y || true
apt-get install -y zsh curl git wget || true

# Проверка доступности интернета
check_network() {
  curl -sf --connect-timeout 5 https://github.com >/dev/null 2>&1
}

# Установка Oh My Zsh (полностью автоматическая)
echo "[setup-shell] Установка Oh My Zsh для пользователя ${USER_NAME}..."
if check_network; then
  if [ ! -d "$USER_HOME/.oh-my-zsh" ]; then
    # Качаем и устанавливаем вручную без интерактивного скрипта
    su - "$USER_NAME" -c '
      set -e
      export RUNZSH=no
      export KEEP_ZSHRC=yes
      export CHSH=no
      # Скачиваем архив и распаковываем
      git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" 2>/dev/null || true
      # Создаём базовый .zshrc из шаблона
      cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$HOME/.zshrc" 2>/dev/null || true
    ' || echo "[setup-shell] Oh My Zsh установка пропущена"
  else
    echo "[setup-shell] Oh My Zsh уже установлен"
  fi
else
  echo "[setup-shell] Пропуск Oh My Zsh - нет сети"
fi

# Установка Starship
echo "[setup-shell] Установка Starship..."
if command -v starship >/dev/null 2>&1; then
  echo "[setup-shell] Starship уже установлен"
elif check_network; then
  curl -fsSL https://starship.rs/install.sh 2>/dev/null | bash -s -- -y 2>/dev/null || true
  if ! command -v starship >/dev/null 2>&1; then
    apt-get install -y starship 2>/dev/null || true
  fi
else
  apt-get install -y starship 2>/dev/null || true
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
  echo "[setup-shell] ВНИМАНИЕ: zshrc не найден"
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

# Установка zsh по умолчанию (без chsh - используем usermod)
echo "[setup-shell] Установка Zsh по умолчанию для ${USER_NAME}..."
usermod -s /bin/zsh "$USER_NAME" 2>/dev/null || true

echo "[setup-shell] Готово."

