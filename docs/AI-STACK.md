### **AI‑стек VibeCode OS**

Полный набор AI‑инструментов для локальной разработки с LLM и генерацией изображений.

---

### **Локальные LLM**

**Ollama**
- Основной способ запуска локальных LLM
- Systemd-сервис для автозапуска
- Скрипт: `scripts/ai/install-ollama.sh`

**Модели**
- llama3.2 — универсальная модель
- codellama — для программирования
- qwen2.5-coder — современная кодинг-модель
- Установка: `scripts/ai/install-ollama-models.sh`

**Open WebUI**
- Веб-интерфейс для Ollama
- Запускается через Docker на порту 3000
- Скрипт: `scripts/ai/install-open-webui.sh`

---

### **AI в терминале**

**ai-chat**
- CLI-утилита для общения с Ollama
- Интерактивный режим с командами /exit, /clear, /models
- Одиночные запросы: `ai-chat "ваш вопрос"`
- Выбор модели: `MODEL=codellama ai-chat`
- Установлен в `/usr/local/bin/ai-chat`

---

### **AI в редакторах**

**VSCodium**
- Расширение Continue для локальных моделей через Ollama
- Автодополнение и чат без внешних ключей
- Настройка после установки VSCodium

**Neovim**
- Плагины для интеграции с Ollama
- Быстрые действия по коду через локальный backend
- Настройка через AstroNvim

---

### **Генерация изображений**

**ComfyUI + Stable Diffusion**
- Установка в `/opt/vibecode/comfyui`
- Гибкие пайплайны генерации
- CPU-версия по умолчанию, инструкции для GPU
- Запуск: `sudo bash scripts/ai/start-sd.sh`
- Веб-интерфейс: http://localhost:8188
- Модели: `/opt/vibecode/comfyui/models/`

---

### **AI‑фреймворки и библиотеки**

Виртуальное окружение `~/.venv-ai` с предустановленными библиотеками:

- PyTorch (CPU, с инструкциями для GPU)
- Transformers, Accelerate
- LangChain, LangChain Community
- LlamaIndex
- Ollama Python SDK
- NumPy, Pandas, Matplotlib, Jupyter

Установка: `scripts/ai/setup-python-ai-stack.sh`

Активация: `ai-env` (алиас в shell)

Для GPU PyTorch:
```bash
source ~/.venv-ai/bin/activate
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

---

### **Проприетарные облачные помощники (опционально)**

Не входят в базовую установку, требуют API-ключи:

**OpenAI CLI**
- Скрипт: `scripts/ai/install-openai-cli.sh`
- Требует `OPENAI_API_KEY`

**GitHub Copilot CLI**
- Скрипт: `scripts/ai/install-github-copilot-cli.sh`
- Требует GitHub аккаунт и подписку

**Другие инструменты**
- Cursor — проприетарный IDE с AI
- Claude — через веб или API
- Warp — терминал с AI-функциями

Документация по интеграции в `docs/AI-STACK.md`

---

### **Быстрый старт**

Полная установка AI-стека:
```bash
sudo ./scripts/ai/setup-ai-stack.sh
```

Загрузка моделей:
```bash
sudo ./scripts/ai/install-ollama-models.sh
```

Использование:
- Open WebUI: http://localhost:3000
- Terminal AI: `ai-chat`
- Python AI: `ai-env` → активация окружения
- ComfyUI: `sudo bash scripts/ai/start-sd.sh` → http://localhost:8188

### **Требования по ресурсам**

**Минимум (CPU-режим):**
- RAM: 8GB (16GB рекомендуется)
- Диск: 20GB для моделей
- CPU: 4+ ядра

**Рекомендуется (GPU):**
- NVIDIA GPU с 8GB+ VRAM
- CUDA 12.1+
- Драйверы NVIDIA установлены
- 32GB RAM для комфортной работы

**Модели:**
- llama3.2 (3B) — ~2GB
- codellama (7B) — ~4GB
- qwen2.5-coder (7B) — ~4GB
- SD 1.5 — ~4GB

