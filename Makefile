# Makefile для сборки VibeCode OS / VibeLinux
#
# Основная линия (Arch Linux + KDE Plasma 6):
#   make arch          - сборка ISO (профиль archiso-vibelinux)
#   make generate      - генерация скрипта сборки из JSON-конфига
#   make wizard        - пост-установочный мастер (live-сессия)
#
# Legacy (Ubuntu 24.04: Full / Minimal / Lite):
#   make legacy-full       - полная сборка ISO
#   make legacy-full-keep  - полная сборка с сохранением chroot
#   make legacy-mini       - минимальная сборка ISO (CLI)
#   make legacy-mini-keep  - минимальная сборка с сохранением chroot
#   make legacy-lite       - быстрая Lite-сборка
#   make legacy-full-vibe  - полная сборка (все инструменты)
#   make legacy-check      - проверка зависимостей (dry-run)
#   make legacy-check-mini - проверка зависимостей minimal (dry-run)
#   make legacy-upgrade    - мастер доустановки (Minimal → Full)
#
# Утилиты:
#   make clean         - очистка артефактов сборки
#   make help          - справка по доступным командам
#
# Старые имена (full, mini, lite, check, ...) работают как алиасы legacy-целей.

.PHONY: arch generate wizard \
        legacy-full legacy-full-keep legacy-mini legacy-mini-keep \
        legacy-lite legacy-full-vibe legacy-check legacy-check-mini legacy-upgrade \
        clean help \
        full full-keep mini mini-keep lite full-vibe check check-mini upgrade

# Основная цель по умолчанию
all: help

ПУТЬ := $(CURDIR)

DETECT_DISTRO := $(shell if command -v pacman >/dev/null 2>&1; then echo "arch"; elif command -v dnf >/dev/null 2>&1; then echo "fedora"; else echo "ubuntu"; fi)

# ============================================================
# Основная линия: Arch Linux + KDE Plasma 6
# ============================================================

# Сборка ISO Arch Linux (rolling release)
arch:
	@echo "🚀 Запуск сборки Arch Linux..."
	sudo bash $(ПУТЬ)/scripts/build/build-vibe-arch.sh

# Генерация скрипта сборки из JSON-конфигурации
generate:
	@echo "📝 Генерация скрипта сборки из конфигурации..."
	@bash $(ПУТЬ)/scripts/base/generate-build-script.sh

# Запуск vibe-wizard (пост-установочный мастер)
wizard:
	@echo "🧙 Запуск Vibe Wizard (пост-установочный мастер)..."
	@echo ""
	@echo "Запустите в live-сессии:"
	@echo "  sudo bash $(ПУТЬ)/scripts/base/vibe-wizard.sh"
	@echo ""
	@echo "Или напрямую:"
	@echo "  sudo /usr/local/bin/vibe-wizard"

# ============================================================
# Legacy: Ubuntu-редакции (Full / Minimal / Lite)
# ============================================================

# Полная сборка ISO (Ubuntu 24.04)
legacy-full:
	@echo "🚀 Запуск полной сборки ISO (Ubuntu, legacy)..."
	sudo BUILD_MODE=full $(ПУТЬ)/scripts/legacy/build-iso.sh

# Полная сборка с сохранением chroot (быстрая пересборка)
legacy-full-keep:
	@echo "🔄 Запуск полной сборки с сохранением chroot (Ubuntu, legacy)..."
	sudo KEEP_CH_ROOT=1 BUILD_MODE=full $(ПУТЬ)/scripts/legacy/build-iso.sh

# Минимальная сборка ISO (CLI only)
legacy-mini:
	@echo "🚀 Запуск минимальной сборки ISO (Ubuntu, legacy)..."
	sudo BUILD_MODE=full $(ПУТЬ)/scripts/legacy/build-minimal-iso.sh

# Минимальная сборка с сохранением chroot (быстрая пересборка)
legacy-mini-keep:
	@echo "🔄 Запуск минимальной сборки с сохранением chroot (Ubuntu, legacy)..."
	sudo KEEP_CH_ROOT=1 BUILD_MODE=full $(ПУТЬ)/scripts/legacy/build-minimal-iso.sh

# Lite-сборка (быстрая, только базовые инструменты)
legacy-lite:
	@echo "🚀 Запуск Lite-сборки (Ubuntu 24.04, legacy, базовые инструменты)..."
	sudo bash $(ПУТЬ)/scripts/legacy/build/build-vibe-lite-ubuntu.sh

# Full-сборка (все редакторы, AI-агенты, языки)
legacy-full-vibe:
	@echo "🚀 Запуск Full-сборки (Ubuntu 24.04, legacy, все инструменты)..."
	sudo bash $(ПУТЬ)/scripts/legacy/build/build-vibe-full-ubuntu.sh

# Проверка зависимостей для полной сборки (dry-run)
legacy-check:
	@echo "🔍 Проверка зависимостей для полной сборки (Ubuntu, legacy)..."
	BUILD_MODE=dry-run $(ПУТЬ)/scripts/legacy/build-iso.sh

# Проверка зависимостей для минимальной сборки (dry-run)
legacy-check-mini:
	@echo "🔍 Проверка зависимостей для минимальной сборки (Ubuntu, legacy)..."
	BUILD_MODE=dry-run $(ПУТЬ)/scripts/legacy/build-minimal-iso.sh

# Мастер доустановки компонентов (для Minimal → Full)
legacy-upgrade:
	@echo "🚀 Запуск мастера доустановки компонентов (Ubuntu, legacy)..."
	sudo bash $(ПУТЬ)/scripts/legacy/minimal-upgrade.sh

# ============================================================
# Старые имена (deprecated алиасы legacy-целей)
# ============================================================
full: legacy-full
full-keep: legacy-full-keep
mini: legacy-mini
mini-keep: legacy-mini-keep
lite: legacy-lite
full-vibe: legacy-full-vibe
check: legacy-check
check-mini: legacy-check-mini
upgrade: legacy-upgrade

# ============================================================
# Утилиты
# ============================================================

# Очистка артефактов сборки
clean:
	@echo "🧹 Очистка артефактов сборки..."
	sudo rm -rf $(ПУТЬ)/build/ $(ПУТЬ)/build-minimal/ 2>/dev/null || true
	sudo rm -rf /srv/vibe-iso /srv/vibe-iso-work 2>/dev/null || true
	rm -rf $(ПУТЬ)/out/ 2>/dev/null || true
	@echo "✅ Очистка завершена"

# Справка
help:
	@echo "VibeCode OS / VibeLinux — Сборка ISO-образов"
	@echo ""
	@echo "Основная линия (Arch Linux + KDE Plasma 6):"
	@echo "  make arch       - сборка ISO"
	@echo "  make generate   - генерация скрипта сборки из JSON-конфига"
	@echo "  make wizard     - пост-установочный мастер (live-сессия)"
	@echo ""
	@echo "Legacy (Ubuntu 24.04: Full / Minimal / Lite):"
	@echo "  make legacy-full       - полная сборка ISO"
	@echo "  make legacy-full-keep  - полная сборка с сохранением chroot"
	@echo "  make legacy-mini       - минимальная сборка ISO (CLI)"
	@echo "  make legacy-mini-keep  - минимальная сборка с сохранением chroot"
	@echo "  make legacy-lite       - быстрая Lite-сборка"
	@echo "  make legacy-full-vibe  - полная сборка (все инструменты)"
	@echo "  make legacy-check      - проверка зависимостей (dry-run)"
	@echo "  make legacy-check-mini - проверка зависимостей minimal (dry-run)"
	@echo "  make legacy-upgrade    - мастер доустановки (Minimal → Full)"
	@echo ""
	@echo "Утилиты:"
	@echo "  make clean       - очистка артефактов (build/, out/, /srv/vibe-iso-work)"
	@echo "  make help        - эта справка"
	@echo ""
	@echo "Старые имена (full, mini, lite, check, upgrade, ...) работают как алиасы."
	@echo "Текущая ОС: $(DETECT_DISTRO)"
