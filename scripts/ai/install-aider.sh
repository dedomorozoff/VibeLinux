#!/usr/bin/env bash
set -euo pipefail

# Скрипт установки Aider - AI-инструмента для парного программирования в терминале
# https://aider.chat/

echo "--- Установка Aider ---"

# Aider требует Python. Используем pip из системного или виртуального окружения.
# Рекомендуется устанавливать через pipx или в изолированное окружение.

if ! command -v pipx >/dev/null 2>&1; then
    echo "Установка pipx..."
    if [[ $EUID -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
        echo "Нужны права root/sudo для установки pipx."
        exit 1
    fi

    if command -v pacman >/dev/null 2>&1; then
        if [[ $EUID -eq 0 ]]; then
            pacman -Sy --noconfirm --needed pipx
        else
            sudo pacman -Sy --noconfirm --needed pipx
        fi
    elif command -v apt-get >/dev/null 2>&1; then
        if [[ $EUID -eq 0 ]]; then
            apt-get update -y
            DEBIAN_FRONTEND=noninteractive apt-get install -y pipx
        else
            sudo apt-get update -y
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pipx
        fi
    else
        echo "Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
        exit 1
    fi

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
