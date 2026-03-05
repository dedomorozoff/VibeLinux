#!/usr/bin/env bash
set -euo pipefail

# Черновой оркестратор сборки ISO для VibeCode OS.
#
# Контракт и целевой пайплайн описаны в `docs/BUILD-ISO.md`.
# В CI (GitHub Actions) скрипт запускается в режиме dry-run, чтобы проверять
# наличие инструментов и базовую структуру репозитория.

# Определяем ROOT_DIR:
# Находим корень репозитория (папка с .git и документацией)
# Запуск возможен из любой директории

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"

# 1. Если запущен из корня репозитория (есть .git в текущей директории)
if [[ -d ".git" ]]; then
  ROOT_DIR="${CURRENT_DIR}"
# 2. Если запущен из поддиректории (scripts/, docs/, etc)
elif [[ -d "scripts" || -d "docs" || -d ".github" ]]; then
  ROOT_DIR="${CURRENT_DIR}"
# 3. Если скрипт в scripts/, а запускаем из scripts/
elif [[ "${SCRIPT_DIR}" == *"scripts" ]] && [[ -d "${SCRIPT_DIR}/../.git" || -d "${SCRIPT_DIR}/../scripts" ]]; then
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# 4. Фоллбек: идём вверх от места расположения скрипта
else
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

BUILD_MODE="${BUILD_MODE:-dry-run}" # dry-run|full
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/build}"
CHROOT_DIR="${CHROOT_DIR:-${WORK_DIR}/chroot}"
IMAGE_DIR="${IMAGE_DIR:-${WORK_DIR}/image}"
ISO_OUTPUT="${ISO_OUTPUT:-${WORK_DIR}/VibeCodeOS-alpha.iso}"

log() { echo "[build-iso] $*"; }
die() { echo "[build-iso] ERROR: $*" >&2; exit 1; }
need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Не найдено: '$cmd'. Установите зависимости (см. docs/BUILD-ISO.md и .github/workflows/build-iso.yml)."
}
need_file() {
  local path="$1"
  [[ -f "$path" ]] || die "Не найден файл: ${path#$ROOT_DIR/}"
}
need_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "Не найден каталог: ${path#$ROOT_DIR/}"
}

mkdir -p "${WORK_DIR}"

log "ROOT_DIR=${ROOT_DIR}"
log "WORK_DIR=${WORK_DIR}"
log "BUILD_MODE=${BUILD_MODE}"

case "${BUILD_MODE}" in
  dry-run)
    log "Проверяю зависимости CLI и структуру репозитория (dry-run)."

    # Инструменты сборки ISO (см. docs/BUILD-ISO.md)
    need_cmd debootstrap
    need_cmd mksquashfs
    need_cmd xorriso
    need_cmd grub-mkrescue
    need_cmd mformat

    # Базовая структура scripts/
    need_dir "${ROOT_DIR}/scripts"
    need_file "${ROOT_DIR}/scripts/base/base-packages.sh"
    need_file "${ROOT_DIR}/scripts/base/cleanup.sh"
    need_file "${ROOT_DIR}/scripts/desktop/install-mate.sh"
    need_file "${ROOT_DIR}/scripts/drivers/install-nvidia.sh"

    # Документация/CI точка опоры (чтобы не разъехалось)
    need_file "${ROOT_DIR}/docs/BUILD-ISO.md"
    need_file "${ROOT_DIR}/.github/workflows/build-iso.yml"

    log "OK: dry-run проверки пройдены. Полная сборка пока не выполняется этим скриптом."
    ;;

  full)
    if [[ $EUID -ne 0 ]]; then
      die "Режим full требует root (запускайте через sudo)."
    fi

    log "Запуск пайплайна сборки alpha-ISO VibeCode OS..."

    # Шаг 1: Bootstrap Ubuntu 24.04 в chroot
    log "Шаг 1: Bootstrap Ubuntu 24.04 (noble) в ${CHROOT_DIR}"
    rm -rf "${CHROOT_DIR}"
    debootstrap --arch=amd64 noble "${CHROOT_DIR}" http://archive.ubuntu.com/ubuntu

    # Шаг 2: Настройка chroot
    log "Шаг 2: Настройка chroot"
    mount -t proc proc "${CHROOT_DIR}/proc"
    mount -t sysfs sys "${CHROOT_DIR}/sys"
    mount -o bind /dev "${CHROOT_DIR}/dev"

    # Шаг 3: Установка базовых пакетов
    log "Шаг 3: Установка базовых пакетов"
    cp "${ROOT_DIR}/scripts/base/base-packages.sh" "${CHROOT_DIR}/root/base-packages.sh"
    cp "${ROOT_DIR}/scripts/base/cleanup.sh" "${CHROOT_DIR}/root/cleanup.sh"
    cp "${ROOT_DIR}/scripts/desktop/install-mate.sh" "${CHROOT_DIR}/root/install-mate.sh"
    cp "${ROOT_DIR}/scripts/drivers/install-nvidia.sh" "${CHROOT_DIR}/root/install-nvidia.sh"

    chroot "${CHROOT_DIR}" /bin/bash /root/base-packages.sh
    chroot "${CHROOT_DIR}" /bin/bash /root/cleanup.sh
    chroot "${CHROOT_DIR}" /bin/bash /root/install-mate.sh

    # Шаг 4: Очистка и выключение
    log "Шаг 4: Очистка chroot"
    umount "${CHROOT_DIR}/proc"
    umount "${CHROOT_DIR}/sys"
    umount "${CHROOT_DIR}/dev"

    # Шаг 5: Подготовка SquashFS
    log "Шаг 5: Упаковка rootfs в SquashFS"
    mkdir -p "${IMAGE_DIR}/casper"
    mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" -comp xz -b 1M

    # Шаг 6: Подготовка структуры live-ISO
    log "Шаг 6: Подготовка структуры live-ISO"
    mkdir -p "${IMAGE_DIR}/boot/grub"
    mkdir -p "${IMAGE_DIR}/casper"
    mkdir -p "${IMAGE_DIR}/.disk"
    mkdir -p "${IMAGE_DIR}/EFI"
    mkdir -p "${IMAGE_DIR}/EFI/boot"

    # Создаём файл метаданных
    echo "VibeCode OS alpha" > "${IMAGE_DIR}/.disk/info"
    echo "system" > "${IMAGE_DIR}/.disk/cd_type"
    date > "${IMAGE_DIR}/.disk/build_time"
    echo "VibeCodeOS-alpha" > "${IMAGE_DIR}/.disk/ubuntu_dist"

    # Копируем initrd и vmlinuz
    # (будет настроено при установке grub)

    # Шаг 7: Создание ISO через grub-mkrescue
    log "Шаг 7: Создание ISO с grub-mkrescue"
    grub-mkrescue -o "${ISO_OUTPUT}" "${IMAGE_DIR}" || die "Ошибка при создании ISO"

    log "✅ ISO собран: ${ISO_OUTPUT}"
    log "Проверьте файл: ${ISO_OUTPUT}"
    ;;

  *)
    die "Неизвестный BUILD_MODE='${BUILD_MODE}'. Допустимо: dry-run|full"
    ;;
esac

