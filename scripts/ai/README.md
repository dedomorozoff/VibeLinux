# AI Stack Scripts

Скрипты для установки и настройки AI-инструментов в VibeCode OS.

## Быстрый старт

Полная установка AI-стека:
```bash
sudo ./setup-ai-stack.sh
```

## Компоненты

### Локальные LLM

**install-ollama.sh**
- Устанавливает Ollama
- Настраивает systemd-сервис
- Автозапуск при загрузке системы

**install-ollama-models.sh**
- Загружает базовые модели (llama3.2, codellama, qwen2.5-coder)
- Использование: `./install-ollama-models.sh [model1 model2 ...]`

**install-open-webui.sh**
- Устанавливает Open WebUI через Docker
- Веб-интерфейс на http://localhost:3000
- Подключается к локальному Ollama

### Terminal AI

**ai-chat**
- CLI для общения с Ollama
- Интерактивный режим: `ai-chat`
- Одиночный запрос: `ai-chat "ваш вопрос"`
- Выбор модели: `MODEL=codellama ai-chat`

### Python AI

**setup-python-ai-stack.sh**
- Создаёт venv в ~/.venv-ai
- Устанавливает PyTorch, Transformers, LangChain, LlamaIndex
- Алиас для активации: `ai-env`
- Работает в Arch и Debian/Ubuntu (`pacman` или `apt-get`)

### Генерация изображений

**setup-comfyui.sh**
- Устанавливает ComfyUI в /opt/vibecode/comfyui
- CPU-версия по умолчанию
- Инструкции для GPU в выводе скрипта
- Работает в Arch и Debian/Ubuntu (`pacman` или `apt-get`)

**start-sd.sh**
- Запускает ComfyUI
- Веб-интерфейс на http://localhost:8188

### Проприетарные инструменты (опционально)

**install-openai-cli.sh**
- OpenAI CLI (требует API-ключ)
- Системные зависимости ставятся через `pacman` или `apt-get`

**install-github-copilot-cli.sh**
- GitHub Copilot CLI (требует подписку)
- Системные зависимости ставятся через `pacman` или `apt-get`

**install-codex-cli.sh**
- OpenAI Codex CLI
- Системные зависимости ставятся через `pacman` или `apt-get`

**install-claude-code.sh**
- Anthropic Claude Code
- Системные зависимости ставятся через `pacman` или `apt-get`

**install-qwen-code.sh**
- Qwen Code
- Системные зависимости ставятся через `pacman` или `apt-get`

**install-terminal-ai.sh**
- Дополнительные терминальные AI-утилиты
- Работает в Arch и Debian/Ubuntu (`pacman` или `apt-get`)

## Требования

**Минимум:**
- 8GB RAM (16GB рекомендуется)
- 20GB свободного места
- 4+ ядра CPU

**Для GPU:**
- NVIDIA GPU с 8GB+ VRAM
- CUDA 12.1+
- Драйверы NVIDIA

## Документация

Полная документация: `docs/AI-STACK.md`
