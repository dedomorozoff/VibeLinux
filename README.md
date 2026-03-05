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

- **Ubuntu 24.04 LTS** — стабильная база
- **MATE Desktop** — лёгкое и продуктивное окружение
- **Брендинг VibeCode OS** — темы, обои, шрифты для кодинга
- **Установщик из коробки** — Ubiquity для установки на диск
- **Базовые утилиты** — git, vim, firefox, network-manager и др.

---

### 🚀 Быстрый старт

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

### Черновые скрипты

Все скрипты рассчитаны на выполнение в среде Ubuntu (например, 24.04) и требуют прав `sudo`/root.

- База:
  - `scripts/base/base-packages.sh` — установка базовых утилит.
  - `scripts/base/cleanup.sh` — удаление типичных предустановленных пакетов.

- Dev‑стек:
  - `scripts/dev/setup-shell.sh` — Zsh + Oh My Zsh + Starship.
  - `scripts/dev/setup-terminal.sh` — Kitty.
  - `scripts/dev/setup-langs.sh` — pyenv, nvm, rustup, SDKMAN!.
  - `scripts/dev/setup-devtools.sh` — Git, lazygit, Docker, Docker Compose.
  - `scripts/dev/setup-dev-env.sh` — агрегирующий скрипт для dev‑окружения.
  - (в дальнейшем сюда может быть добавлен отдельный скрипт установки Zed и преднастроенных тем Kilo Code / OpenCode для VSCodium).

- AI‑стек:
  - `scripts/ai/install-ollama.sh` — установка Ollama и запуск сервиса.
  - `scripts/ai/install-ollama-models.sh` — загрузка базовых моделей Ollama.
  - `scripts/ai/install-open-webui.sh` — запуск Open WebUI (GUI) в Docker.
  - `scripts/ai/install-terminal-ai.sh` — установка `ai-chat` в PATH.
  - `scripts/ai/setup-python-ai-stack.sh` — Python‑библиотеки (torch CPU, transformers, langchain, llama-index и т.д.).
  - `scripts/ai/ai-chat` — простой CLI‑чат с локальным Ollama.
  - `scripts/ai/setup-comfyui.sh` — установка ComfyUI.
  - `scripts/ai/start-sd.sh` — запуск Stable Diffusion через ComfyUI.

- Сборка:
  - `scripts/build-iso.sh` — каркас скрипта сборки ISO (пока без реализации).

---

### Git / GitHub

Репозиторий подготовлен к инициализации в Git:

- `.gitignore` настроен под типичные артефакты (venv, node_modules, образы ISO и т.п.).
- Workflow `build-iso` собирает ISO в черновом виде, вызывая `scripts/build-iso.sh`.

Следующие шаги:

1. Выполнить `git init` в корне проекта.
2. Добавить удалённый репозиторий на GitHub (`git remote add origin ...`).
3. Создать первый коммит с текущей структурой.

