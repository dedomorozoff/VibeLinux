# Makefile для сборки VibeCode OS / VibeLinux
#
# Использование:
#   make full          - полная сборка ISO (с GUI, dev и AI-стеком)
#   make mini          - минимальная сборка ISO (только CLI)
#   make full-keep     - полная сборка с сохранением chroot
#   make mini-keep     - минимальная сборка с сохранением chroot
#   make lite          - быстрая lite-сборка (Ubuntu, базовые инструменты)
#   make arch          - сборка на базе Arch Linux (rolling release)
#   make generate      - генерация скрипта сборки из JSON-конфига
#   make check         - проверка зависимостей (dry-run)
#   make check-mini    - проверка зависимостей для mini (dry-run)
#   make upgrade       - мастер доустановки компонентов (для Minimal)
#   make wizard        - запуск vibe-wizard (пост-установочный мастер)
#   make clean         - очистка артефактов сборки
#   make help          - справка по доступным командам

.PHONY: full mini full-keep mini-keep lite arch generate check check-mini upgrade wizard clean help

# Основная цель по умолчанию
all: help

# Makefile для сборки VibeCode OS / VibeCode OS
ПУТЬ := /home/dedo/VibeLinux

DETECT_DISTRO := $(shell if command -v pacman >/dev/null 2>&1; then echo "arch"; elif command -v dnf >/dev/null 2>&1; then echo "fedora"; else echo "ubuntu"; fi)

# Полная сборка ISO (определяет ОС)
full:
	@echo "🚀 Запуск полной сборки ISO ($(DETECT_DISTRO) detected)..."
	@if [ "$(DETECT_DISTRO)" = "arch" ]; then \
		sudo bash $(ПУТЬ)/scripts/build/build-vibe-arch.sh; \
	elif [ "$(DETECT_DISTRO)" = "fedora" ]; then \
		sudo BUILD_MODE=full $(ПУТЬ)/scripts/build-iso.sh; \
	else \
		sudo BUILD_MODE=full $(ПУТЬ)/scripts/build-iso.sh; \
	fi

# Полная сборка с сохранением chroot (быстрая пересборка)
full-keep:
	@echo "🔄 Запуск полной сборки с сохранением chroot ($(DETECT_DISTRO) detected)..."
	@if [ "$(DETECT_DISTRO)" = "arch" ]; then \
		sudo KEEP_CH_ROOT=1 bash $(ПУТЬ)/scripts/build/build-vibe-arch.sh; \
	else \
		sudo KEEP_CH_ROOT=1 BUILD_MODE=full $(ПУТЬ)/scripts/build-iso.sh; \
	fi

# Минимальная сборка ISO (CLI only)
mini:
	@echo "🚀 Запуск минимальной сборки ISO ($(DETECT_DISTRO) detected)..."
	@if [ "$(DETECT_DISTRO)" = "arch" ]; then \
		sudo bash $(ПУТЬ)/scripts/build/build-vibe-arch.sh; \
	else \
		sudo BUILD_MODE=full $(ПУТЬ)/scripts/build-minimal-iso.sh; \
	fi

# Минимальная сборка с сохранением chroot (быстрая пересборка)
mini-keep:
	@echo "🔄 Запуск минимальной сборки с сохранением chroot ($(DETECT_DISTRO) detected)..."
	@if [ "$(DETECT_DISTRO)" = "arch" ]; then \
		sudo KEEP_CH_ROOT=1 bash $(ПУТЬ)/scripts/build/build-vibe-arch.sh; \
	else \
		sudo KEEP_CH_ROOT=1 BUILD_MODE=full $(ПУТЬ)/scripts/build-minimal-iso.sh; \
	fi

# Lite-сборка (быстрая, только базовые инструменты)
lite:
	@echo "🚀 Запуск Lite-сборки (Ubuntu 24.04, базовые инструменты)..."
	sudo bash $(ПУТЬ)/scripts/build/build-vibe-lite-ubuntu.sh

# Full-сборка (все редакторы, AI-агенты, языки)
full-vibe:
	@echo "🚀 Запуск Full-сборки (Ubuntu 24.04, все инструменты)..."
	sudo bash $(ПУТЬ)/scripts/build/build-vibe-full-ubuntu.sh

# Arch Linux сборка (rolling release)
arch:
	@echo "🚀 Запуск сборки Arch Linux..."
	sudo bash $(ПУТЬ)/scripts/build/build-vibe-arch.sh

# Генерация скрипта сборки из JSON-конфигурации
generate:
	@echo "📝 Генерация скрипта сборки из конфигурации..."
	@bash $(ПУТЬ)/scripts/base/generate-build-script.sh

# Проверка зависимостей для полной сборки
check:
	@echo "🔍 Проверка зависимостей для полной сборки..."
	BUILD_MODE=dry-run $(ПУТЬ)/scripts/build-iso.sh

# Проверка зависимостей для минимальной сборки
check-mini:
	@echo "🔍 Проверка зависимостей для минимальной сборки..."
	BUILD_MODE=dry-run $(ПУТЬ)/scripts/build-minimal-iso.sh

# Мастер доустановки компонентов (для Minimal → Full)
upgrade:
	@echo "🚀 Запуск мастера доустановки компонентов..."
	sudo bash $(ПУТЬ)/scripts/minimal-upgrade.sh

# Запуск vibe-wizard (пост-установочный мастер)
wizard:
	@echo "🧙 Запуск Vibe Wizard (пост-установочный мастер)..."
	@echo ""
	@echo "Запустите в live-сессии:"
	@echo "  sudo bash $(ПУТЬ)/scripts/base/vibe-wizard.sh"
	@echo ""
	@echo "Или напрямую:"
	@echo "  sudo /usr/local/bin/vibe-wizard"

# Очистка артефактов сборки
clean:
	@echo "🧹 Очистка артефактов сборки..."
	sudo rm -rf $(ПУТЬ)/build/ $(ПУТЬ)/build-minimal/ 2>/dev/null || true
	sudo rm -rf /srv/vibe-iso 2>/dev/null || true
	rm -rf $(ПУТЬ)/out/ 2>/dev/null || true
	@echo "✅ Очистка завершена"

# Справка
help:
	@echo "VibeCode OS / VibeLinux — Сборка ISO-образов"
	@echo ""
	@echo "Основные цели:"
	@echo "  make full        - полная сборка ISO (auto: определяет ОС хоста)"
	@echo "  make full-keep  - полная сборка с сохранением chroot"
	@echo "  make mini       - минимальная сборка ISO (auto: определяет ОС)"
	@echo "  make mini-keep  - минимальная сборка с сохранением chroot"
	@echo "  make lite       - быстрая lite-сборка (Ubuntu)"
	@echo "  make full-vibe  - полная сборка (Ubuntu, все инструменты)"
	@echo "  make arch       - сборка Arch Linux"
	@echo ""
	@echo "Проверка и утилиты:"
	@echo "  make check      - проверка зависимостей (dry-run)"
	@echo "  make upgrade    - мастер доустановки компонентов"
	@echo "  make wizard     - пост-установочный мастер"
	@echo "  make clean     - очистка артефактов"
	@echo "  make help      - эта справка"
	@echo ""
	@echo "Текущая ОС: $(DETECT_DISTRO)"
