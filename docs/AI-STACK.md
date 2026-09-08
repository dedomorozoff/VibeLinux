### **AI‑стек VibeCode OS**

Полный набор AI‑инструментов для локальной разработки с LLM и генерацией изображений.

**⚡ Полный список AI-компонентов см. также в [`PACKAGES.md`](../PACKAGES.md#ai-стек).**

---

### **Локальные LLM**

**Ollama**
- Основной способ запуска локальных LLM
- Systemd-сервис для автозапуска
- **Не входит в live-ISO** (пакет ~500 МБ): ставится post-install на установленной системе — `sudo install-ollama` или `scripts/ai/install-ollama.sh`
- Скрипт для других систем: `scripts/ai/install-ollama.sh`

**Модели**
- llama3.2 — универсальная модель
- codellama — для программирования
- qwen2.5-coder — современная кодинг-модель
- Модели **не входят в ISO** (2–4 ГБ каждая) — скачиваются post-install: `ai-setup` или `scripts/ai/install-ollama-models.sh`
- В live-сессии корень — RAM-оверлей, поэтому ollama и модели ставятся **после установки на диск**.

**Open WebUI**
- Веб-интерфейс для Ollama
- Запускается через Docker на порту 3000
- Скрипт: `scripts/ai/install-open-webui.sh`

---

### **AI-агенты в терминале**

**ai-chat**
- Простая CLI-утилита для быстрого общения с локальными моделями Ollama.
- Интерактивный режим с командами /exit, /clear, /models.
- Установлен в `/usr/local/bin/ai-chat`.

**Современные agentic CLI**
- **Codex CLI** — `codex` (OpenAI)
- **Claude Code** — `claude` (Anthropic)
- **Qwen Code** — `qwen` (Alibaba)
- **SourceCraft CLI** — `sourcecraft` (Яндекс Code Assistant, бесплатно без VPN)
- **Koda CLI** — `koda` (ООО «Кода», форк gemini-cli)
- **Kilo Code / MiMo Code / Continue** — `kilo`, `mimo`, `cn`
- **Crush** — `crush` (Charm, LSP + MCP, multi-model)
- **Kimi Code CLI** — `kimi` (Moonshot AI)
- **В образе VibeLinux Arch все перечисленные CLI предустановлены** на этапе сборки (запечены в squashfs), поэтому работают и в live-сессии, и на установленной системе без прав root и без доустановки. Скрипты в `scripts/ai/install-*.sh` остаются для других систем (Ubuntu legacy, bare-metal).

---

### **AI в редакторах**

**Continue.dev**
- Open-source AI assistant для VS Code / VSCodium / Neovim
- Работает с локальными моделями через Ollama (без API-ключей)
- Установка расширения: `scripts/ai/install-continue.sh`

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

Виртуальное окружение `~/.venv-ai`, создаётся скриптом `scripts/ai/setup-python-ai-stack.sh`:

- PyTorch (CPU, с инструкциями для GPU)
- Transformers, Accelerate (стабильные версии с PyPI)
- LangChain Core
- LlamaIndex
- ChromaDB (векторная БД для RAG)
- HuggingFace Hub (huggingface-cli для управления моделями)
- Ollama Python SDK

Активация: `ai-env` (alias на `source ~/.venv-ai/bin/activate`)

Для GPU PyTorch:
```bash
ai-env
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
- Codex CLI — локальный агент OpenAI в терминале
- Claude Code — агент Anthropic для codebase/terminal workflows
- Qwen Code — open-source terminal agent с поддержкой OpenAI/Anthropic-compatible API
- Cursor — проприетарный IDE с AI
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
- Python AI: `ai-env` (активация окружения `~/.venv-ai`)
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

