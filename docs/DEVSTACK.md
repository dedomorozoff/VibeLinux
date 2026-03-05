### **Dev‑стек VibeCode OS (черновик)**

Этот документ фиксирует целевой стек инструментов разработки и базовые принципы его установки/настройки. Реализация будет постепенно автоматизироваться скриптами в каталоге `scripts/`.

---

### **Терминал и оболочка**

- **Терминал по умолчанию:** `Kitty` (GPU‑ускоренный, быстрый, хорошо кастомизируется).
- **Оболочка:** `Zsh` с `Oh My Zsh` и промптом `Starship`.

План:

1. Скрипт `scripts/dev/setup-shell.sh`:
   - Устанавливает Zsh, Oh My Zsh, Starship.
   - Кладёт базовый `.zshrc` и подключает Starship.
2. Скрипт `scripts/dev/setup-terminal.sh`:
   - Устанавливает Kitty.
   - (в будущем) копирует базовые конфиги в `~/.config/kitty`.

---

### **Языки и менеджеры версий**

- **Python:** `pyenv` + версии 3.11.11, 3.12.8 (по умолчанию 3.12.8)
- **Node.js:** `nvm` (v0.40.4) + LTS и latest версии
- **Rust:** `rustup` (стабильный toolchain)
- **Go:** из репозитория Ubuntu
- **Java/Kotlin:** `SDKMAN!` + Java 21 LTS (Temurin)

Скрипт `scripts/dev/setup-langs.sh`:
- Устанавливает менеджеры версий
- Ставит базовые версии языков
- Добавляет инициализацию в shell-конфиги

---

### **Редакторы и IDE**

**VSCodium**

- Open Source аналог VS Code
- Установка через официальный репозиторий
- Базовые расширения (добавятся позже):
  - GitLens, Docker, Python, ESLint/Prettier, Rust, Go

**Neovim + AstroNvim**

- Современный Vim с LSP из коробки
- AstroNvim — готовая конфигурация с плагинами
- Автодополнение, статусбар, файловый менеджер

**Zed**

- Быстрый современный редактор
- Установка через официальный скрипт
- Фокус на скорость и коллаборацию

Скрипт `scripts/dev/setup-editors.sh` устанавливает все три редактора.

---

### **Контроль версий и контейнеры**

- **Git** — из репозитория Ubuntu
- **lazygit** — TUI-клиент для Git
- **Docker** и **Docker Compose** — контейнеризация

Скрипт `scripts/dev/setup-devtools.sh`:
- Устанавливает Git, lazygit, Docker
- Добавляет пользователя в группу docker
- Проверяет работу Docker через hello-world

---

### **Автоматизация**

Полная настройка dev-среды одной командой:

```bash
sudo ./scripts/dev/setup-dev-env.sh
```

Агрегирует все скрипты:
- `setup-shell.sh` — Zsh + Oh My Zsh + Starship
- `setup-terminal.sh` — Kitty
- `setup-langs.sh` — Python, Node.js, Rust, Go, Java
- `setup-devtools.sh` — Git, Docker, lazygit
- `setup-editors.sh` — VSCodium, Neovim, Zed

Можно запускать скрипты по отдельности для частичной настройки.

