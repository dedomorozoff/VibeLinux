### VibeCode OS (черновой README)

**VibeCode OS** — дистрибутив Linux для «вайбкодинга» и AI‑разработки из коробки.  
Более подробный стратегический план см. в `roadmap.md` и `PROJECT_OVERVIEW.md`.

---

### Быстрый обзор структуры

- `PROJECT_OVERVIEW.md` — миссия, ЦА и ключевые решения.
- `BRANDING.md` — брендинг, цвета, шрифты, UX‑принципы.
- `AGENTS.md` — ожидания от AI‑агента при работе над проектом.
- `docs/DEVSTACK.md` — dev‑стек (языки, IDE, терминал, Docker и т.д.).
- `docs/AI-STACK.md` — AI‑стек (Ollama, GUI, терминал, редакторы, SD).
- `scripts/` — скрипты настройки и сборки (черновые).
- `.github/workflows/build-iso.yml` — CI для сборки ISO (черновой).

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
  - `scripts/build/build-iso.sh` — каркас скрипта сборки ISO (пока без реализации).

---

### Git / GitHub

Репозиторий подготовлен к инициализации в Git:

- `.gitignore` настроен под типичные артефакты (venv, node_modules, образы ISO и т.п.).
- Workflow `build-iso` собирает ISO в черновом виде, вызывая `scripts/build/build-iso.sh`.

Следующие шаги:

1. Выполнить `git init` в корне проекта.
2. Добавить удалённый репозиторий на GitHub (`git remote add origin ...`).
3. Создать первый коммит с текущей структурой.

