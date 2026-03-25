### **Dev‑стек VibeCode OS**

Этот документ фиксирует целевой стек инструментов разработки и базовые принципы его установки/настройки. Реализация будет постепенно автоматизироваться скриптами в каталоге `scripts/`.

**⚡ Полный список программ см. также в [`PACKAGES.md`](../PACKAGES.md).**

---

### **Терминал, оболочка и CLI-утилиты**

- **Терминал по умолчанию:** `Kitty` (GPU‑ускоренный, быстрый, хорошо кастомизируется).
- **Оболочка:** `Zsh` с `Oh My Zsh` и промптом `Starship`.
- **Современный CLI-инструментарий:**
  - `eza` — современная замена `ls` (с иконками и цветами)
  - `bat` — современная замена `cat` (подсветка синтаксиса, интеграция с Git)
  - `fd` — быстрая альтернатива `find`
  - `ripgrep` (`rg`) — невероятно быстрый поиск текста (замена `grep`)
  - `fzf` — нечеткий поиск (fuzzy finder) для истории, файлов и процессов
  - `zoxide` — умный переход по каталогам (`z` вместо `cd`)
  - `btop` — стильный и функциональный монитор ресурсов

План:

1. Скрипт `scripts/dev/setup-shell.sh`:
   - Устанавливает Zsh, Oh My Zsh, Starship.
   - Устанавливает CLI-утилиты: `eza`, `bat`, `fd-find`, `ripgrep`, `fzf`, `zoxide`, `btop`.
   - Кладёт базовый `.zshrc` и подключает Starship + плагины.
   - Настраивает алиасы для новых утилит.
   - Копирует конфиги из `scripts/dev/configs/`.
2. Скрипт `scripts/dev/setup-terminal.sh`:
   - Устанавливает Kitty.
   - Копирует конфиги в `~/.config/kitty`.
   - Устанавливает шрифты для кодинга (JetBrains Mono, Fira Code, Cascadia Code).

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
- Базовые расширения (автоматически устанавливаются):
  - GitLens, Docker, Python, ESLint/Prettier, Rust, Go
  - Темы (Catppuccin, Tokyo Night по умолчанию)
  - AI-инструменты (Kilo Code, Continue, Aider, GitHub Copilot, Ollama)

**Neovim + AstroNvim**

- Современный Vim с LSP из коробки
- AstroNvim — готовая конфигурация с плагинами
- Автодополнение, статусбар, файловый менеджер

**Zed**

- Быстрый современный редактор
- Установка через официальный скрипт
- Фокус на скорость и коллаборацию

Скрипт `scripts/dev/setup-editors.sh` устанавливает все три редактора и расширения VSCodium.

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

---

### **Интеграция в build-iso.sh**

Фаза 2 автоматически интегрируется в сборку ISO через `scripts/build-iso.sh`:

1. **Автоматическая установка** — скрипты копируются в chroot и выполняются по порядку
2. **Автоматическая интеграция** — dev-конфигы копируются в chroot перед установкой
3. **Автоматическая установка** — запускается после установки MATE и до настройки autologin

Скрипты для сборки на хост-системе:
```bash
sudo ./scripts/dev/setup-dev-env.sh  # Для локальной среды
```

---

### **Утилиты**

**check-install.sh** — проверка установки компонентов:
```bash
sudo ./scripts/dev/utils/check-install.sh
```

**validate-env.sh** — валидация dev-среды:
```bash
sudo ./scripts/dev/utils/validate-env.sh
```

**install-vscodium-extensions.sh** — установка расширений VSCodium:
```bash
sudo ./scripts/dev/utils/install-vscodium-extensions.sh
```

---

### **Конфигурация**

Конфиги находятся в `scripts/dev/configs/`:

- `.zshrc` — настройки Zsh с инициализацией всех менеджеров версий
- `starship.toml` — настройки промпта
- `kitty.conf` — настройки терминала
- `vscodium-extensions.txt` — список расширений VSCodium
- `vscodium-settings.json` — настройки VSCodium с темой Kilo Code по умолчанию

Конфиги для chroot (автоматические):
- `kitty.conf` — копируется в `/root/.config/kitty/`
- `vscodium-settings.json` — копируется в `/root/.config/codium/User/`
- `vscodium-extensions.txt` — копируется в `/root/configs/`

---

### **Troubleshooting**

**Проблема:** Zsh не запускается

**Решение:** Убедитесь, что Zsh установлен и установлен как shell по умолчанию:
```bash
chsh -s $(which zsh)
```

**Проблема:** Starship не отображается

**Решение:** Убедитесь, что Starship установлен и добавлен в `.zshrc`:
```bash
eval "$(starship init zsh)"
```

**Проблема:** Docker не запускается

**Решение:** Добавьте пользователя в группу docker и перезапустите сервис:
```bash
sudo usermod -aG docker $USER
sudo systemctl restart docker
```

**Проблема:** Расширения VSCodium не устанавливаются

**Решение:** Запустите скрипт установки вручную:
```bash
sudo ./scripts/dev/utils/install-vscodium-extensions.sh
```

