### Core OS: структура скриптов (черновик)

Этот документ описывает, как скрипты в `scripts/` используются для подготовки базовой системы и сборки alpha-ISO VibeCode OS.

---

### 1. Основные каталоги

- `scripts/base/` — базовые пакеты, cleanup, системные настройки.
- `scripts/desktop/` — установка и настройка MATE и графического стека.
- `scripts/drivers/` — установка проприетарных драйверов (в первую очередь NVIDIA).
- `scripts/build/` — сборка ISO (debootstrap + SquashFS + GRUB, интеграция с CI).

Dev- и AI-скрипты вынесены отдельно и описаны в `docs/DEVSTACK.md` и `docs/AI-STACK.md`.

---

### 2. Слой Base (`scripts/base/`)

- `scripts/base/base-packages.sh`
  - Устанавливает базовые CLI-утилиты:
    - мониторинг и системные утилиты (`htop`, `btop`, `neofetch`),
    - инструменты для загрузки (`curl`, `wget`, `unzip`),
    - инструменты разработки (`git`, `build-essential`),
    - служебные пакеты (`ca-certificates`, `software-properties-common`).
  - Ожидается запуск с правами `root` на Ubuntu 24.04 или совместимой.

- `scripts/base/cleanup.sh`
  - Удаляет типичные предустановленные пакеты (офис, почта, игры и т.п.).
  - Выполняет `autoremove`.
  - Список пакетов будет уточняться и может отличаться между live-окружением и установленной системой.

---

### 3. Слой Desktop (`scripts/desktop/`)

- `scripts/desktop/install-mate.sh`
  - Устанавливает MATE и дисплей-менеджер LightDM.
  - Режим выбирается переменной `PROFILE`:
    - `PROFILE=minimal` — на базе `mate-desktop-environment` (чистый MATE).
    - `PROFILE=standard` (по умолчанию) — на базе `ubuntu-mate-desktop` (стек Ubuntu MATE).
  - Настраивает LightDM как дисплей-менеджер по умолчанию, когда это уместно.
  - Может работать как внутри chroot при сборке ISO, так и на установленной системе.

---

### 4. Слой Drivers (`scripts/drivers/`)

- `scripts/drivers/install-nvidia.sh`
  - Post-install скрипт для установки проприетарных драйверов NVIDIA.
  - Профили:
    - `PROFILE=desktop` (по умолчанию) — установка основного драйвера (например, `nvidia-driver-535`).
    - `PROFILE=ai` — тот же драйвер + в будущем дополнительные compute/CUDA-компоненты.
  - Цель для alpha:
    - Обеспечить простой сценарий установки драйвера после инсталляции системы.
    - Интеграция с установщиком (галочка «проприетарные драйверы») пока не модифицируется.

Подробнее о стратегии NVIDIA см. в `docs/DRIVERS-NVIDIA.md`.

---

### 5. Слой Build (`scripts/build/`)

- `scripts/build-iso.sh`
  - Оркестратор сборки ISO на основе:
    - `debootstrap` (rootfs Ubuntu 24.04),
    - `squashfs-tools` (`mksquashfs`),
    - `xorriso`,
    - `grub-mkrescue`.
  - Режимы:
    - `BUILD_MODE=dry-run` — проверка наличия инструментов и базовой структуры (используется в CI).
    - `BUILD_MODE=full` — в будущем реализует полный пайплайн сборки alpha-ISO.
  - Использует директории:
    - `$WORK_DIR` (по умолчанию `./build`),
    - `$CHROOT_DIR`, `$IMAGE_DIR`, `$ISO_OUTPUT`.

Детали пайплайна ISO описаны в `docs/BUILD-ISO.md`.

