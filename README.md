### VibeCode OS

**VibeCode OS** — дистрибутив Linux для «вайбкодинга» и AI‑разработки из коробки.

[![Build ISO](https://github.com/yourusername/vibecodeos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/yourusername/vibecodeos/actions/workflows/build-iso.yml)
[![Release](https://github.com/yourusername/vibecodeos/actions/workflows/release.yml/badge.svg)](https://github.com/yourusername/vibecodeos/actions/workflows/release.yml)

---

### 📥 Скачать

**Последний релиз:** [Releases](https://github.com/yourusername/vibecodeos/releases)

Или собрать самостоятельно:
```bash
sudo BUILD_MODE=full ./scripts/build-iso.sh
```

---

### ✨ Что включено

**Базовая система:**
- Ubuntu 24.04 LTS — стабильная база
- MATE Desktop — лёгкое окружение
- Брендинг VibeCode OS — темы, обои, шрифты
- Установщик Ubiquity

**Dev-стек:**
- Терминал: Kitty + Zsh + Starship
- Языки: Python (pyenv), Node.js (nvm), Rust, Go, Java
- Редакторы: VSCodium, Neovim (AstroNvim), Zed
- Инструменты: Git, Docker, lazygit

**AI-стек:**
- Ollama — локальные LLM
- Open WebUI — веб-интерфейс для моделей
- ai-chat — терминальный AI-чат
- Python AI: PyTorch, Transformers, LangChain, LlamaIndex
- ComfyUI — генерация изображений через Stable Diffusion

---

### 🚀 Быстрый старт

#### Установка Dev-стека

```bash
sudo ./scripts/dev/setup-dev-env.sh
```

#### Установка AI-стека

```bash
sudo ./scripts/ai/setup-ai-stack.sh
sudo ./scripts/ai/install-ollama-models.sh
```

Использование AI:
- Open WebUI: http://localhost:3000
- Terminal: `ai-chat`
- Python: `ai-env` (активация окружения)
- ComfyUI: `sudo bash scripts/ai/start-sd.sh`

#### Сборка ISO

```bash
# Проверка зависимостей
BUILD_MODE=dry-run ./scripts/build-iso.sh

# Полная сборка
sudo BUILD_MODE=full ./scripts/build-iso.sh

# Быстрая пересборка (сохраняет chroot)
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-iso.sh
```

#### Тестирование

```bash
# В QEMU
qemu-system-x86_64 -cdrom build/VibeCodeOS-alpha.iso -m 2048 -enable-kvm

# В VirtualBox (см. docs/TESTING.md)
```

#### Создание релиза

```bash
# Через Git тег
git tag v0.1.0-alpha
git push origin v0.1.0-alpha

# Или через GitHub UI: Actions → Release VibeCode OS → Run workflow
```

Подробнее: [docs/RELEASE.md](docs/RELEASE.md)

---

### 📚 Документация

- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) — миссия, ЦА и ключевые решения
- [roadmap.md](roadmap.md) — стратегический план развития
- [BRANDING.md](BRANDING.md) — брендинг, цвета, шрифты, UX‑принципы
- [AGENTS.md](AGENTS.md) — ожидания от AI‑агента при работе над проектом

**Технические документы:**
- [docs/BUILD-ISO.md](docs/BUILD-ISO.md) — процесс сборки ISO
- [docs/TESTING.md](docs/TESTING.md) — руководство по тестированию
- [docs/RELEASE.md](docs/RELEASE.md) — процесс создания релизов
- [docs/ALPHA-STATUS.md](docs/ALPHA-STATUS.md) — текущий статус разработки
- [docs/DEVSTACK.md](docs/DEVSTACK.md) — dev‑стек (языки, IDE, терминал)
- [docs/AI-STACK.md](docs/AI-STACK.md) — AI‑стек (Ollama, GUI, SD)

---

### 📦 Скрипты

**База:**
- `scripts/base/base-packages.sh` — базовые утилиты
- `scripts/base/setup-distro-info.sh` — брендинг системы
- `scripts/base/setup-bootloader.sh` — GRUB и Plymouth
- `scripts/base/cleanup.sh` — очистка

**Dev-стек:**
- `scripts/dev/setup-dev-env.sh` — полная установка dev-окружения
- `scripts/dev/setup-shell.sh` — Zsh + Oh My Zsh + Starship
- `scripts/dev/setup-terminal.sh` — Kitty
- `scripts/dev/setup-langs.sh` — Python, Node.js, Rust, Go, Java
- `scripts/dev/setup-devtools.sh` — Git, Docker, lazygit
- `scripts/dev/setup-editors.sh` — VSCodium, Neovim, Zed

**AI-стек:**
- `scripts/ai/setup-ai-stack.sh` — полная установка AI-стека
- `scripts/ai/install-ollama.sh` — Ollama
- `scripts/ai/install-ollama-models.sh` — загрузка моделей
- `scripts/ai/install-open-webui.sh` — Open WebUI
- `scripts/ai/setup-python-ai-stack.sh` — Python AI-библиотеки
- `scripts/ai/setup-comfyui.sh` — ComfyUI
- `scripts/ai/ai-chat` — терминальный AI-чат
- `scripts/ai/start-sd.sh` — запуск ComfyUI

**Сборка:**
- `scripts/build-iso.sh` — сборка ISO-образа

---

### Git / GitHub

Репозиторий подготовлен к инициализации в Git:

- `.gitignore` настроен под типичные артефакты (venv, node_modules, образы ISO и т.п.).
- Workflow `build-iso` собирает ISO в черновом виде, вызывая `scripts/build-iso.sh`.

Следующие шаги:

1. Выполнить `git init` в корне проекта.
2. Добавить удалённый репозиторий на GitHub (`git remote add origin ...`).
3. Создать первый коммит с текущей структурой.

