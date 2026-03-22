# VibeCode OS — Две редакции

Этот документ описывает различия между двумя редакциями VibeCode OS.

---

## 📦 Редакции

### VibeCode OS Minimal
**Минимальная консольная система**

```
┌─────────────────────────────────────────────┐
│  VibeCode OS Minimal                        │
│  ─────────────────────────                  │
│  • Текстовый установщик                     │
│  • Только CLI (без GUI)                     │
│  • Базовые утилиты (htop, mc, git, zsh)     │
│  • MC (Midnight Commander)                  │
│  • Скрипт доустановки vibecode-upgrade      │
│                                              │
│  Размер ISO: ~500 МБ - 1 ГБ                 │
│  Размер после установки: ~2-3 ГБ            │
└─────────────────────────────────────────────┘
```

**Для кого:**
- Серверные развёртывания
- Контейнеризация (Docker-хосты)
- Опытные пользователи, желающие настроить систему с нуля
- Виртуальные машины с ограниченными ресурсами

**Состав:**
- Ubuntu 24.04 LTS (база)
- Ядро: linux-image-generic, linux-headers-generic
- Консольные утилиты: htop, mc, nano, vim-tiny, tmux, zsh
- Сеть: curl, wget, git, NetworkManager
- Архиваторы: unzip, zip, p7zip-full
- Live-поддержка: casper, squashfs-tools
- **Скрипт доустановки:** `/usr/local/bin/vibecode-upgrade`

---

### VibeCode OS Full
**Полноценная рабочая среда для разработки**

```
┌─────────────────────────────────────────────┐
│  VibeCode OS Full                           │
│  ──────────────────                         │
│  • Графический установщик (Ubiquity)        │
│  • MATE Desktop Environment                 │
│  • Полный Dev-стек из коробки               │
│  • AI-инструменты (Ollama, Open WebUI)      │
│  • VSCodium, Neovim, Zed                    │
│  • Python, Node.js, Rust, Go, Java          │
│  • Docker, lazygit                          │
│  • Брендинг VibeCode OS                     │
│                                              │
│  Размер ISO: ~3-4 ГБ                        │
│  Размер после установки: ~15-20 ГБ          │
└─────────────────────────────────────────────┘
```

**Для кого:**
- Разработчики всех уровней
- AI-энтузиасты и исследователи
- Студенты и начинающие разработчики
- Любители keyboard-driven интерфейсов

**Состав:**
- Всё из Minimal +
- MATE Desktop Environment
- LightDM (дисплей-менеджер)
- Kitty (GPU-ускоренный терминал)
- Zsh + Oh My Zsh + Starship
- CLI-утилиты (eza, bat, fd, rg, fzf, zoxide, btop)
- Языки: Python, Node.js, Rust, Go, Java
- Редакторы: VSCodium, Neovim (AstroNvim), Zed
- Инструменты: Git, lazygit, Docker
- AI-стек: Ollama, Open WebUI, ai-chat, Aider, ComfyUI
- Python AI-библиотеки (PyTorch, Transformers, LangChain)
- Шрифты: JetBrains Mono, Fira Code, Cascadia Code
- Брендинг: темы, обои, иконки, Plymouth

---

## 🔄 Доустановка (Minimal → Full)

Если вы установили **Minimal** версию, вы можете доустановить компоненты до **Full**:

```bash
# Запуск мастера доустановки
sudo vibecode-upgrade
```

### Категории для установки

| № | Категория | Размер | Что включает |
|---|-----------|--------|--------------|
| 1 | Терминал и оболочка | ~200 МБ | Kitty, Zsh, Oh My Zsh, Starship, CLI-утилиты |
| 2 | Языки программирования | ~1-2 ГБ | Python, Node.js, Rust, Go, Java |
| 3 | Редакторы и IDE | ~500 МБ - 1 ГБ | VSCodium, Neovim, Zed |
| 4 | Инструменты разработчика | ~500 МБ | Git, lazygit, Docker |
| 5 | AI-стек | ~10-20 ГБ | Ollama, Open WebUI, ai-chat, Aider, ComfyUI, Python AI |
| 6 | Драйверы NVIDIA | ~1 ГБ | Проприетарные драйверы |

### Быстрая доустановка

Установить всё сразу (аналог Full версии):

```bash
sudo vibecode-upgrade
# Выбрать: A (установить всё)
```

---

## 📊 Сравнение редакций

| Компонент | Minimal | Full |
|-----------|---------|------|
| **GUI (MATE Desktop)** | ❌ | ✅ |
| **Kitty терминал** | ❌ | ✅ |
| **Zsh + Oh My Zsh** | ✅ | ✅ |
| **Starship** | ❌ | ✅ |
| **CLI-утилиты (eza, bat, fd, rg...)** | ❌ | ✅ |
| **Python + pyenv** | ❌ | ✅ |
| **Node.js + nvm** | ❌ | ✅ |
| **Rust + rustup** | ❌ | ✅ |
| **Go** | ❌ | ✅ |
| **Java + SDKMAN!** | ❌ | ✅ |
| **VSCodium** | ❌ | ✅ |
| **Neovim** | ✅ (базовый) | ✅ (AstroNvim) |
| **Zed** | ❌ | ✅ |
| **Git** | ✅ | ✅ |
| **lazygit** | ❌ | ✅ |
| **Docker** | ❌ | ✅ |
| **Ollama** | ❌ | ✅ |
| **Open WebUI** | ❌ | ✅ |
| **ai-chat** | ❌ | ✅ |
| **Aider** | ❌ | ✅ |
| **ComfyUI** | ❌ | ✅ |
| **Python AI-библиотеки** | ❌ | ✅ |
| **Шрифты (JetBrains Mono...)** | ❌ | ✅ |
| **MC (Midnight Commander)** | ✅ | ✅ |
| **Tmux** | ✅ | ✅ |
| **Скрипт vibecode-upgrade** | ✅ | ❌ (не нужен) |

---

## 🚀 Сценарии использования

### Сценарий 1: Сервер
**Выбор:** Minimal  
**Почему:** Минимальный размер, нет лишних компонентов, только базовые утилиты

### Сценарий 2: Разработка с нуля
**Выбор:** Minimal → Full (через vibecode-upgrade)  
**Почему:** Контроль над устанавливаемыми компонентами

### Сценарий 3: Рабочая станция
**Выбор:** Full  
**Почему:** Готовая среда разработки из коробки

### Сценарий 4: Виртуальная машина
**Выбор:** Minimal  
**Почему:** Меньше требований к ресурсам

### Сценарий 5: AI-разработка
**Выбор:** Full  
**Почему:** Все AI-инструменты предустановлены

---

## 📥 Сборка

### Minimal ISO

```bash
# Проверка
make check-mini

# Сборка
make mini

# Быстрая пересборка
make mini-keep
```

**Скрипт:** `scripts/build-minimal-iso.sh`

### Full ISO

```bash
# Проверка
make check

# Сборка
make full

# Быстрая пересборка
make full-keep
```

**Скрипт:** `scripts/build-iso.sh`

---

## 📚 Документация

- [PACKAGES.md](PACKAGES.md) — полный список пакетов
- [MINIMAL-UPGRADE.md](docs/MINIMAL-UPGRADE.md) — мастер доустановки (из системы)
- [UPGRADE-MINIMAL.md](docs/UPGRADE-MINIMAL.md) — мастер доустановки (из репозитория)
- [DEVSTACK.md](docs/DEVSTACK.md) — dev-стек
- [AI-STACK.md](docs/AI-STACK.md) — AI-стек
