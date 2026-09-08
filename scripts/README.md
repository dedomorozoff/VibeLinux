# Скрипты VibeCode OS

Каталог `scripts/` содержит автоматизацию для:

- сборки ISO‑образов (основная линия — Arch Linux + KDE Plasma 6, Ubuntu — legacy),
- установки и настройки dev‑стека,
- настройки AI‑стека,
- утилитарных задач (очистка системы, установка тем и т.д.).

---

## 📂 Структура

| Каталог | Назначение |
|---------|------------|
| `build/` | Основная линия сборки: Arch Linux (`build-vibe-arch.sh`, `install-vibelinux-arch.sh`, `prepare-aur.sh`) |
| `legacy/` | **Ubuntu-редакции** (Full / Minimal / Lite): сборка ISO, пакетные и DE-скрипты |
| `base/` | Общие утилиты: `generate-build-script.sh`, `vibe-wizard.sh`, `vibe-config-template.json` |
| `drivers/` | Установка проприетарных драйверов (NVIDIA) |
| `dev/` | Языки, IDE, терминал, Docker, Git‑инструменты |
| `ai/` | Ollama, GUI‑клиенты, терминальные и редакторные интеграции |
| `archive/` | Мёртвый код (не поддерживается, для истории) |

---

## 🚀 Быстрый старт

### Сборка ISO (через Makefile)

```bash
# Основная сборка (Arch Linux + KDE Plasma 6)
make arch

# Legacy: Ubuntu-редакции
make legacy-full        # Full (KDE Plasma + dev + AI)
make legacy-mini        # Minimal (только CLI)
make legacy-lite        # Lite (CLI + базовые инструменты)

# Быстрая пересборка (сохраняет chroot, legacy Ubuntu)
make legacy-full-keep
make legacy-mini-keep

# Проверка зависимостей (legacy Ubuntu)
make legacy-check
make legacy-check-mini

# Очистка
make clean
```

### Сборка ISO (вручную)

```bash
# Основная: Arch Linux
sudo bash scripts/build/build-vibe-arch.sh

# Legacy: Ubuntu Full
sudo BUILD_MODE=full ./scripts/legacy/build-iso.sh
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/legacy/build-iso.sh  # Быстрая пересборка

# Legacy: Ubuntu Minimal
sudo BUILD_MODE=full ./scripts/legacy/build-minimal-iso.sh
sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/legacy/build-minimal-iso.sh
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

### Сборка ISO (`build/` — основная линия)

| Скрипт | Назначение |
|--------|------------|
| `build-vibe-arch.sh` | **Arch Linux + KDE Plasma 6** (основная сборка) |
| `install-vibelinux-arch.sh` | Установка VibeLinux на хост Arch |
| `prepare-aur.sh` | Подготовка AUR |

### Legacy (`legacy/` — Ubuntu-редакции)

| Скрипт | Назначение |
|--------|------------|
| `build-iso.sh` | Сборка Full (Ubuntu) |
| `build-minimal-iso.sh` | Сборка Minimal (Ubuntu, CLI) |
| `verify-build.sh` | Проверка содержимого собранного chroot |
| `minimal-upgrade.sh` | **Мастер доустановки** (доступен как `vibecode-upgrade`) |
| `base/` | Пакетные скрипты (apt): base/minimal/full-packages, cleanup, bootloader, distro-info |
| `desktop/` | DE-скрипты: `install-kde.sh`, `configure-kde.sh`, `install-i3wm.sh`, `install-hyprland.sh`, `setup-installer.sh`, `apply-branding.sh`, `configs/` |
| `build/` | `build-vibe-full-ubuntu.sh`, `build-vibe-lite-ubuntu.sh` |

### База (`base/`)

| Скрипт | Назначение |
|--------|------------|
| `generate-build-script.sh` | Генератор скрипта сборки из JSON-конфига |
| `vibe-wizard.sh` | Пост-установочный мастер (GUI/TUI/CLI) |
| `vibe-config-template.json` | Шаблон конфигурации для генератора |

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
| `install-openai-cli.sh` | OpenAI CLI (опционально) |
| `install-github-copilot-cli.sh` | GitHub Copilot CLI (опционально) |
| `install-codex-cli.sh` | OpenAI Codex CLI (опционально) |
| `install-claude-code.sh` | Claude Code (опционально) |
| `install-qwen-code.sh` | Qwen Code (опционально) |
| `install-crush.sh` | Crush — AI coding agent (опционально) |
| `install-kimi.sh` | Kimi Code CLI (опционально) |
| `install-terminal-ai.sh` | Терминальные AI-утилиты |

### Драйверы (`drivers/`)

| Скрипт | Назначение |
|--------|------------|
| `install-nvidia.sh` | Установка проприетарных драйверов NVIDIA (pacman/apt) |

---

## 📝 Примечания

1. **Режимы сборки (legacy Ubuntu):**
   - `dry-run` — проверка зависимостей без реальной сборки
   - `full` — полноценная сборка ISO

2. **Оптимизация повторной сборки:**
   - Используйте `KEEP_CHROOT=1` или `make legacy-full-keep` / `make legacy-mini-keep`
   - Это сохраняет chroot-окружение и пропускает этап bootstrap

3. **Тестирование:**
   - В QEMU: `qemu-system-x86_64 -cdrom build/VibeCodeOS-alpha.iso -m 2048 -enable-kvm`
   - В VirtualBox: см. `docs/TESTING.md`

4. **Документация:**
   - Процесс сборки: `docs/BUILD-ISO.md`
   - Тестирование: `docs/TESTING.md`
   - Dev-стек: `docs/DEVSTACK.md`
   - AI-стек: `docs/AI-STACK.md`
