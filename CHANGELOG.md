# Changelog

## [Unreleased]

### Added

**Core OS:**
- Настройка GRUB и Plymouth с брендингом VibeCode OS
- Скрипт `setup-bootloader.sh` для кастомизации загрузчика
- Базовая система на Ubuntu 24.04 LTS + MATE

**Dev Stack:**
- Полная установка dev-окружения через `setup-dev-env.sh`
- Zsh + Oh My Zsh + Starship
- Kitty терминал
- Языки: Python (pyenv 3.11/3.12), Node.js (nvm v0.40.4), Rust, Go, Java 21 LTS
- Редакторы: VSCodium, Neovim (AstroNvim), Zed
- Docker, Git, lazygit

**AI Stack:**
- Ollama для локальных LLM
- Open WebUI (веб-интерфейс на порту 3000)
- ai-chat — интерактивный терминальный чат
- Python AI окружение: PyTorch, Transformers, LangChain, LlamaIndex
- ComfyUI для Stable Diffusion
- Модели: llama3.2, codellama, qwen2.5-coder
- Агрегирующий скрипт `setup-ai-stack.sh`

**Documentation:**
- Обновлён DEVSTACK.md с конкретными версиями
- Обновлён AI-STACK.md с требованиями по ресурсам
- README для scripts/ai
- Обновлён главный README.md

### Changed
- nvm обновлён до v0.40.4
- Модели Ollama обновлены до актуальных версий
- ai-chat получил интерактивный режим с командами

### Fixed
- Исправлены пути в скриптах сборки
- Добавлены проверки зависимостей

## [0.1.0-alpha] - TBD

Первый альфа-релиз VibeCode OS
