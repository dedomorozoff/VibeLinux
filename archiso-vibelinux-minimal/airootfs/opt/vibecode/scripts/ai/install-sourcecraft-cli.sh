#!/usr/bin/env bash
set -euo pipefail

# Установка SourceCraft Code Assistant CLI (Яндекс, бесплатно без VPN).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-sourcecraft-cli] Установка curl (если нужно)..."
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed curl ca-certificates
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates || true
else
  echo "[install-sourcecraft-cli] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[install-sourcecraft-cli] curl не найден после установки."
  exit 1
fi

echo "[install-sourcecraft-cli] Установка SourceCraft CLI (глобально, команда: src)..."
# -i /usr/local → бинарник в /usr/local/bin; -n — не трогать rc-файлы.
# Без этого установщик кладёт бинарник в $HOME/sourcecraft/bin/src.
curl -fsSL https://s3.yandexcloud.net/sourcecraft-cli/install.sh | sh -s -- -i /usr/local -n || {
  echo "[install-sourcecraft-cli] Не удалось установить SourceCraft CLI."
  exit 1
}

cat <<'EOF'
[install-sourcecraft-cli] Готово.

Дальнейшие шаги:
  1. Перезапустить терминал (чтобы подхватился PATH).
  2. Запустить `src` и пройти авторизацию.
  3. Документация: https://sourcecraft.dev/portal/docs/ru/sourcecraft/operations/cli-quickstart
EOF