#!/usr/bin/env bash
set -euo pipefail

# Черновой оркестратор сборки ISO для VibeCode OS.
#
# Контракт и целевой пайплайн описаны в `docs/BUILD-ISO.md`.
# В CI (GitHub Actions) скрипт запускается в режиме dry-run, чтобы проверять
# наличие инструментов и базовую структуру репозитория.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

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

    log "Режим full пока не реализован (зарезервирован под alpha-ISO пайплайн)."
    log "Ожидаемые шаги:"
    log "  - debootstrap Ubuntu 24.04 (noble) в ${CHROOT_DIR}"
    log "  - запуск слоёв: scripts/base/* + scripts/desktop/install-mate.sh (MATE)"
    log "  - упаковка rootfs в SquashFS и подготовка структуры live-ISO в ${IMAGE_DIR}"
    log "  - grub-mkrescue -> ${ISO_OUTPUT}"
    log "См. docs/BUILD-ISO.md."
    exit 2
    ;;

  *)
    die "Неизвестный BUILD_MODE='${BUILD_MODE}'. Допустимо: dry-run|full"
    ;;
esac

