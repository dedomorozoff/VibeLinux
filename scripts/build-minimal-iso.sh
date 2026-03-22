#!/usr/bin/env bash
set -euo pipefail

# Оркестратор сборки МИНИМАЛЬНОГО ISO (без GUI) для VibeCode OS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"

if [[ -d ".git" ]]; then
  ROOT_DIR="${CURRENT_DIR}"
elif [[ -d "scripts" || -d "docs" || -d ".github" ]]; then
  ROOT_DIR="${CURRENT_DIR}"
elif [[ "${SCRIPT_DIR}" == *"scripts" ]] && [[ -d "${SCRIPT_DIR}/../.git" || -d "${SCRIPT_DIR}/../scripts" ]]; then
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

BUILD_MODE="${BUILD_MODE:-dry-run}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/build-minimal}"
CHROOT_DIR="${CHROOT_DIR:-${WORK_DIR}/chroot}"
IMAGE_DIR="${IMAGE_DIR:-${WORK_DIR}/image}"
ISO_OUTPUT="${ISO_OUTPUT:-${WORK_DIR}/VibeCodeOS-minimal.iso}"

log() { echo "[build-minimal-iso] $*"; }
die() { echo "[build-minimal-iso] ERROR: $*" >&2; exit 1; }

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Не найдено: '$cmd'. Установите зависимости (debootstrap, mksquashfs, xorriso, grub-pc-bin, grub-efi-amd64-bin)."
}

mkdir -p "${WORK_DIR}"

log "ROOT_DIR=${ROOT_DIR}"
log "WORK_DIR=${WORK_DIR}"
log "BUILD_MODE=${BUILD_MODE}"

case "${BUILD_MODE}" in
  dry-run)
    log "Проверка зависимостей (dry-run)..."
    need_cmd debootstrap
    need_cmd mksquashfs
    need_cmd xorriso

    [[ -f "${ROOT_DIR}/scripts/base/minimal-packages.sh" ]] || die "Не найден скрипт minimal-packages.sh"
    log "OK: dry-run проверки пройдены."
    ;;

  full)
    if [[ $EUID -ne 0 ]]; then
      die "Режим full требует root (sudo)."
    fi

    log "Запуск сборки Minimal ISO..."

    # Шаг 1: Bootstrap
    if [[ ! -d "${CHROOT_DIR}/etc" ]]; then
      log "Шаг 1: Bootstrap Ubuntu 24.04..."
      debootstrap --arch=amd64 noble "${CHROOT_DIR}" http://archive.ubuntu.com/ubuntu
    fi

    # Шаг 2: Mount & Prep
    log "Шаг 2: Подготовка chroot..."
    mount -t proc proc "${CHROOT_DIR}/proc" 2>/dev/null || true
    mount -t sysfs sys "${CHROOT_DIR}/sys" 2>/dev/null || true
    mount -o bind /dev "${CHROOT_DIR}/dev" 2>/dev/null || true

    # Копируем только нужные скрипты
    cp "${ROOT_DIR}/scripts/base/minimal-packages.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/base/cleanup.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/base/setup-distro-info.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/base/setup-bootloader.sh" "${CHROOT_DIR}/root/"

    # Копируем скрипт доустановки (minimal-upgrade.sh)
    if [[ -f "${ROOT_DIR}/scripts/minimal-upgrade.sh" ]]; then
        log "Копирование minimal-upgrade.sh в chroot..."
        cp "${ROOT_DIR}/scripts/minimal-upgrade.sh" "${CHROOT_DIR}/usr/local/bin/vibecode-upgrade"
        chmod +x "${CHROOT_DIR}/usr/local/bin/vibecode-upgrade"
    fi

    chmod +x "${CHROOT_DIR}/root"/*.sh

    # Конвертация CRLF в LF (для Windows-систем)
    log "Конвертация окончаний строк в Unix-формат..."
    if command -v sed &>/dev/null; then
      chroot "${CHROOT_DIR}" /bin/bash -c "
        for f in /root/*.sh /usr/local/bin/vibecode-upgrade; do
          [ -f \"\$f\" ] && sed -i 's/\r$//' \"\$f\" 2>/dev/null || true
        done
      "
    fi

    # Шаг 3: Установка пакетов
    log "Шаг 3: Установка пакетов и настройка..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/minimal-packages.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-distro-info.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-bootloader.sh"

    # Создание пользователя
    chroot "${CHROOT_DIR}" /bin/bash -c '
      if ! id "vibecode" &>/dev/null; then
        useradd -m -s /bin/bash vibecode
        echo "vibecode:vibecode" | chpasswd
        usermod -a -G sudo vibecode
      fi
    '

    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/cleanup.sh"

    # Шаг 4: Размонтирование
    log "Шаг 4: Размонтирование..."
    umount -l "${CHROOT_DIR}/proc" || true
    umount -l "${CHROOT_DIR}/sys" || true
    umount -l "${CHROOT_DIR}/dev" || true

    # Шаг 5: SquashFS
    log "Шаг 5: Создание SquashFS..."
    mkdir -p "${IMAGE_DIR}/casper"
    rm -f "${IMAGE_DIR}/casper/filesystem.squashfs"
    mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" \
      -comp zstd \
      -e boot proc sys dev run tmp

    # Шаг 6: Подготовка ISO структуры
    log "Шаг 6: Подготовка структуры ISO..."
    mkdir -p "${IMAGE_DIR}/boot/grub"
    mkdir -p "${IMAGE_DIR}/casper"

    # Копирование ядра (используем относительные пути для casper)
    log "Копирование ядра и initrd..."
    if ls "${CHROOT_DIR}"/boot/vmlinuz-* 1>/dev/null 2>&1; then
        cp "$(ls -v "${CHROOT_DIR}"/boot/vmlinuz-* | tail -n 1)" "${IMAGE_DIR}/casper/vmlinuz"
        cp "$(ls -v "${CHROOT_DIR}"/boot/initrd.img-* | tail -n 1)" "${IMAGE_DIR}/casper/initrd"
        # Также копируем в boot для совместимости
        cp "${IMAGE_DIR}/casper/vmlinuz" "${IMAGE_DIR}/boot/vmlinuz"
        cp "${IMAGE_DIR}/casper/initrd" "${IMAGE_DIR}/boot/initrd"
    else
        die "Ядро не найдено в chroot/boot"
    fi

    # Шаг 7: Конфиг GRUB
    log "Шаг 7: Настройка GRUB..."
    cat > "${IMAGE_DIR}/boot/grub/grub.cfg" << 'GRUBEOF'
set default=0
set timeout=10

# Safe video режим для VirtualBox и проблемных видеокарт
menuentry "VibeCode OS Minimal (CLI)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false quiet ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (safe graphics)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false rescue ---
    initrd /casper/initrd
}
GRUBEOF

    # Шаг 8: Создание ISO (упрощенная версия для CLI)
    log "Шаг 8: Создание ISO..."
    # Для простоты используем grub-mkrescue или xorriso напрямую
    # Здесь используется минимальный xorriso вызов
    xorriso -as mkisofs \
      -iso-level 3 \
      -r -V "VibeCodeMinimal" \
      -o "${ISO_OUTPUT}" \
      -b boot/grub/grub.cfg \
      -no-emul-boot \
      "${IMAGE_DIR}" \
      || die "Ошибка при создании ISO"

    log "✅ Minimal ISO собран: ${ISO_OUTPUT}"
    ;;

  *)
    die "Неизвестный BUILD_MODE='${BUILD_MODE}'. Допустимо: dry-run|full"
    ;;
esac
