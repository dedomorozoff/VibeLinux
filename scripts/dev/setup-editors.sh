#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки редакторов: VSCodium, Neovim, Zed для VibeCode OS.

# Определяем ROOT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
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

echo "[setup-editors] Настройка VSCodium..."
# В chroot среде конфиги копируются в /root/configs/ (из build-iso.sh)
# Для хост-системы используем относительные пути
VSCODIUM_SETTINGS=""
VSCODIUM_EXTENSIONS=""

# Проверяем возможные расположения конфигов
if [[ -f "/root/configs/vscodium-settings.json" ]]; then
  VSCODIUM_SETTINGS="/root/configs/vscodium-settings.json"
elif [[ -f "/root/dev-configs/vscodium-settings.json" ]]; then
  VSCODIUM_SETTINGS="/root/dev-configs/vscodium-settings.json"
elif [[ -n "${ROOT_DIR:-}" ]] && [[ -f "${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json" ]]; then
  VSCODIUM_SETTINGS="${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json"
fi

if [[ -f "/root/configs/vscodium-extensions.txt" ]]; then
  VSCODIUM_EXTENSIONS="/root/configs/vscodium-extensions.txt"
elif [[ -f "/root/dev-configs/vscodium-extensions.txt" ]]; then
  VSCODIUM_EXTENSIONS="/root/dev-configs/vscodium-extensions.txt"
elif [[ -n "${ROOT_DIR:-}" ]] && [[ -f "${ROOT_DIR}/scripts/dev/configs/vscodium-extensions.txt" ]]; then
  VSCODIUM_EXTENSIONS="${ROOT_DIR}/scripts/dev/configs/vscodium-extensions.txt"
fi

# Применяем настройки VSCodium
if [[ -n "$VSCODIUM_SETTINGS" ]] && [[ -f "$VSCODIUM_SETTINGS" ]]; then
  mkdir -p "/home/${USER_NAME}/.config/codium/User"
  cp "$VSCODIUM_SETTINGS" "/home/${USER_NAME}/.config/codium/User/settings.json" || true
  echo "[setup-editors] VSCodium settings applied from: $VSCODIUM_SETTINGS"
fi

# Установка расширений если есть файл со списком
if [[ -n "$VSCODIUM_EXTENSIONS" ]] && [[ -f "$VSCODIUM_EXTENSIONS" ]]; then
  if command -v codium >/dev/null 2>&1; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^# ]] && continue
      extension_id=$(echo "$line" | awk '{print $1}')
      if [[ -n "$extension_id" ]]; then
        su - "$USER_NAME" -c "codium --install-extension '$extension_id'" 2>/dev/null || true
      fi
    done < "$VSCODIUM_EXTENSIONS"
    echo "[setup-editors] VSCodium extensions installed from: $VSCODIUM_EXTENSIONS"
  else
    echo "[setup-editors] Пропуск установки расширений VSCodium: codium не найден в PATH"
  fi
fi

echo "[setup-editors] Готово."
