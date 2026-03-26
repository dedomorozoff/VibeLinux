# Changelog

## [Unreleased]

### Added

**Core OS:**
- Настройка GRUB и Plymouth с брендингом VibeCode OS
- Скрипт `setup-bootloader.sh` для кастомизации загрузчика
- Базовая система на Ubuntu 24.04 LTS + MATE

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

5. **scripts/desktop/install-mate.sh:**
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
