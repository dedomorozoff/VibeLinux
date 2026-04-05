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

# Полная сборка ISO (основной скрипт)
full:
	@echo "🚀 Запуск полной сборки ISO..."
	sudo BUILD_MODE=full ./scripts/build-iso.sh

# Полная сборка с сохранением chroot (быстрая пересборка)
full-keep:
	@echo "🔄 Запуск полной сборки с сохранением chroot..."
	sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-iso.sh

# Минимальная сборка ISO (CLI only)
mini:
	@echo "🚀 Запуск минимальной сборки ISO..."
	sudo BUILD_MODE=full ./scripts/build-minimal-iso.sh

# Минимальная сборка с сохранением chroot (быстрая пересборка)
mini-keep:
	@echo "🔄 Запуск минимальной сборки с сохранением chroot..."
	sudo KEEP_CHROOT=1 BUILD_MODE=full ./scripts/build-minimal-iso.sh

# Lite-сборка (быстрая, только базовые инструменты)
lite:
	@echo "🚀 Запуск Lite-сборки (Ubuntu 24.04, базовые инструменты)..."
	sudo bash ./scripts/build/build-vibe-lite-ubuntu.sh

# Full-сборка (все редакторы, AI-агенты, языки)
full-vibe:
	@echo "🚀 Запуск Full-сборки (Ubuntu 24.04, все инструменты)..."
	sudo bash ./scripts/build/build-vibe-full-ubuntu.sh

# Arch Linux сборка (rolling release)
arch:
	@echo "🚀 Запуск сборки Arch Linux..."
	sudo bash ./scripts/build/build-vibe-arch.sh

# Генерация скрипта сборки из JSON-конфигурации
generate:
	@echo "📝 Генерация скрипта сборки из конфигурации..."
	@bash ./scripts/base/generate-build-script.sh

# Проверка зависимостей для полной сборки
check:
	@echo "🔍 Проверка зависимостей для полной сборки..."
	BUILD_MODE=dry-run ./scripts/build-iso.sh

# Проверка зависимостей для минимальной сборки
check-mini:
	@echo "🔍 Проверка зависимостей для минимальной сборки..."
	BUILD_MODE=dry-run ./scripts/build-minimal-iso.sh

# Мастер доустановки компонентов (для Minimal → Full)
upgrade:
	@echo "🚀 Запуск мастера доустановки компонентов..."
	@echo ""
	@echo "Этот мастер поможет превратить Minimal версию в Full"
	@echo ""
	sudo bash ./scripts/minimal-upgrade.sh

# Запуск vibe-wizard (пост-установочный мастер)
wizard:
	@echo "🧙 Запуск Vibe Wizard (пост-установочный мастер)..."
	@echo ""
	@echo "Запустите в live-сессии:"
	@echo "  sudo bash ./scripts/base/vibe-wizard.sh"
	@echo ""
	@echo "Или напрямую:"
	@echo "  sudo /usr/local/bin/vibe-wizard"

# Очистка артефактов сборки
clean:
	@echo "🧹 Очистка артефактов сборки..."
	sudo rm -rf build/ build-minimal/ 2>/dev/null || true
	sudo rm -rf /srv/vibe-iso 2>/dev/null || true
	rm -rf out/ 2>/dev/null || true
	@echo "✅ Очистка завершена"

# Справка
help:
	@echo "VibeCode OS / VibeLinux — Сборка ISO-образов"
	@echo ""
	@echo "Основные цели:"
	@echo "  make full        - полная сборка ISO (основной скрипт)"
	@echo "  make full-keep   - полная сборка с сохранением chroot"
	@echo "  make mini        - минимальная сборка ISO (только CLI)"
	@echo "  make mini-keep   - минимальная сборка с сохранением chroot"
	@echo "  make lite        - быстрая lite-сборка (Ubuntu, базовые инструменты)"
	@echo "  make full-vibe   - полная сборка (все редакторы, AI, языки)"
	@echo "  make arch        - сборка на базе Arch Linux (rolling release)"
	@echo "  make generate    - генерация скрипта из JSON-конфига"
	@echo ""
	@echo "Проверка и утилиты:"
	@echo "  make check       - проверка зависимостей для полной сборки (dry-run)"
	@echo "  make check-mini  - проверка зависимостей для минимальной сборки (dry-run)"
	@echo "  make upgrade     - мастер доустановки компонентов (Minimal → Full)"
	@echo "  make wizard      - запуск vibe-wizard (пост-установочный мастер)"
	@echo "  make clean       - очистка артефактов сборки"
	@echo "  make help        - показать эту справку"
	@echo ""
	@echo "Примеры:"
	@echo "  make check       # Сначала проверь зависимости"
	@echo "  make lite        # Собери лёгкий ISO"
	@echo "  make full-vibe   # Собери полный ISO со всеми инструментами"
	@echo "  make arch        # Собери ISO на базе Arch Linux"
	@echo "  make generate    # Сгенерируй скрипт из JSON-конфига"
	@echo "  make full-keep   # Быстрая пересборка полного ISO"
	@echo "  make upgrade     # Доустановить компоненты в Minimal версии"
