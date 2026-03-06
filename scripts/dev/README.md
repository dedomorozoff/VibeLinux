# Dev-стек VibeCode OS

Скрипты для установки и настройки инструментов разработки.

## Структура

```
scripts/dev/
├── setup-dev-env.sh          # Главный агрегирующий скрипт
├── setup-shell.sh            # Zsh + Oh My Zsh + Starship
├── setup-terminal.sh         # Kitty
├── setup-langs.sh            # Менеджеры версий и языки
├── setup-devtools.sh         # Git, Docker, lazygit
├── setup-editors.sh          # VSCodium, Neovim, Zed
├── configs/                  # Конфигурационные файлы
│   ├── zshrc.template        # Шаблон .zshrc
│   ├── starship.toml         # Конфиг Starship
│   ├── kitty.conf            # Конфиг Kitty
│   └── vscodium-extensions.txt  # Список расширений VSCodium
├── utils/                    # Утилиты
│   ├── check-install.sh      # Проверка установки компонентов
│   ├── validate-env.sh       # Валидация dev-среды
│   └── install-vscodium-extensions.sh  # Установка расширений VSCodium
└── README.md                 # Документация
```

## Использование

### Полная установка

```bash
sudo ./scripts/dev/setup-dev-env.sh
```

### Частичная установка

```bash
# Только оболочка
sudo ./scripts/dev/setup-shell.sh

# Только терминал
sudo ./scripts/dev/setup-terminal.sh

# Только языки
sudo ./scripts/dev/setup-langs.sh

# Только dev-инструменты
sudo ./scripts/dev/setup-devtools.sh

# Только редакторы
sudo ./scripts/dev/setup-editors.sh
```

### Проверка и валидация

```bash
# Проверка установки компонентов
sudo ./scripts/dev/utils/check-install.sh

# Валидация dev-среды
sudo ./scripts/dev/utils/validate-env.sh
```

## Установленные компоненты

### Оболочка и терминал

- **Zsh** — современная оболочка
- **Oh My Zsh** — фреймворк для Zsh
- **Starship** — промпт для Zsh
- **Kitty** — GPU-ускоренный терминал

### Языки и менеджеры версий

- **Python** — pyenv + версии 3.11.11, 3.12.8
- **Node.js** — nvm + LTS и latest
- **Rust** — rustup + stable
- **Go** — из репозитория Ubuntu
- **Java** — SDKMAN! + Java 21 LTS (Temurin)

### Редакторы и IDE

- **VSCodium** — Open Source VS Code
- **Neovim** — с AstroNvim
- **Zed** — быстрый GUI-редактор

### Dev-инструменты

- **Git** — система контроля версий
- **lazygit** — TUI для Git
- **Docker** — контейнеризация
- **Docker Compose** — оркестрация контейнеров

## Конфигурация

Конфиги находятся в `configs/`:

- `.zshrc` — настройки Zsh
- `starship.toml` — настройки промпта
- `kitty.conf` — настройки терминала
- `vscodium-extensions.txt` — список расширений

## Troubleshooting

### Проблема: Zsh не запускается

**Решение:** Убедитесь, что Zsh установлен и установлен как shell по умолчанию:
```bash
chsh -s $(which zsh)
```

### Проблема: Starship не отображается

**Решение:** Убедитесь, что Starship установлен и добавлен в `.zshrc`:
```bash
eval "$(starship init zsh)"
```

### Проблема: Docker не запускается

**Решение:** Добавьте пользователя в группу docker и перезапустите сервис:
```bash
sudo usermod -aG docker $USER
sudo systemctl restart docker
```

### Проблема: Расширения VSCodium не устанавливаются

**Решение:** Запустите скрипт установки вручную:
```bash
sudo ./scripts/dev/utils/install-vscodium-extensions.sh
```

## Разработка

### Добавление нового компонента

1. Создайте скрипт в `scripts/dev/`
2. Добавьте вызов в `setup-dev-env.sh`
3. Добавьте конфиги в `configs/` если нужно
4. Обновите документацию

### Добавление нового расширения VSCodium

Добавьте ID расширения в `configs/vscodium-extensions.txt`:
```
author.extension-name
```

## Лицензия

MIT
