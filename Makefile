# Makefile для сборки VibeCode OS
#
# Использование:
#   make full          - полная сборка ISO (с GUI, dev и AI-стеком)
#   make mini          - минимальная сборка ISO (только CLI)
#   make full-keep     - полная сборка с сохранением chroot
#   make mini-keep     - минимальная сборка с сохранением chroot
#   make check         - проверка зависимостей (dry-run)
#   make check-mini    - проверка зависимостей для mini (dry-run)
#   make clean         - очистка артефактов сборки
#   make help          - справка по доступным командам

.PHONY: full mini full-keep mini-keep check check-mini clean help

# Основная цель по умолчанию
all: help

# Полная сборка ISO
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

# Проверка зависимостей для полной сборки
check:
	@echo "🔍 Проверка зависимостей для полной сборки..."
	BUILD_MODE=dry-run ./scripts/build-iso.sh

# Проверка зависимостей для минимальной сборки
check-mini:
	@echo "🔍 Проверка зависимостей для минимальной сборки..."
	BUILD_MODE=dry-run ./scripts/build-minimal-iso.sh

# Очистка артефактов сборки
clean:
	@echo "🧹 Очистка артефактов сборки..."
	sudo rm -rf build/ build-minimal/ 2>/dev/null || true
	@echo "✅ Очистка завершена"

# Справка
help:
	@echo "VibeCode OS — Сборка ISO-образов"
	@echo ""
	@echo "Доступные команды:"
	@echo "  make full        - полная сборка ISO (с GUI, dev и AI-стеком)"
	@echo "  make full-keep   - полная сборка с сохранением chroot (быстрая пересборка)"
	@echo "  make mini        - минимальная сборка ISO (только CLI)"
	@echo "  make mini-keep   - минимальная сборка с сохранением chroot (быстрая пересборка)"
	@echo "  make check       - проверка зависимостей для полной сборки (dry-run)"
	@echo "  make check-mini  - проверка зависимостей для минимальной сборки (dry-run)"
	@echo "  make clean       - очистка артефактов сборки"
	@echo "  make help        - показать эту справку"
	@echo ""
	@echo "Примеры:"
	@echo "  make check       # Сначала проверь зависимости"
	@echo "  make mini        # Собери минимальный ISO"
	@echo "  make full-keep   # Быстрая пересборка полного ISO"
