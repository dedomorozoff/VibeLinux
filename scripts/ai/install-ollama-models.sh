#!/usr/bin/env bash
set -euo pipefail

# Черновой скрипт для загрузки базовых моделей Ollama.

MODELS=(
  "llama3"
  "codellama"
  "mistral"
)

if ! command -v ollama >/dev/null 2>&1; then
  echo "[install-ollama-models] Команда 'ollama' не найдена. Установите Ollama перед запуском этого скрипта."
  exit 1
fi

for model in "${MODELS[@]}"; do
  echo "[install-ollama-models] Загрузка модели: ${model}..."
  ollama pull "${model}" || echo "[install-ollama-models] Не удалось загрузить ${model}, проверьте подключение."
done

echo "[install-ollama-models] Готово."

