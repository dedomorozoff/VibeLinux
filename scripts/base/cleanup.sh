#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт очистки системы от предустановленного "мусора".
# Задача: показать намерение, а не быть окончательно вылизанным.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[cleanup] Удаление типичных предустановленных пакетов (черновой список)..."

TO_REMOVE=(
  libreoffice-*      # офисный пакет
  thunderbird        # почтовый клиент
  games-*            # пример игровых пакетов
)

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get remove -y "${TO_REMOVE[@]}" || true
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y

echo "[cleanup] Готово. Список пакетов требует уточнения под финальную сборку."

