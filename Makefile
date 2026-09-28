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
# Экспериментальная линия (FreeBSD: VibeBSD):
#   make bsd              - полная сборка ISO (Poudriere + jail + KDE Plasma 6)
#   make bsd-setup        - Poudriere + jail
#   make bsd-customize    - кастомизация rootfs
#   make bsd-packages     - установка пакетов в jail
#   make bsd-drop         - удаление тяжёлых пакетов
#   make bsd-slim         - утоньшение rootfs
#   make bsd-soft         - локальные сборки из soft/ (AI-агенты)
#   make bsd-build        - сборка ISO
#
# Утилиты:
#   make clean         - очистка артефактов сборки
#   make help          - справка по доступным командам
#
# Старые имена (full, mini, lite, check, ...) работают как алиасы legacy-целей.

.PHONY: arch arch-mini arch-mini-keep generate wizard \
        legacy-full legacy-full-keep legacy-mini legacy-mini-keep \
        legacy-lite legacy-full-vibe legacy-check legacy-check-mini legacy-upgrade \
        bsd bsd-setup bsd-customize bsd-packages bsd-drop bsd-slim bsd-soft bsd-build \
        clean help \
        full full-keep mini mini-keep lite full-vibe check check-mini upgrade

# Основная цель по умолчанию
all: help

# Абсолютный путь к репозиторию. Сборка идёт и на хосте FreeBSD (bmake, а не
# GNU make), где $(CURDIR) пустой, а $(.CURDIR) — рабочий; в GNU make наоборот,
# поэтому склеиваем оба варианта: лишняя часть всегда пуста.
ROOT := $(CURDIR)$(.CURDIR)

DETECT_DISTRO != sh -c 'if command -v pacman >/dev/null 2>&1; then echo arch; elif command -v dnf >/dev/null 2>&1; then echo fedora; elif command -v freebsd-version >/dev/null 2>&1; then echo freebsd; else echo ubuntu; fi'

# ============================================================
# Основная линия: Arch Linux + KDE Plasma 6
# ============================================================

# Сборка ISO Arch Linux (rolling release)
arch:
	@echo "🚀 Запуск сборки Arch Linux..."
	sudo bash $(ROOT)/scripts/build/build-vibe-arch.sh

# Минимальная сборка ISO (CLI only, Arch Linux)
arch-mini:
	@echo "🚀 Запуск минимальной сборки ISO (Arch Linux, CLI)..."
	sudo bash $(ROOT)/scripts/build/build-vibe-arch-minimal.sh

# Минимальная сборка с сохранением chroot (быстрая пересборка)
arch-mini-keep:
	@echo "🔄 Минимальная сборка с сохранением chroot (Arch Linux, CLI)..."
	sudo KEEP_CHROOT=1 bash $(ROOT)/scripts/build/build-vibe-arch-minimal.sh

# Генерация скрипта сборки из JSON-конфигурации
generate:
	@echo "📝 Генерация скрипта сборки из конфигурации..."
	@bash $(ROOT)/scripts/base/generate-build-script.sh

# Запуск vibe-wizard (пост-установочный мастер)
wizard:
	@echo "🧙 Запуск Vibe Wizard (пост-установочный мастер)..."
	@echo ""
	@echo "Запустите в live-сессии:"
	@echo "  sudo bash $(ROOT)/scripts/base/vibe-wizard.sh"
	@echo ""
	@echo "Или напрямую:"
	@echo "  sudo /usr/local/bin/vibe-wizard"

# ============================================================
# Legacy: Ubuntu-редакции (Full / Minimal / Lite)
# ============================================================

# Полная сборка ISO (Ubuntu 24.04)
legacy-full:
	@echo "🚀 Запуск полной сборки ISO (Ubuntu, legacy)..."
	sudo BUILD_MODE=full $(ROOT)/scripts/legacy/build-iso.sh

# Полная сборка с сохранением chroot (быстрая пересборка)
legacy-full-keep:
	@echo "🔄 Запуск полной сборки с сохранением chroot (Ubuntu, legacy)..."
	sudo KEEP_CH_ROOT=1 BUILD_MODE=full $(ROOT)/scripts/legacy/build-iso.sh

# Минимальная сборка ISO (CLI only)
legacy-mini:
	@echo "🚀 Запуск минимальной сборки ISO (Ubuntu, legacy)..."
	sudo BUILD_MODE=full $(ROOT)/scripts/legacy/build-minimal-iso.sh

# Минимальная сборка с сохранением chroot (быстрая пересборка)
legacy-mini-keep:
	@echo "🔄 Запуск минимальной сборки с сохранением chroot (Ubuntu, legacy)..."
	sudo KEEP_CH_ROOT=1 BUILD_MODE=full $(ROOT)/scripts/legacy/build-minimal-iso.sh

# Lite-сборка (быстрая, только базовые инструменты)
legacy-lite:
	@echo "🚀 Запуск Lite-сборки (Ubuntu 24.04, legacy, базовые инструменты)..."
	sudo bash $(ROOT)/scripts/legacy/build/build-vibe-lite-ubuntu.sh

# Full-сборка (все редакторы, AI-агенты, языки)
legacy-full-vibe:
	@echo "🚀 Запуск Full-сборки (Ubuntu 24.04, legacy, все инструменты)..."
	sudo bash $(ROOT)/scripts/legacy/build/build-vibe-full-ubuntu.sh

# Проверка зависимостей для полной сборки (dry-run)
legacy-check:
	@echo "🔍 Проверка зависимостей для полной сборки (Ubuntu, legacy)..."
	BUILD_MODE=dry-run $(ROOT)/scripts/legacy/build-iso.sh

# Проверка зависимостей для минимальной сборки (dry-run)
legacy-check-mini:
	@echo "🔍 Проверка зависимостей для минимальной сборки (Ubuntu, legacy)..."
	BUILD_MODE=dry-run $(ROOT)/scripts/legacy/build-minimal-iso.sh

# Мастер доустановки компонентов (для Minimal → Full)
legacy-upgrade:
	@echo "🚀 Запуск мастера доустановки компонентов (Ubuntu, legacy)..."
	sudo bash $(ROOT)/scripts/legacy/minimal-upgrade.sh

# ============================================================
# FreeBSD: VibeBSD (экспериментальная редакция)
# ============================================================

# Полная сборка: setup → customize → пакеты → чистка → soft → ISO
bsd:
	@echo "🚀 VibeBSD: полная сборка (setup + customize + пакеты + slim + soft + ISO)..."
	sh $(ROOT)/freebsd-vibebsd/scripts/00-setup-poudriere.sh
	sh $(ROOT)/freebsd-vibebsd/scripts/10-customize-rootfs.sh
	sh $(ROOT)/freebsd-vibebsd/scripts/15-install-packages.sh
	sh $(ROOT)/freebsd-vibebsd/scripts/16-drop-postinstall.sh
	sh $(ROOT)/freebsd-vibebsd/scripts/17-slim-rootfs.sh
	sh $(ROOT)/freebsd-vibebsd/scripts/18-install-soft.sh
	sh $(ROOT)/freebsd-vibebsd/scripts/20-build-iso.sh

# Установка Poudriere + создание jail (portstree — только VIBEBSD_PORTS=1)
bsd-setup:
	@echo "🧱 VibeBSD: установка Poudriere + jail..."
	sh $(ROOT)/freebsd-vibebsd/scripts/00-setup-poudriere.sh

# Кастомизация rootfs (брендинг, пользователь, конфиги)
bsd-customize:
	@echo "🎨 VibeBSD: кастомизация rootfs..."
	sh $(ROOT)/freebsd-vibebsd/scripts/10-customize-rootfs.sh

# Установка бинарных пакетов в jail (официальный репозиторий FreeBSD)
bsd-packages:
	@echo "📦 VibeBSD: установка пакетов в jail..."
	sh $(ROOT)/freebsd-vibebsd/scripts/15-install-packages.sh

# Удаление тяжёлых пакетов из jail (rust, postgres-client, samba) — до утоньшения
bsd-drop:
	@echo "🗑  VibeBSD: выкинуть тяжёлые пакеты из jail..."
	sh $(ROOT)/freebsd-vibebsd/scripts/16-drop-postinstall.sh

# Утоньшение rootfs (docs, man, локали, тесты) — после bsd-drop
bsd-slim:
	@echo "🪓 VibeBSD: утоньшение rootfs..."
	sh $(ROOT)/freebsd-vibebsd/scripts/17-slim-rootfs.sh

# Локальные сборки из soft/ (opencode, dmcode, dmed, dmsh) — после утоньшения
bsd-soft:
	@echo "🧰 VibeBSD: установка локальных пакетов из soft/..."
	sh $(ROOT)/freebsd-vibebsd/scripts/18-install-soft.sh

# Сборка ISO
bsd-build:
	@echo "💿 VibeBSD: сборка ISO..."
	sh $(ROOT)/freebsd-vibebsd/scripts/20-build-iso.sh

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
	sudo rm -rf $(ROOT)/build/ $(ROOT)/build-minimal/ 2>/dev/null || true
	sudo rm -rf /srv/vibe-iso /srv/vibe-iso-work 2>/dev/null || true
	rm -rf $(ROOT)/out/ 2>/dev/null || true
	@echo "✅ Очистка завершена"

# Справка
help:
	@echo "VibeCode OS / VibeLinux — Сборка ISO-образов"
	@echo ""
	@echo "Основная линия (Arch Linux + KDE Plasma 6):"
	@echo "  make arch       - сборка ISO"
	@echo "  make arch-mini  - минимальная сборка ISO (CLI only)"
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
	@echo "FreeBSD (экспериментальная редакция VibeBSD):"
	@echo "  make bsd              - полная сборка (setup + customize + пакеты + slim + ISO)"
	@echo "  make bsd-setup        - Poudriere + jail"
	@echo "  make bsd-customize    - кастомизация rootfs"
	@echo "  make bsd-packages     - установка пакетов в jail"
	@echo "  make bsd-drop         - удаление тяжёлых пакетов (rust/pg-client/samba)"
	@echo "  make bsd-slim         - утоньшение rootfs (docs, man, локали)"
	@echo "  make bsd-soft         - локальные сборки из soft/ (opencode, dmcode, dmed, dmsh)"
	@echo "  make bsd-build        - сборка ISO"
	@echo ""
	@echo "Утилиты:"
	@echo "  make clean       - очистка артефактов (build/, out/, /srv/vibe-iso-work)"
	@echo "  make help        - эта справка"
	@echo ""
	@echo "Старые имена (full, mini, lite, check, upgrade, ...) работают как алиасы."
	@echo "Текущая ОС: $(DETECT_DISTRO)"
