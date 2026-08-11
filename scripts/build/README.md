# VibeLinux — Скрипты сборки ISO

Эта папка содержит готовые скрипты для сборки ISO-образов VibeLinux.

## 📁 Структура

- `scripts/legacy/build-vibe-lite-ubuntu.sh` — **Lite-версия (legacy)** (Ubuntu 24.04, минимальный набор: CLI + Neovim + базовые утилиты)
- `scripts/legacy/build-vibe-full-ubuntu.sh` — **Full-версия (legacy)** (Ubuntu 24.04, все редакторы, AI-агенты, языки, инструменты)
- `scripts/build/build-vibe-arch.sh` — **Arch Linux (основная)** (rolling release, полный набор)

> ⚠️ **Ubuntu-сборки переведены в legacy** и лежат в `scripts/legacy/`. Основная линия — Arch Linux (`build-vibe-arch.sh`, профиль `archiso-vibelinux/`).

## 🚀 Использование

### Быстрый старт

```bash
# Lite-сборка (legacy, только базовое)
sudo bash scripts/legacy/build-vibe-lite-ubuntu.sh

# Full-сборка (legacy, все инструменты)
sudo bash scripts/legacy/build-vibe-full-ubuntu.sh

# Arch Linux сборка (основная)
sudo bash scripts/build/build-vibe-arch.sh
```

### Через Makefile

```bash
make lite        # Lite-сборка (legacy)
make full-vibe   # Full-сборка (legacy)
make arch        # Arch Linux (основная)
```

## 🔧 Требования

- **Root/sudo** доступ
- **25-50 ГБ** свободного места
- **Быстрый интернет** (загрузка пакетов)
- **Linux-хост** (Ubuntu 24.04 / Debian 13 / Arch / Fedora)

### Зависимости (устанавливаются автоматически)

- `debootstrap` (для Ubuntu/Debian)
- `arch-install-scripts` (для Arch)
- `squashfs-tools`
- `xorriso`
- `grub-common`, `grub-pc-bin`, `grub-efi-amd64-bin`
- `mtools`, `dosfstools`

## 📦 Что включено

### Lite-версия
- ✅ Zsh + Oh My Zsh + Starship
- ✅ Python 3 (системный)
- ✅ Neovim
- ✅ Git, curl, wget, jq, fzf, ripgrep, tmux
- ✅ Flatpak поддержка
- ✅ Vibe Wizard (пост-установочный мастер)

### Full-версия
- ✅ **Всё из Lite**
- ✅ Node.js LTS (через fnm)
- ✅ Bun, Deno
- ✅ Rust (через rustup)
- ✅ Go 1.22
- ✅ VS Code, Zed, Helix
- ✅ Ollama (локальные LLM)
- ✅ Aider (AI-ассистент)
- ✅ Docker

### Arch Linux
- ✅ Rolling release (всегда свежие пакеты)
- ✅ Полный набор инструментов
- ✅ Pacman менеджер

## 🎯 Архитектура

Каждый скрипт выполняет следующие шаги:

1. **Установка зависимостей** на хост-машине
2. **Bootstrap** базовой системы (debootstrap/pacstrap)
3. **Chroot кастомизация** (установка пакетов, настройка пользователя)
4. **Сборка SquashFS** из chroot
5. **Создание ISO** с GRUB загрузчиком (BIOS + UEFI)

## 📝 Конфигурация

Скрипты используют шаблон конфигурации из `scripts/base/vibe-config-template.json`.

Для генерации кастомного скрипта из конфига:

```bash
# Отредактируйте конфиг
nano scripts/base/vibe-config-template.json

# Сгенерируйте скрипт
make generate

# Запустите
sudo bash scripts/build/build-vibe-generated.sh
```

## 🧙 Vibe Wizard

После установки ISO в live-режиме автоматически запускается **Vibe Wizard** — пост-установочный мастер, который позволяет доустановить нужные компоненты.

Wizard поддерживает три режима:
- **GUI** (zenity) — в графической сессии
- **TUI** (whiptail) — в терминале
- **CLI** — текстовый режим

## 🐛 Отладка

Логи сборки:
- `workdir/chroot/root/build.log` — лог chroot кастомизации
- `/tmp/vibe-wizard.log` — лог пост-установочного мастера

## 📄 Лицензия

MIT — используйте свободно, модифицируйте под свои задачи.
