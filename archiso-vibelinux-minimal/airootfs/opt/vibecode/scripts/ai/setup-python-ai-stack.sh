#!/usr/bin/env bash
set -euo pipefail

# Установка Python AI-стека: PyTorch, Transformers, LangChain и др.
# По умолчанию ставит CPU-версии, для GPU нужно переустановить PyTorch.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_HOME="${USER_HOME:-/home/$USER_NAME}"

run_as_user() {
  if command -v sudo >/dev/null 2>&1; then
    sudo -u "$USER_NAME" bash -lc "$1"
  else
    su - "$USER_NAME" -c "$1"
  fi
}

echo "[setup-python-ai] Установка системных зависимостей..."
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed \
    python-pip \
    python-virtualenv \
    base-devel
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential
else
  echo "[setup-python-ai] Неподдерживаемый пакетный менеджер (нужен pacman или apt-get)."
  exit 1
fi

echo "[setup-python-ai] Создание виртуального окружения для AI..."
run_as_user '
  if [ ! -d "$HOME/.venv-ai" ]; then
    python3 -m venv "$HOME/.venv-ai"
  fi
'

echo "[setup-python-ai] Установка AI-библиотек..."
run_as_user '
  source "$HOME/.venv-ai/bin/activate"

  # Обновляем pip
  pip install --upgrade pip setuptools wheel

  # PyTorch CPU (для GPU: pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121)
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

  # Transformers и связанные
  pip install transformers accelerate sentencepiece protobuf

  # LangChain экосистема
  pip install langchain langchain-community langchain-core

  # LlamaIndex
  pip install llama-index

  # Ollama Python SDK
  pip install ollama

  # Дополнительные утилиты
  pip install numpy pandas matplotlib jupyter ipython

  echo ""
  echo "✓ AI-стек установлен в ~/.venv-ai"
  echo ""
  echo "Для активации: source ~/.venv-ai/bin/activate"
  echo "Для GPU PyTorch: pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
'

# Добавляем алиас для быстрой активации
if ! grep -q "alias ai-env" "${USER_HOME}/.zshrc" 2>/dev/null; then
  echo "" >> "${USER_HOME}/.zshrc"
  echo "# AI environment" >> "${USER_HOME}/.zshrc"
  echo "alias ai-env='source ~/.venv-ai/bin/activate'" >> "${USER_HOME}/.zshrc"
fi

if ! grep -q "alias ai-env" "${USER_HOME}/.bashrc" 2>/dev/null; then
  echo "" >> "${USER_HOME}/.bashrc"
  echo "# AI environment" >> "${USER_HOME}/.bashrc"
  echo "alias ai-env='source ~/.venv-ai/bin/activate'" >> "${USER_HOME}/.bashrc"
fi

echo "[setup-python-ai] Готово. Используйте 'ai-env' для активации окружения."
