# Changelog

## [Unreleased]

### Added
- **Arch ISO — AI-агенты предустановлены в образ** (решает проблему «AI не ставится в live-сессии»):
  - Все CLI-агенты запечены в squashfs на этапе сборки: opencode (pacman), qwen-code, Claude Code, Codex, Kilo, MiMo, Continue, Kimi (npm global), Crush (нативный бинарник из GitHub-релизов) — работают и в live, и на установленной системе, без root и без доустановки
  - `ollama` **намеренно не входит в ISO** (пакет ~500 МБ и всё равно нужен диск под модели) — ставится post-install: `install-ollama` / `ai-install`; systemd-сервис включается этим скриптом
  - `pipx` добавлен в `packages.x86_64`
  - Скрипты `scripts/ai/*` копируются в образ на `/opt/vibecode/scripts/ai` (`build-vibe-arch.sh`) — после установки на диск доступен `sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh`
- **Live-сессия осведомлена о RAM-оверлее:**
  - `ai-install` показывает статус предустановленных агентов, свободное место на `/` и направляет тяжёлые установки (ollama / WebUI / ComfyUI / Python-стек) на установленную систему
  - `install-ollama`, `ai-setup`, `setup-ai-stack.sh`, `install-ollama-models.sh` блокируются в live-сессии (корень — RAM) с понятным объяснением
  - `install-cursor` / `install-kiro` получили live-guard
- **VibeBSD (экспериментальная FreeBSD-редакция):** `freebsd-vibebsd/`
  - Пакетные списки base/desktop/dev/ai для FreeBSD pkg (проверены по FreshPorts)
  - Пайплайн сборки ISO на Poudriere (jail → кастомизация → `poudriere image -t iso`)
  - Кастомизация: брендинг, пользователь `vibebsd` (SDDM autologin), rc.conf (dbus/sddm/ollama)
  - Конфиги Zsh/Starship/Kitty, адаптированные под FreeBSD (`/usr/local`, Podman-алиасы)
  - Пост-установочный AI-стек без Docker (`uv`, Open WebUI, ComfyUI) — `scripts/setup-ai.sh`
  - Makefile-цели: `make bsd`, `bsd-setup`, `bsd-customize`, `bsd-build`
  - Документация: `freebsd-vibebsd/README.md`, `docs/VIBEBSD.md`, раздел в `roadmap.md`

### Changed
- **Основная редакция — Arch Linux + KDE Plasma 6:**
  - Профиль `archiso-vibelinux/` (`make arch`, `scripts/build/build-vibe-arch.sh`)
  - Ubuntu-редакции (Full / Minimal / Lite) переведены в статус legacy
  - Обновлена документация: `AGENTS.md`, `PROJECT_OVERVIEW.md`, `BUILD-INSTRUCTIONS.md`, `EDITIONS.md`, `PACKAGES.md`, `docs/`
- **nlsh берётся из GitHub-релизов** (`github.com/dedomorozoff/nlsh`, `releases/latest`)
  - Arch: `build-vibe-arch.sh` скачивает свежий `.pkg.tar.zst` (v0.2.5+) в airootfs,
    `customize_airootfs.sh` ставит его через `pacman -U` (логика не изменилась)
  - Ubuntu (legacy Full ISO): `.deb` из релиза ставится через `dpkg -i` в chroot
  - Офлайн-фолбэки сохранены: локальный пакет/бинарник из `soft/nlsh/`
    (иконка и .desktop по-прежнему только оттуда — в релизах их нет)

### Fixed
- **AI Launcher не запускался с рабочего стола (работал только из терминала):**
  - Причина: в ISO отсутствовал `kdialog` — лаунчер проваливался в терминальное
    select-меню, а при запуске с ярлыка stdin = /dev/null, select молча читал EOF
    и скрипт выходил, не показав ничего
  - `kdialog` добавлен в `packages.x86_64`
  - Лаунчер стал устойчивым: если диалога нет, а stdin — не TTY,
    он перезапускает сам себя в `konsole --hold` (меню видно в любом случае);
    «агенты не найдены» тоже показываются в терминале, а не пропадают
  - `Exec` в `AI-Launcher.desktop` переведён на абсолютный путь
    `/usr/local/bin/ai-launcher`
- **AI Launcher:** меню стало циклическим — после выхода агента возвращается
  к выбору, а не завершается (выход — «Выход» или Ctrl+D)
  - Агент запускается прямо в текущем терминале, без вложенного `konsole`
    (исчезает и предупреждение профиля из этого пути)
  - Запуск с ярлыка: kdialog-выбор → `konsole` с сразу запущенным агентом,
    после его выхода в том же окне открывается меню
  - Обработан EOF/Ctrl+D в меню (раньше был бы busy-loop на пустом stdin)
- **Konsole:** убран `Parent=FALLBACK` из `VibeLinux.profile` — Konsole писала
  «Profile "VibeLinux" has an invalid parent "FALLBACK"» при каждом запуске
- **Crush (EACCES):** отказались от npm-пакета `@charmland/crush` — при первом
  запуске он качает нативный бинарник в глобальный node_modules
  (`/usr/lib/node_modules`), и у обычного пользователя падает
  «permission denied, mkdir .../bin»
  - Теперь crush ставится напрямую из GitHub-релизов
    (`charmbracelet/crush`, статический Go-бинарник, node не нужен):
    в ISO на этапе сборки и в `scripts/ai/install-crush.sh` (post-install)
- **Arch ISO (mkinitcpio):** Убран хук `autodetect` из `mkinitcpio.conf` во всех местах
  - Помимо `airootfs/etc/mkinitcpio.conf`, исправлен heredoc, который
    `customize_airootfs.sh` принудительно перезаписывал с `autodetect`
    во время сборки (именно он реально попадал в initramfs — генерация
    происходит на этапе pacstrap, до копирования airootfs-оверлея профиля)
  - `autodetect` урезал модули под железо машины сборки: без оптического привода на хосте
    из initramfs выпадал `sr_mod`, и live-ISO не могло загрузиться с виртуального CD/DVD
    в VirtualBox
  - Теперь, как в официальном archiso (releng), в initramfs попадают все драйверы
- **Arch ISO (mkinitcpio):** `COMPRESSION_OPTIONS=(-19)` → `(-15)` для initramfs
  - Приведено в соответствие со squashfs-политикой профиля (`-15` в `profiledef.sh`)
  - Сборка initramfs быстрее, выигрыш в размере от `-19` минимален

### Added
- **Russian Language Support:** Полная поддержка русского языка во всей системе
  - Языковые пакеты: language-pack-ru, language-pack-gnome-ru, kde-l10n-ru
  - Локаль ru_RU.UTF-8 по умолчанию
  - Раскладка клавиатуры RU/US с переключением по Alt+Shift
  - Русская локаль в KDE Plasma, терминале и всех приложениях
  - Шрифты с поддержкой кириллицы (Noto CJK, Noto Color Emoji)
- **nlsh (Natural Language Shell):** Локальный AI-ассистент для управления системой
  - Бинарник из `soft/nlsh/` встроен в ISO
  - Ярлык на рабочем столе KDE Plasma
  - Команды: `nlsh ask`, `nlsh run`, `nlsh repl`, `nlsh info`
  - Работает с локальными LLM через llama.cpp (без облака)

### Fixed
- **Minimal ISO:** Убран параметр `init=/lib/systemd/systemd` из GRUB-конфига live-образа
  - Этот параметр конфликтовал с casper и вызывал kernel panic (`exitcode=0x00000100`)
  - Теперь casper сам управляет init-процессом через `/lib/casper/casper-init`
- **Minimal ISO:** Добавлен режим отладки (Debug mode) в GRUB
  - Включает подробное логирование systemd для диагностики
- **Minimal ISO:** Обновлены зависимости в minimal-packages.sh
  - `live-tools` → `live-config`, `live-config-doc` (актуально для Ubuntu 24.04)
  - Добавлен `squashfs-tools` для работы с SquashFS

### Added
- **Docs:** Создан `docs/MINIMAL-DEBUG.md` — полное руководство по отладке kernel panic
  - Диагностика причин и решений
  - Чек-лист перед сборкой
  - Команды для проверки chroot и ISO
  - Примеры запуска в QEMU с отладочными параметрами

**Core OS:**
- Настройка GRUB и Plymouth с брендингом VibeCode OS
- Скрипт `setup-bootloader.sh` для кастомизации загрузчика
- Базовая система на Ubuntu 24.04 LTS + KDE Plasma (legacy-редакция)

**Dev Stack:**
- Полная установка dev-окружения через `setup-dev-env.sh`
- Zsh + Oh My Zsh + Starship
- Kitty терминал
- Языки: Python (pyenv 3.11/3.12), Node.js (nvm v0.40.4), Rust, Go, Java 21 LTS
- Редакторы: VSCodium, Neovim (AstroNvim), Zed
- Docker, Git, lazygit

**AI Stack:**
- Ollama для локальных LLM
- Open WebUI (веб-интерфейс на порту 3000)
- ai-chat — интерактивный терминальный чат
- Python AI окружение: PyTorch, Transformers, LangChain, LlamaIndex
- ComfyUI для Stable Diffusion
- Модели: llama3.2, codellama, qwen2.5-coder
- Агрегирующий скрипт `setup-ai-stack.sh`

**Documentation:**
- Обновлён DEVSTACK.md с конкретными версиями
- Обновлён AI-STACK.md с требованиями по ресурсам
- README для scripts/ai
- Обновлён главный README.md
- **NEW:** DEBUG-LIVE-ISO.md — руководство по отладке kernel panic

### Changed
- nvm обновлён до v0.40.4
- Модели Ollama обновлены до актуальных версий
- ai-chat получил интерактивный режим с командами

### Fixed

**Critical: Kernel Panic Fix (commit 2026-03-26)**

Исправлена критическая ошибка "Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000100":

1. **scripts/base/base-packages.sh:**
   - ✅ Добавлены пакеты `systemd` и `systemd-sysv` (явное указание)
   - ✅ Добавлен `live-tools` для live-сессии

2. **scripts/base/minimal-packages.sh:**
   - ✅ Добавлены пакеты `systemd` и `live-tools`

3. **scripts/build-iso.sh:**
   - ✅ Добавлен параметр `init=/lib/systemd/systemd` в GRUB конфигурацию (все menuentry)
   - ✅ Добавлена проверка systemd и `/sbin/init` после установки пакетов
   - ✅ Автоматическое создание symlink `/sbin/init` → `/lib/systemd/systemd`

4. **scripts/build-minimal-iso.sh:**
   - ✅ Добавлен параметр `init=/lib/systemd/systemd` в GRUB конфигурацию
   - ✅ Добавлена проверка systemd и `/sbin/init` после установки пакетов

5. **scripts/desktop/install-kde.sh:**
   - ✅ Использован флаг `--important` для `apt-get autoremove` (защита критических пакетов)
   - ✅ Добавлена проверка systemd после `autoremove`
   - ✅ Восстановление symlink `/sbin/init` при необходимости

6. **scripts/base/cleanup.sh:**
   - ✅ Удалён опасный `apt-get autoremove` (может удалить systemd)
   - ✅ Добавлена проверка systemd в конце скрипта

**Причина проблемы:**
- Ubuntu 24.04 использует systemd как init-систему (PID 1)
- Без явного указания `systemd` в пакетах, он мог не установиться
- `apt-get autoremove` удалял systemd, считая его "ненужным"
- Без параметра `init=/lib/systemd/systemd` casper не мог найти init-процесс

**Решение:**
- Явная установка `systemd` и `systemd-sysv` во всех сценариях
- Защита от `autoremove` с флагом `--important`
- Явное указание `init=` в параметрах ядра GRUB
- Проверка и восстановление symlink `/sbin/init`

## [0.1.0-alpha] - TBD

Первый альфа-релиз VibeCode OS
