### VibeCode OS

**VibeCode OS** — дистрибутив Linux для «вайбкодинга» и AI‑разработки из коробки.

[![Build ISO](https://github.com/yourusername/vibecodeos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/yourusername/vibecodeos/actions/workflows/build-iso.yml)
[![Release](https://github.com/yourusername/vibecodeos/actions/workflows/release.yml/badge.svg)](https://github.com/yourusername/vibecodeos/actions/workflows/release.yml)

---

### 📥 Скачать

**Последний релиз:** [Releases](https://github.com/yourusername/vibecodeos/releases)

Или собрать самостоятельно:
```bash
# Полная версия (с GUI)
make full

# Минимальная версия (только CLI)
make mini

# Проверка зависимостей
make check
```

---

### 📦 Редакции

| Параметр | **Full** | **Minimal** |
|----------|----------|-------------|
| **Размер** | ~3-4 ГБ | ~500 МБ - 1 ГБ |
| **GUI** | ✅ MATE Desktop | ❌ Только CLI |
| **Dev-стек** | ✅ Полный | ❌ Базовый |
| **AI-стек** | ✅ Ollama, Open WebUI | ❌ Нет |
| **Назначение** | Desktop для разработки | Сервер, контейнеры, база |

**Подробнее:** [EDITIONS.md](EDITIONS.md) — подробное сравнение редакций

---

### ✨ Что включено

#### Полная версия (Full)

**Базовая система:**
- Ubuntu 24.04 LTS — стабильная база
- MATE Desktop — лёгкое окружение
- Брендинг VibeCode OS — темы, обои, шрифты
- Установщик Ubiquity
- LightDM — дисплей-менеджер

**Терминал и оболочка:**
- **Kitty** — GPU-ускоренный терминал
- **Zsh** + **Oh My Zsh** — оболочка с плагинами
- **Starship** — кроссплатформенный промпт
- **CLI-утилиты:**
  - `eza` — современная замена `ls`
  - `bat` — замена `cat` с подсветкой
  - `fd` — быстрая замена `find`
  - `ripgrep (rg)` — быстрый поиск текста
  - `fzf` — нечёткий поиск
  - `zoxide` — умные переходы по каталогам
  - `btop` — монитор ресурсов

**Языки программирования:**
- **Python** (3.11, 3.12) через `pyenv`
- **Node.js** (LTS + latest) через `nvm`
- **Rust** через `rustup`
- **Go** (свежая версия)
- **Java 21 LTS** через `SDKMAN!`

**Редакторы и IDE:**
- **VSCodium** с расширениями:
  - GitLens, Docker, Python, Pylance
  - ESLint, Prettier
  - Rust Analyzer, Go, Java
  - C/C++, YAML, JSON, XML
  - GitHub Actions, REST Client
  - Темы: Tokyo Night, Catppuccin
  - AI: Kilo Code, Continue, Aider, GitHub Copilot
- **Neovim** + **AstroNvim** — готовая конфигурация
- **Zed** — быстрый современный редактор

**Инструменты разработки:**
- **Git** — контроль версий
- **lazygit** — TUI для Git
- **Docker** + **Docker Compose** — контейнеризация

**AI-стек:**
- **Ollama** — локальные LLM (llama3.2, codellama, qwen2.5-coder)
- **Open WebUI** — веб-интерфейс для моделей
- **ai-chat** — терминальный AI-чат
- **Aider** — AI-парное программирование
- **Python AI-библиотеки:**
  - PyTorch (CPU), Transformers, Accelerate
  - LangChain, LlamaIndex
  - NumPy, Pandas, Matplotlib, Jupyter
- **ComfyUI** — генерация изображений (Stable Diffusion)

**Шрифты:**
- JetBrains Mono
- Fira Code
- Cascadia Code
- Hack

---

#### Минимальная версия (Minimal)

**Базовая система:**
- Ubuntu 24.04 LTS — стабильная база
- Ядро: linux-image-generic, linux-headers-generic
- Live-поддержка: casper, squashfs-tools

**Консольные утилиты:**
- **Оболочка:** Zsh
- **Мультиплексор:** Tmux
- **Файловые менеджеры:** MC (Midnight Commander)
- **Текстовые редакторы:** Vim-tiny, Nano
- **Мониторинг:** htop, neofetch
- **Сеть:** curl, wget, NetworkManager, ping, traceroute
- **Архиваторы:** unzip, zip, p7zip-full
- **Разработка:** git, build-essential
- **Навигация:** tree, net-tools
- **Дополнительно:** sudo, ca-certificates, software-properties-common

**VirtualBox Guest Utils** — поддержка гостевой ОС

---

### 🚀 Быстрый старт

#### Сборка ISO (через Makefile)

```bash
# Проверка зависимостей
make check        # Для полной версии
make check-mini   # Для минимальной версии

# Сборка
make full         # Полная версия (с GUI, dev и AI)
make mini         # Минимальная версия (только CLI)

# Быстрая пересборка (сохраняет chroot)
make full-keep
make mini-keep

# Очистка
make clean
```

#### Мастер доустановки (Minimal → Full)

Если у вас установлена Minimal версия, вы можете доустановить компоненты:

```bash
# Из установленной системы (после установки ISO)
sudo vibecode-upgrade

# Или из репозитория
make upgrade
```

Запустится интерактивный мастер с псевдографическим меню, который предложит:
- Терминал и оболочку (Kitty, Zsh, Starship, CLI-утилиты)
- Языки программирования (Python, Node.js, Rust, Go, Java)
- Редакторы и IDE (VSCodium, Neovim, Zed)
- Инструменты разработчика (Git, Docker, lazygit)
- AI-стек (Ollama, Open WebUI, ai-chat, ComfyUI)
- Драйверы NVIDIA

Также можно установить всё сразу одной командой.

**Подробнее:** [docs/MINIMAL-UPGRADE.md](docs/MINIMAL-UPGRADE.md)

#### Сборка ISO (вручную)

```bash
# Полная версия
sudo BUILD_MODE=full ./scripts/build-iso.sh
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-iso.sh  # Быстрая пересборка

# Минимальная версия
sudo BUILD_MODE=full ./scripts/build-minimal-iso.sh
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-minimal-iso.sh
```

#### Тестирование

```bash
# В QEMU
qemu-system-x86_64 -cdrom build/VibeCodeOS-alpha.iso -m 2048 -enable-kvm
qemu-system-x86_64 -cdrom build-minimal/VibeCodeOS-minimal.iso -m 1024

# В VirtualBox (см. docs/TESTING.md)
```

#### Установка на хост-систему

```bash
# Dev-стек
sudo ./scripts/dev/setup-dev-env.sh

# AI-стек
sudo ./scripts/ai/setup-ai-stack.sh
sudo ./scripts/ai/install-ollama-models.sh
```

#### Использование AI

- **Open WebUI:** http://localhost:3000
- **Terminal:** `ai-chat`
- **Python:** `ai-env` (активация окружения)
- **ComfyUI:** `sudo bash scripts/ai/start-sd.sh` → http://localhost:8188
- **Aider:** `aider` (AI-парное программирование)

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

**Основная:**
- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) — миссия, ЦА и ключевые решения
- [roadmap.md](roadmap.md) — стратегический план развития
- [BRANDING.md](BRANDING.md) — брендинг, цвета, шрифты, UX‑принципы
- [AGENTS.md](AGENTS.md) — ожидания от AI‑агента при работе над проектом
- [PACKAGES.md](PACKAGES.md) — **полный список пакетов и программ**
- [EDITIONS.md](EDITIONS.md) — **сравнение редакций (Minimal vs Full)**

**Технические документы:**
- [docs/BUILD-ISO.md](docs/BUILD-ISO.md) — процесс сборки ISO
- [docs/TESTING.md](docs/TESTING.md) — руководство по тестированию
- [docs/RELEASE.md](docs/RELEASE.md) — процесс создания релизов
- [docs/ALPHA-STATUS.md](docs/ALPHA-STATUS.md) — текущий статус разработки
- [docs/DEVSTACK.md](docs/DEVSTACK.md) — dev‑стек (языки, IDE, терминал)
- [docs/AI-STACK.md](docs/AI-STACK.md) — AI‑стек (Ollama, GUI, SD)
- [docs/DRIVERS-NVIDIA.md](docs/DRIVERS-NVIDIA.md) — установка драйверов NVIDIA
- [docs/CORE-OS-PACKAGES.md](docs/CORE-OS-PACKAGES.md) — базовые пакеты системы
- [docs/CORE-OS-SCRIPTS.md](docs/CORE-OS-SCRIPTS.md) — скрипты базовой системы
- [docs/UPGRADE-MINIMAL.md](docs/UPGRADE-MINIMAL.md) — мастер доустановки (из репозитория)
- [docs/MINIMAL-UPGRADE.md](docs/MINIMAL-UPGRADE.md) — **мастер доустановки (из установленной системы)**
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — **решение проблем**

---

### 📦 Скрипты

**Сборка ISO:**
- `Makefile` — удобный интерфейс для сборки (рекомендуется)
- `scripts/build-iso.sh` — сборка полной версии (с GUI)
- `scripts/build-minimal-iso.sh` — сборка минимальной версии (CLI)

**База:**
- `scripts/base/base-packages.sh` — базовые утилиты (htop, curl, wget, git, build-essential)
- `scripts/base/minimal-packages.sh` — минимальный набор для CLI-версии
- `scripts/base/setup-distro-info.sh` — брендинг системы
- `scripts/base/setup-bootloader.sh` — GRUB и Plymouth
- `scripts/base/cleanup.sh` — очистка системы

**Desktop:**
- `scripts/desktop/install-mate.sh` — установка MATE Desktop
- `scripts/desktop/configure-mate-panel.sh` — настройка панели MATE
- `scripts/desktop/setup-installer.sh` — установка Ubiquity (установщик)
- `scripts/desktop/apply-branding.sh` — применение брендинга

**Dev-стек:**
- `scripts/dev/setup-dev-env.sh` — полная установка dev-окружения
- `scripts/dev/setup-shell.sh` — Zsh + Oh My Zsh + Starship + CLI-утилиты
- `scripts/dev/setup-terminal.sh` — Kitty + шрифты
- `scripts/dev/setup-langs.sh` — Python, Node.js, Rust, Go, Java
- `scripts/dev/setup-editors.sh` — VSCodium, Neovim, Zed
- `scripts/dev/setup-devtools.sh` — Git, Docker, lazygit

**AI-стек:**
- `scripts/ai/setup-ai-stack.sh` — полная установка AI-стека
- `scripts/ai/install-ollama.sh` — Ollama (локальные LLM)
- `scripts/ai/install-ollama-models.sh` — загрузка моделей (llama3.2, codellama, qwen2.5-coder)
- `scripts/ai/install-open-webui.sh` — Open WebUI (веб-интерфейс)
- `scripts/ai/setup-python-ai-stack.sh` — Python AI-библиотеки (PyTorch, Transformers, LangChain)
- `scripts/ai/setup-comfyui.sh` — ComfyUI (генерация изображений)
- `scripts/ai/start-sd.sh` — запуск ComfyUI
- `scripts/ai/ai-chat` — терминальный AI-чат
- `scripts/ai/install-aider.sh` — Aider (AI-парное программирование)
- `scripts/ai/install-openai-cli.sh` — OpenAI CLI (опционально)
- `scripts/ai/install-github-copilot-cli.sh` — GitHub Copilot CLI (опционально)

**Драйверы:**
- `scripts/drivers/install-nvidia.sh` — установка проприетарных драйверов NVIDIA

---

### Git / GitHub

Репозиторий подготовлен к инициализации в Git:

- `.gitignore` настроен под типичные артефакты (venv, node_modules, образы ISO и т.п.).
- Workflow `build-iso` собирает ISO в черновом виде, вызывая `scripts/build-iso.sh`.

Следующие шаги:

1. Выполнить `git init` в корне проекта.
2. Добавить удалённый репозиторий на GitHub (`git remote add origin ...`).
3. Создать первый коммит с текущей структурой.

