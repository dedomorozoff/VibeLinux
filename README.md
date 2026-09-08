### VibeLinux

**VibeLinux** — Linux-дистрибутив для вайбкодинга и AI-разработки из коробки.

---

### 📥 Скачать

**Последний релиз:** [GitHub Releases](https://github.com/anomalyco/VibeLinux/releases)

Или собрать самостоятельно:

```bash
make arch              # Arch Linux (KDE Plasma + полный стек)
make legacy-full       # Ubuntu 24.04 Full (KDE Plasma + dev, legacy)
make legacy-lite       # Ubuntu 24.04 Lite (CLI-only, legacy)
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

#### Arch Linux (основная) / Full (Ubuntu, legacy)

**Базовая система:**
- Arch Linux (rolling) — основная редакция; Ubuntu 24.04 LTS — legacy
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

**AI-стек (в ISO, предустановлен — работает и в live, и на установленной системе):**
- **opencode**, **qwen-code**, **Claude Code**, **Codex**, **Kilo**, **MiMo**, **Continue**, **Crush**, **Kimi** — все CLI-агенты запечены в образ
- **dmsh** — Natural Language Shell (AI-ассистент в терминале)

**Ollama и тяжёлый AI-стек (post-install, после установки на диск):**
- `sudo install-ollama` — рантайм локальных LLM (в live-ISO не входит: пакет ~500 МБ)
- `sudo ai-setup` — базовые Ollama-модели
- `sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh` — PyTorch, Transformers, LangChain, LlamaIndex, Open WebUI, ComfyUI
- В live-сессии корень — RAM-оверлей, поэтому тяжёлые компоненты ставятся только после установки на диск

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
- btop, tmux, mc, curl, wget

---

### 🚀 Быстрый старт

#### Сборка ISO

```bash
# Arch Linux (основная линия)
make arch

# Ubuntu (legacy)
make legacy-full
make legacy-lite

# С сохранением chroot (для ускорения повторной сборки, legacy)
make legacy-full-keep

# FreeBSD (экспериментальная редакция VibeBSD, сборка на FreeBSD-хосте)
make bsd
```

#### Установка на хост-систему

```bash
# Dev-стек
sudo ./scripts/dev/setup-dev-env.sh

# AI-стек (post-install; в образе VibeLinux Arch CLI-агенты уже предустановлены,
# ollama ставится отдельно — install-ollama.sh)
sudo ./scripts/ai/install-ollama.sh
sudo ./scripts/ai/setup-ai-stack.sh
sudo ./scripts/ai/install-ollama-models.sh
```

#### Использование AI

- **Ollama** (после `install-ollama`): `ollama run qwen2.5-coder`
- **opencode:** `opencode`
- **qwen-code:** `qwen`
- **Claude Code:** `claude`
- **Codex:** `codex`
- **dmsh:** `dmsh`
- **ai-chat:** `ai-chat`
- **Open WebUI:** http://localhost:3000 (после `setup-ai-stack.sh`)

---

### 📚 Документация

- [roadmap.md](roadmap.md) — стратегический план
- [BRANDING.md](BRANDING.md) — брендинг и UX-принципы
- [AGENTS.md](AGENTS.md) — ожидания от AI-агента
- [docs/BUILD-ISO.md](docs/BUILD-ISO.md) — процесс сборки ISO
- [docs/DEVSTACK.md](docs/DEVSTACK.md) — dev-стек
- [docs/AI-STACK.md](docs/AI-STACK.md) — AI-стек
- [docs/VIBEBSD.md](docs/VIBEBSD.md) — экспериментальная FreeBSD-редакция

---

### 📦 Скрипты

**Сборка ISO:**
- `scripts/build/build-vibe-arch.sh` — Arch Linux (основная)
- `scripts/legacy/build-vibe-full-ubuntu.sh` — Ubuntu Full (legacy)
- `scripts/legacy/build-vibe-lite-ubuntu.sh` — Ubuntu Lite (legacy)
- `scripts/legacy/build-iso.sh` — оркестратор Ubuntu Full (legacy)

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

**Драйверы:**
- `scripts/drivers/install-nvidia.sh`
