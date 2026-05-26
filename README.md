### VibeLinux

**VibeLinux** — Linux-дистрибутив для вайбкодинга и AI-разработки из коробки.

---

### 📥 Скачать

**Последний релиз:** [GitHub Releases](https://github.com/anomalyco/VibeLinux/releases)

Или собрать самостоятельно:

```bash
make arch         # Arch Linux (KDE Plasma + полный стек)
make full         # Ubuntu 24.04 Full (KDE Plasma + dev)
make lite         # Ubuntu 24.04 Lite (CLI-only)
```

---

### 📦 Редакции

| Параметр | **Arch** | **Full (Ubuntu)** | **Lite (Ubuntu)** |
|----------|----------|-------------------|-------------------|
| **Размер** | ~3 ГБ | ~3 ГБ | ~1 ГБ |
| **GUI** | ✅ KDE Plasma 6 | ✅ KDE Plasma | ❌ Только CLI |
| **Установщик** | ✅ Calamares | ✅ Ubiquity | Текстовый скрипт |
| **Dev-стек** | ✅ Полный | ✅ Полный | ❌ Базовый |
| **AI-стек** | ✅ Ollama, opencode, qwen-code | ✅ Ollama, Open WebUI | ❌ |
| **Назначение** | Desktop для vibe coding | Desktop для разработки | Сервер, контейнеры |

---

### ✨ Что включено

#### Arch Linux / Full (Ubuntu)

**Базовая система:**
- Arch Linux (rolling) или Ubuntu 24.04 LTS
- KDE Plasma Desktop — современное окружение
- SDDM — дисплей-менеджер с autologin
- Брендинг VibeLinux — темы, обои, шрифты

**Терминал и оболочка:**
- **Kitty** / **Konsole** — GPU-ускоренный терминал
- **Zsh** + **Oh My Zsh** + **Starship** — кастомный промпт
- CLI-утилиты: `eza`, `bat`, `fd`, `ripgrep`, `fzf`, `zoxide`, `btop`

**Языки программирования:**
- **Python** (pyenv), **Node.js** (nvm), **Rust** (rustup)
- **Go**, **PHP** — системные пакеты

**Редактор:**
- **Zed** — ультрабыстрый современный редактор

**Инструменты разработки:**
- **Git** + **lazygit** — TUI для Git
- **Docker** + **Docker Compose** — контейнеризация

**AI-стек (в ISO):**
- **Ollama** — локальные LLM (автозапуск)
- **opencode** — AI-агент для кодинга
- **qwen-code** — Qwen AI-агент
- **nlsh** — Natural Language Shell (AI-ассистент в терминале)

**AI-стек (post-install):**
- `setup-python-ai-stack.sh` — PyTorch, Transformers, LangChain, LlamaIndex
- `install-open-webui.sh` — веб-интерфейс для моделей
- `setup-comfyui.sh` — генерация изображений (Stable Diffusion)
- `install-aider.sh` — AI-парное программирование
- `install-claude-code.sh`, `install-cursor.sh` — проприетарные AI-агенты

**Графические приложения:**
- **Pinta** — графический редактор
- **Bruno** — API-клиент (REST/GraphQL)
- **Spectacle**, **Flameshot** — скриншоты
- **DB Browser for SQLite** — GUI для баз данных

**Шрифты:**
- JetBrains Mono (Nerd Font), Fira Code, Cascadia Code, Hack, Noto CJK

**Локализация:**
- Русский язык по умолчанию
- Раскладка RU/US (переключение Alt+Shift)

---

#### Lite (Ubuntu)

- Ubuntu 24.04 LTS, CLI-only
- Zsh + Starship
- Git, build-essential
- htop, tmux, mc, curl, wget

---

### 🚀 Быстрый старт

#### Сборка ISO

```bash
# Arch Linux
make arch

# Ubuntu
make full
make lite

# С сохранением chroot (для ускорения повторной сборки)
make full-keep
```

#### Установка на хост-систему

```bash
# Dev-стек
sudo ./scripts/dev/setup-dev-env.sh

# AI-стек (post-install)
sudo ./scripts/ai/setup-ai-stack.sh
sudo ./scripts/ai/install-ollama-models.sh
```

#### Использование AI

- **Ollama:** `ollama run qwen2.5-coder`
- **opencode:** `opencode`
- **qwen-code:** `qwen`
- **nlsh:** `nlsh repl`
- **ai-chat:** `ai-chat`
- **Open WebUI:** http://localhost:3000

---

### 📚 Документация

- [roadmap.md](roadmap.md) — стратегический план
- [BRANDING.md](BRANDING.md) — брендинг и UX-принципы
- [AGENTS.md](AGENTS.md) — ожидания от AI-агента
- [docs/BUILD-ISO.md](docs/BUILD-ISO.md) — процесс сборки ISO
- [docs/DEVSTACK.md](docs/DEVSTACK.md) — dev-стек
- [docs/AI-STACK.md](docs/AI-STACK.md) — AI-стек

---

### 📦 Скрипты

**Сборка ISO:**
- `scripts/build/build-vibe-arch.sh` — Arch Linux
- `scripts/build/build-vibe-full-ubuntu.sh` — Ubuntu Full
- `scripts/build/build-vibe-lite-ubuntu.sh` — Ubuntu Lite
- `scripts/build-iso.sh` — основной оркестратор (Ubuntu)

**Dev-стек:**
- `scripts/dev/setup-dev-env.sh` — полная установка
- `scripts/dev/setup-editors.sh` — Zed
- `scripts/dev/setup-langs.sh` — языки
- `scripts/dev/setup-shell.sh` — Zsh + Starship
- `scripts/dev/setup-terminal.sh` — Kitty

**AI-стек (post-install):**
- `scripts/ai/setup-ai-stack.sh` — агрегатор
- `scripts/ai/install-ollama.sh`
- `scripts/ai/install-ollama-models.sh`
- `scripts/ai/setup-python-ai-stack.sh` — Python AI libs
- `scripts/ai/setup-comfyui.sh` — ComfyUI
- `scripts/ai/install-open-webui.sh`
- `scripts/ai/install-aider.sh`

**Драйверы:**
- `scripts/drivers/install-nvidia.sh`
