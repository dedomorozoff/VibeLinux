#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт установки Git, lazygit, Docker и Docker Compose.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${1:-root}"

echo "[setup-devtools] Установка Git..."
apt-get update -y || true
DEBIAN_FRONTEND=noninteractive apt-get install -y git 2>/dev/null || true

echo "[setup-devtools] Установка lazygit (GitHub release)..."
if ! command -v lazygit >/dev/null 2>&1; then
  LAZYGIT_VERSION=$(curl -sf "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "")
  if [[ -n "$LAZYGIT_VERSION" ]]; then
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" 2>/dev/null \
      && tar xf /tmp/lazygit.tar.gz -C /tmp lazygit \
      && install /tmp/lazygit /usr/local/bin/lazygit \
      && rm -f /tmp/lazygit /tmp/lazygit.tar.gz
  else
    echo "[setup-devtools] Не удалось определить версию lazygit (нет сети?)"
  fi
fi

echo "[setup-devtools] Установка Docker и Docker Compose..."
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin 2>/dev/null || true

echo "[setup-devtools] Добавление пользователя ${USER_NAME} в группу docker..."
usermod -aG docker "$USER_NAME" 2>/dev/null || true

# Docker требует systemd в runtime, пропускаем в chroot
if ! pidof systemd >/dev/null 2>&1; then
  echo "[setup-devtools] Пропуск запуска Docker (chroot режим)"
else
  echo "[setup-devtools] Перезапуск сервиса Docker..."
  systemctl enable docker 2>/dev/null || true
  systemctl restart docker 2>/dev/null || true

  echo "[setup-devtools] Проверка Docker (может занять время)..."
  if docker run --rm hello-world >/dev/null 2>&1; then
    echo "[setup-devtools] Docker работает корректно."
  else
    echo "[setup-devtools] Не удалось запустить hello-world. Проверьте Docker вручную."
  fi
fi

echo "[setup-devtools] Готово."

