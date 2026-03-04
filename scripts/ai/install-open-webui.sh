#!/usr/bin/env bash
set -euo pipefail

# Установка и запуск Open WebUI как локального GUI для Ollama.
# Реализация через Docker (самый простой воспроизводимый путь).

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[install-open-webui] Проверка Docker..."
if ! command -v docker >/dev/null 2>&1; then
  echo "[install-open-webui] Docker не найден. Сначала запустите scripts/dev/setup-devtools.sh"
  exit 1
fi

echo "[install-open-webui] Создание volume для данных..."
docker volume create open-webui || true

echo "[install-open-webui] Запуск контейнера Open WebUI..."
docker run -d \
  --name open-webui \
  --restart unless-stopped \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

echo "[install-open-webui] Готово. WebUI доступен на http://localhost:3000"

