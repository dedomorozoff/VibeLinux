#!/bin/bash
set -e

# Скрипт установки Aider - AI-инструмента для парного программирования в терминале
# https://aider.chat/

echo "--- Установка Aider ---"

# Aider требует Python. Используем pip из системного или виртуального окружения.
# Рекомендуется устанавливать через pipx или в изолированное окружение.

if ! command -v pipx &> /dev/null; then
    echo "Установка pipx..."
    sudo apt-get update
    sudo apt-get install -y pipx
    pipx ensurepath
fi

echo "Установка aider-chat через pipx..."
pipx install aider-chat

# Добавляем алиас или проверяем доступность
if command -v aider &> /dev/null; then
    echo "Aider успешно установлен!"
    aider --version
else
    echo "Предупреждение: aider может быть не в PATH. Попробуйте перезапустить терминал или использовать 'pipx ensurepath'."
fi

echo "Для работы Aider с Ollama используйте:"
echo "aider --model ollama/qwen2.5-coder"
