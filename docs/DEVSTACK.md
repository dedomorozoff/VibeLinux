### **Dev‑стек VibeCode OS**

Этот документ фиксирует целевой стек инструментов разработки и базовые принципы его установки/настройки. Реализация будет постепенно автоматизироваться скриптами в каталоге `scripts/`.

---

### **Терминал и оболочка**

- **Терминал по умолчанию:** `Kitty` (GPU‑ускоренный, быстрый, хорошо кастомизируется).
- **Оболочка:** `Zsh` с `Oh My Zsh` и промптом `Starship`.

План:

1. Скрипт `scripts/dev/setup-shell.sh`:
   - Устанавливает Zsh, Oh My Zsh, Starship.
   - Кладёт базовый `.zshrc` и подключает Starship.
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
  - Темы (Catppuccin, Tokyo Night, Kilo Code)
  - Continue (для AI-интеграции)

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

