#!/usr/bin/env bash
set -euo pipefail

# Скрипт для загрузки базовых моделей Ollama.
# Использование: ./install-ollama-models.sh [model1 model2 ...]
# Без аргументов загружает базовый набор.

if [[ $# -gt 0 ]]; then
  MODELS=("$@")
else
  MODELS=(
    "llama3.2:latest"
    "codellama:latest"
    "qwen2.5-coder:latest"
  )
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "[install-ollama-models] Команда 'ollama' не найдена. Установите Ollama перед запуском этого скрипта."
  exit 1
fi

for model in "${MODELS[@]}"; do
  echo "[install-ollama-models] Загрузка модели: ${model}..."
  if ollama pull "${model}"; then
    echo "[install-ollama-models] ✓ ${model} загружена"
  else
    echo "[install-ollama-models] ✗ Не удалось загрузить ${model}"
  fi
done

echo ""
echo "[install-ollama-models] Список установленных моделей:"
ollama list

echo "[install-ollama-models] Готово."
