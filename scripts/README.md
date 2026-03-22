# Скрипты VibeCode OS

Каталог `scripts/` содержит автоматизацию для:

- сборки базовой системы и ISO‑образов,
- установки и настройки dev‑стека,
- настройки AI‑стека,
- утилитарных задач (очистка системы, установка тем и т.д.).

---

## 📂 Структура

| Каталог | Назначение |
|---------|------------|
| `base/` | Базовые пакеты, cleanup, системные настройки |
| `desktop/` | Установка и настройка MATE и графического стека |
| `drivers/` | Установка проприетарных драйверов (NVIDIA) |
| `dev/` | Языки, IDE, терминал, Docker, Git‑инструменты |
| `ai/` | Ollama, GUI‑клиенты, терминальные и редакторные интеграции |

---

## 🚀 Быстрый старт

### Сборка ISO (через Makefile)

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

### Сборка ISO (вручную)

```bash
# Полная версия
sudo BUILD_MODE=full ./scripts/build-iso.sh
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-iso.sh  # Быстрая пересборка

# Минимальная версия
sudo BUILD_MODE=full ./scripts/build-minimal-iso.sh
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-minimal-iso.sh
```

### Установка на хост-систему

```bash
# Dev-стек
sudo ./scripts/dev/setup-dev-env.sh

# AI-стек
sudo ./scripts/ai/setup-ai-stack.sh
```

---

## 📦 Скрипты

### Сборка ISO

| Скрипт | Назначение |
|--------|------------|
| `build-iso.sh` | Сборка полной версии (с GUI) |
| `build-minimal-iso.sh` | Сборка минимальной версии (CLI) |
| `verify-build.sh` | Проверка сборки |

### Доустановка (Minimal → Full)

| Скрипт | Назначение |
|--------|------------|
| `minimal-upgrade.sh` | **Мастер доустановки из установленной системы** |
| | Доступен как `vibecode-upgrade` после установки |

### База (`base/`)

| Скрипт | Назначение |
|--------|------------|
| `base-packages.sh` | Базовые утилиты (htop, curl, wget, git, build-essential) |
| `minimal-packages.sh` | Минимальный набор для CLI-версии |
| `setup-distro-info.sh` | Брендинг системы |
| `setup-bootloader.sh` | GRUB и Plymouth |
| `cleanup.sh` | Очистка системы |

### Desktop (`desktop/`)

| Скрипт | Назначение |
|--------|------------|
| `install-mate.sh` | Установка MATE Desktop |
| `configure-mate-panel.sh` | Настройка панели MATE |
| `setup-installer.sh` | Установка Ubiquity (установщик) |
| `apply-branding.sh` | Применение брендинга |

### Dev-стек (`dev/`)

| Скрипт | Назначение |
|--------|------------|
| `setup-dev-env.sh` | Полная установка dev-окружения |
| `setup-shell.sh` | Zsh + Oh My Zsh + Starship + CLI-утилиты |
| `setup-terminal.sh` | Kitty + шрифты |
| `setup-langs.sh` | Python, Node.js, Rust, Go, Java |
| `setup-editors.sh` | VSCodium, Neovim, Zed |
| `setup-devtools.sh` | Git, Docker, lazygit |
| `setup-vscodium.sh` | Настройка VSCodium |

**Утилиты (`dev/utils/`):**
- `check-install.sh` — проверка установки компонентов
- `validate-env.sh` — валидация dev-среды
- `install-vscodium-extensions.sh` — установка расширений VSCodium

**Конфигурации (`dev/configs/`):**
- `.zshrc` — настройки Zsh
- `starship.toml` — настройки промпта
- `kitty.conf` — настройки терминала
- `vscodium-extensions.txt` — список расширений
- `vscodium-settings.json` — настройки VSCodium

### AI-стек (`ai/`)

| Скрипт | Назначение |
|--------|------------|
| `setup-ai-stack.sh` | Полная установка AI-стека |
| `install-ollama.sh` | Ollama (локальные LLM) |
| `install-ollama-models.sh` | Загрузка моделей (llama3.2, codellama, qwen2.5-coder) |
| `install-open-webui.sh` | Open WebUI (веб-интерфейс) |
| `setup-python-ai-stack.sh` | Python AI-библиотеки (PyTorch, Transformers, LangChain) |
| `setup-comfyui.sh` | ComfyUI (генерация изображений) |
| `start-sd.sh` | Запуск ComfyUI |
| `ai-chat` | Терминальный AI-чат |
| `install-aider.sh` | Aider (AI-парное программирование) |
| `install-openai-cli.sh` | OpenAI CLI (опционально) |
| `install-github-copilot-cli.sh` | GitHub Copilot CLI (опционально) |
| `install-terminal-ai.sh` | Терминальные AI-утилиты |

### Драйверы (`drivers/`)

| Скрипт | Назначение |
|--------|------------|
| `install-nvidia.sh` | Установка проприетарных драйверов NVIDIA |

---

## 📝 Примечания

1. **Режимы сборки:**
   - `dry-run` — проверка зависимостей без реальной сборки
   - `full` — полноценная сборка ISO

2. **Оптимизация повторной сборки:**
   - Используйте `KEEP_CHROOT=1` или `make full-keep` / `make mini-keep`
   - Это сохраняет chroot-окружение и пропускает этап bootstrap

3. **Тестирование:**
   - В QEMU: `qemu-system-x86_64 -cdrom build/VibeCodeOS-alpha.iso -m 2048 -enable-kvm`
   - В VirtualBox: см. `docs/TESTING.md`

4. **Документация:**
   - Процесс сборки: `docs/BUILD-ISO.md`
   - Тестирование: `docs/TESTING.md`
   - Dev-стек: `docs/DEVSTACK.md`
   - AI-стек: `docs/AI-STACK.md`
