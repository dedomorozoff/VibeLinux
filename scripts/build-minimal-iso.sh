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

cleanup_mounts() {
  umount -l "${CHROOT_DIR}/proc" 2>/dev/null || true
  umount -l "${CHROOT_DIR}/sys" 2>/dev/null || true
  umount -l "${CHROOT_DIR}/run" 2>/dev/null || true
  umount -l "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
  umount -l "${CHROOT_DIR}/dev" 2>/dev/null || true
}

latest_kernel_path() {
  if ls "${CHROOT_DIR}"/boot/vmlinuz-* 1>/dev/null 2>&1; then
    ls -v "${CHROOT_DIR}"/boot/vmlinuz-* | tail -n 1
  elif [[ -f "${CHROOT_DIR}/boot/vmlinuz" ]]; then
    echo "${CHROOT_DIR}/boot/vmlinuz"
  fi
}

latest_initrd_path() {
  if ls "${CHROOT_DIR}"/boot/initrd.img-* 1>/dev/null 2>&1; then
    ls -v "${CHROOT_DIR}"/boot/initrd.img-* | tail -n 1
  elif [[ -f "${CHROOT_DIR}/boot/initrd.img" ]]; then
    echo "${CHROOT_DIR}/boot/initrd.img"
  fi
}

have_boot_artifacts() {
  [[ -n "$(latest_kernel_path)" ]] && [[ -n "$(latest_initrd_path)" ]]
}

need_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Не найдено: '$cmd'. Установите зависимости (debootstrap, mksquashfs, xorriso, grub-pc-bin, grub-efi-amd64-bin, mtools)."
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
    need_cmd grub-mkstandalone
    need_cmd mkfs.vfat
    need_cmd mcopy
    need_cmd mmd

    [[ -f "${ROOT_DIR}/scripts/base/minimal-packages.sh" ]] || die "Не найден скрипт minimal-packages.sh"
    log "OK: dry-run проверки пройдены."
    ;;

  full)
    if [[ $EUID -ne 0 ]]; then
      die "Режим full требует root (sudo)."
    fi

    log "Запуск сборки Minimal ISO..."
    trap cleanup_mounts EXIT

    # Шаг 1: Bootstrap
    if [[ ! -d "${CHROOT_DIR}/etc" ]]; then
      log "Шаг 1: Bootstrap Ubuntu 24.04..."
      # Полная установка как в base-packages.sh (без --include)
      debootstrap --arch=amd64 noble "${CHROOT_DIR}" http://archive.ubuntu.com/ubuntu
    fi

    mkdir -p "${CHROOT_DIR}/proc" "${CHROOT_DIR}/sys" "${CHROOT_DIR}/dev/pts" "${CHROOT_DIR}/run"

    # Шаг 2: Mount & Prep
    log "Шаг 2: Подготовка chroot..."
    cleanup_mounts
    mount -t proc proc "${CHROOT_DIR}/proc"
    mount -t sysfs sys "${CHROOT_DIR}/sys"
    mount -o bind /dev "${CHROOT_DIR}/dev"
    mount -t devpts devpts "${CHROOT_DIR}/dev/pts"
    mount -o bind /run "${CHROOT_DIR}/run"

    # Копируем только нужные скрипты
    cp "${ROOT_DIR}/scripts/base/minimal-packages.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/base/install-kernel.sh" "${CHROOT_DIR}/root/"
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

    # Установка ядра (отдельным скриптом)
    log "Установка ядра Linux..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/install-kernel.sh"

    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-distro-info.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-bootloader.sh"

    if ! have_boot_artifacts; then
      log "Ядро или initrd отсутствуют после install-kernel.sh. Пробуем восстановить..."
      chroot "${CHROOT_DIR}" /bin/bash -c "apt-get install -y --reinstall linux-generic initramfs-tools linux-firmware"
      chroot "${CHROOT_DIR}" /bin/bash -c "update-initramfs -u -k all"
    fi

    have_boot_artifacts || die "После установки ядра /boot всё ещё пустой. Проверьте apt-логи внутри chroot."

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
    cleanup_mounts

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
    mkdir -p "${IMAGE_DIR}/boot/grub/i386-pc"
    mkdir -p "${IMAGE_DIR}/boot/grub/x86_64-efi"
    mkdir -p "${IMAGE_DIR}/casper"

    # Копирование ядра (используем относительные пути для casper)
    log "Копирование ядра и initrd..."

    # Проверяем что есть в chroot/boot
    log "Содержимое chroot/boot:"
    ls -lh "${CHROOT_DIR}/boot/" 2>/dev/null || log "WARNING: chroot/boot не существует"

    KERNEL_FOUND="$(latest_kernel_path)"
    INITRD_FOUND="$(latest_initrd_path)"

    [[ -n "${KERNEL_FOUND}" ]] && log "Найдено ядро: ${KERNEL_FOUND}"
    [[ -n "${INITRD_FOUND}" ]] && log "Найден initrd: ${INITRD_FOUND}"

    # Копируем если нашли
    if [[ -n "${KERNEL_FOUND}" ]] && [[ -n "${INITRD_FOUND}" ]]; then
        cp "${KERNEL_FOUND}" "${IMAGE_DIR}/casper/vmlinuz"
        cp "${INITRD_FOUND}" "${IMAGE_DIR}/casper/initrd"
        # Также копируем в boot для совместимости
        cp "${IMAGE_DIR}/casper/vmlinuz" "${IMAGE_DIR}/boot/vmlinuz"
        cp "${IMAGE_DIR}/casper/initrd" "${IMAGE_DIR}/boot/initrd"
        log "Ядро и initrd скопированы в casper/ и boot/"
    else
        log "ERROR: Ядро или initrd не найдены!"
        log "Возможные причины:"
        log "  1. Ядро не установилось в chroot (ошибка apt/dpkg внутри install-kernel.sh)"
        log "  2. Initramfs не обновился после установки ядра"
        log "  3. /dev, /dev/pts или /run были недоступны внутри chroot"
        log ""
        log "Попробуйте вручную установить ядро в chroot:"
        log "  chroot ${CHROOT_DIR} apt-get install -y linux-generic initramfs-tools linux-firmware"
        log "  chroot ${CHROOT_DIR} update-initramfs -u -k all"
        die "Сборка прервана: ядро не найдено"
    fi

    log "Копирование модулей GRUB для графического меню..."
    if [[ -d "/usr/lib/grub/i386-pc" ]]; then
      cp -r /usr/lib/grub/i386-pc/*.mod "${IMAGE_DIR}/boot/grub/i386-pc/" 2>/dev/null || true
    fi
    if [[ -d "/usr/lib/grub/x86_64-efi" ]]; then
      cp -r /usr/lib/grub/x86_64-efi/*.mod "${IMAGE_DIR}/boot/grub/x86_64-efi/" 2>/dev/null || true
    fi

    # Шаг 7: Конфиг GRUB
    log "Шаг 7: Настройка GRUB..."

    # Копируем шрифт для GRUB (если есть в системе)
    log "Копирование шрифта GRUB..."
    mkdir -p "${IMAGE_DIR}/boot/grub/fonts"
    if [[ -f /usr/share/grub/unicode.pf2 ]]; then
      cp /usr/share/grub/unicode.pf2 "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2"
    elif command -v grub-mkfont >/dev/null 2>&1; then
      # Пробуем создать шрифт из системных
      for font in /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf \
                  /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
                  /usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf; do
        if [[ -f "$font" ]]; then
          grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 "$font" 2>/dev/null && break || true
        fi
      done
    fi

    # Создаём тему GRUB
    log "Создание темы GRUB..."
    mkdir -p "${IMAGE_DIR}/boot/grub/themes/vibecode"
    cat > "${IMAGE_DIR}/boot/grub/themes/vibecode/theme.txt" << 'THEMEEOF'
title-text: ""
title-color: "#ffffff"
message-font: "DejaVu Sans:16"
message-color: "#ffffff"
+ boot_menu {
    left = 20%
    top = 20%
    width = 60%
    height = 60%
    item_height = 30px
    padding = 20px
    border = 0
    border_color = "#2c3e50"
    item_color = "#ffffff"
    selected_item_color = "#3498db"
    item_font = "DejaVu Sans:16"
    selected_item_font = "DejaVu Sans:bold:16"
}
THEMEEOF

    cat > "${IMAGE_DIR}/boot/grub/grub.cfg" << 'GRUBEOF'
set default=0
set timeout=10
set timeout_style=menu

# Загружаем шрифт и включаем графический режим
if loadfont ${prefix}/fonts/unicode.pf2 ; then
    set gfxmode=auto,1024x768,800x600,640x480
    insmod all_video
    insmod gfxterm
    terminal_output gfxterm
elif loadfont ${prefix}/fonts/DejaVuSans.pf2 ; then
    set gfxmode=auto,1024x768,800x600,640x480
    insmod all_video
    insmod gfxterm
    terminal_output gfxterm
else
    # Fallback на консоль если шрифт не загружен
    terminal_output console
fi

# Применяем тему (если есть)
if [ -f ${prefix}/themes/vibecode/theme.txt ]; then
    set theme=${prefix}/themes/vibecode/theme.txt
fi

# Safe video режим для VirtualBox и проблемных видеокарт
menuentry "VibeCode OS Minimal (Live)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false quiet ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (safe graphics)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false quiet splash ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false rescue ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (text mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false textmode ---
    initrd /casper/initrd
}
GRUBEOF

    # Шаг 8: Создание загрузочных образов GRUB
    log "Шаг 8: Создание загрузочных образов GRUB..."

    # Проверяем наличие GRUB файлов
    GRUB_MBR="/usr/lib/grub/i386-pc/boot_hybrid.img"
    if [[ ! -f "${GRUB_MBR}" ]]; then
      GRUB_MBR="/usr/lib/grub/i386-pc/boot.img"
    fi
    if [[ ! -f "${GRUB_MBR}" ]]; then
      die "Не найден GRUB MBR (boot_hybrid.img или boot.img). Установите grub-pc-bin."
    fi

    # Создаём embed-конфиг для GRUB
    GRUB_EMBED_CFG="$(mktemp)"
    cat > "${GRUB_EMBED_CFG}" << 'GRUBEMBEDEOF'
set echo=1
echo "Searching for GRUB config (Minimal ISO)..."
set root=
search --no-floppy --file --set=root /boot/grub/grub.cfg
if [ -z "$root" ]; then
    search --no-floppy --file --set=root /casper/vmlinuz
fi
if [ -z "$root" ]; then
    search --no-floppy --label --set=root VibeCodeMinimal
fi
if [ -f ($root)/boot/grub/grub.cfg ]; then
    echo "Found config on $root"
    set prefix=($root)/boot/grub
    configfile $prefix/grub.cfg
else
    echo "Config not found! Dropping to shell."
    ls ($root)/
    ls ($root)/boot/grub/
fi
GRUBEMBEDEOF

    # --- BIOS boot image ---
    log "Создание BIOS boot image..."
    # Для i386-pc в режиме CD/DVD (El Torito) часто лучше использовать grub-mkstandalone
    # создающий полный образ, включая cdboot.img
    grub-mkstandalone \
      --format=i386-pc \
      --output="${WORK_DIR}/core.img" \
      --install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_label tar ls part_gpt part_msdos fat ntfs configfile loopback gfxterm all_video font png jpeg gettext gfxmenu" \
      --modules="linux normal iso9660 biosdisk search search_fs_file search_label configfile part_gpt part_msdos fat gfxterm all_video font png jpeg gfxmenu" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=${GRUB_EMBED_CFG}"

    # Для El Torito i386-pc нам нужен cdboot.img в начале
    if [[ -f "/usr/lib/grub/i386-pc/cdboot.img" ]]; then
      cat /usr/lib/grub/i386-pc/cdboot.img "${WORK_DIR}/core.img" > "${IMAGE_DIR}/boot/grub/bios.img"
    else
      die "Не найден /usr/lib/grub/i386-pc/cdboot.img. Установите grub-pc-bin."
    fi

    # --- UEFI boot image ---
    log "Создание UEFI boot image..."

    # Создаём временную директорию для EFI образа с темой и шрифтами
    EFI_TEMP_DIR="$(mktemp -d)"
    mkdir -p "${EFI_TEMP_DIR}/boot/grub/fonts"
    mkdir -p "${EFI_TEMP_DIR}/boot/grub/themes/vibecode"

    # Копируем шрифты
    if [[ -f "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2" ]]; then
      cp "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2" "${EFI_TEMP_DIR}/boot/grub/fonts/"
    fi
    if [[ -f "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" ]]; then
      cp "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" "${EFI_TEMP_DIR}/boot/grub/fonts/"
    fi

    # Копируем тему
    if [[ -f "${IMAGE_DIR}/boot/grub/themes/vibecode/theme.txt" ]]; then
      cp "${IMAGE_DIR}/boot/grub/themes/vibecode/theme.txt" "${EFI_TEMP_DIR}/boot/grub/themes/vibecode/"
    fi

    # Копируем основной grub.cfg для EFI
    cp "${IMAGE_DIR}/boot/grub/grub.cfg" "${EFI_TEMP_DIR}/boot/grub/"

    grub-mkstandalone \
      --format=x86_64-efi \
      --output="${WORK_DIR}/bootx64.efi" \
      --install-modules="linux normal iso9660 search search_fs_file search_label tar ls part_gpt part_msdos fat ntfs configfile loopback gfxterm all_video font png jpeg gettext gfxmenu" \
      --modules="linux normal iso9660 search search_fs_file search_label configfile part_gpt part_msdos fat gfxterm all_video font png jpeg gfxmenu" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=${GRUB_EMBED_CFG}"

    # Создаём FAT-образ EFI System Partition
    EFI_IMG="${IMAGE_DIR}/boot/grub/efi.img"
    mkdir -p "${IMAGE_DIR}/EFI/boot"
    dd if=/dev/zero of="${EFI_IMG}" bs=1M count=4 2>/dev/null
    mkfs.vfat "${EFI_IMG}" 2>/dev/null
    mmd -i "${EFI_IMG}" ::/EFI ::/EFI/boot
    mcopy -i "${EFI_IMG}" "${WORK_DIR}/bootx64.efi" ::/EFI/boot/bootx64.efi

    # Копируем EFI-загрузчик в дерево ISO
    cp "${WORK_DIR}/bootx64.efi" "${IMAGE_DIR}/EFI/boot/bootx64.efi"

    # Очищаем временную директорию
    rm -rf "${EFI_TEMP_DIR}"

    rm -f "${GRUB_EMBED_CFG}"

    # Шаг 9: Создание ISO через xorriso (BIOS + UEFI hybrid)
    log "Шаг 9: Создание ISO..."

    xorriso -as mkisofs \
      -iso-level 3 \
      -full-iso9660-filenames \
      -volid "VibeCodeMinimal" \
      -output "${ISO_OUTPUT}" \
      --grub2-mbr "${GRUB_MBR}" \
      --mbr-force-bootable \
      -partition_offset 16 \
      -isohybrid-mbr "${GRUB_MBR}" \
      -isohybrid-gpt-basdat \
      -b boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --grub2-boot-info \
      -eltorito-alt-boot \
      -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
      -append_partition 2 0xef "${EFI_IMG}" \
      "${IMAGE_DIR}" \
      || die "Ошибка при создании ISO"

    log "✅ Minimal ISO собран: ${ISO_OUTPUT}"
    trap - EXIT
    ;;

  *)
    die "Неизвестный BUILD_MODE='${BUILD_MODE}'. Допустимо: dry-run|full"
    ;;
esac
