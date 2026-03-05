#!/usr/bin/env bash
set -euo pipefail

# Установка Python AI-стека: PyTorch, Transformers, LangChain и др.
# По умолчанию ставит CPU-версии, для GPU нужно переустановить PyTorch.

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"

echo "[setup-python-ai] Установка системных зависимостей..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential

echo "[setup-python-ai] Создание виртуального окружения для AI..."
sudo -u "$USER_NAME" bash -lc '
  if [ ! -d "$HOME/.venv-ai" ]; then
    python3 -m venv "$HOME/.venv-ai"
  fi
'

echo "[setup-python-ai] Установка AI-библиотек..."
sudo -u "$USER_NAME" bash -lc '
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
if ! grep -q "alias ai-env" "/home/$USER_NAME/.zshrc" 2>/dev/null; then
  echo "" >> "/home/$USER_NAME/.zshrc"
  echo "# AI environment" >> "/home/$USER_NAME/.zshrc"
  echo "alias ai-env='source ~/.venv-ai/bin/activate'" >> "/home/$USER_NAME/.zshrc"
fi

if ! grep -q "alias ai-env" "/home/$USER_NAME/.bashrc" 2>/dev/null; then
  echo "" >> "/home/$USER_NAME/.bashrc"
  echo "# AI environment" >> "/home/$USER_NAME/.bashrc"
  echo "alias ai-env='source ~/.venv-ai/bin/activate'" >> "/home/$USER_NAME/.bashrc"
fi

echo "[setup-python-ai] Готово. Используйте 'ai-env' для активации окружения."
