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

    REUSE_CHROOT=0
    if [[ "${KEEP_CHROOT:-0}" == "1" ]] && [[ -d "${CHROOT_DIR}/etc" ]] && have_boot_artifacts; then
      REUSE_CHROOT=1
      log "KEEP_CHROOT=1: используем существующий chroot и пропускаем bootstrap/apt-шаги"
    fi

    if [[ ${REUSE_CHROOT} -eq 0 ]]; then
      # Шаг 1: Bootstrap
      if [[ ! -d "${CHROOT_DIR}/etc" ]]; then
        log "Шаг 1: Bootstrap Ubuntu 24.04..."
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

      # === КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Пересоздание initrd с casper для live-образа ===
      log "Пересоздание initrd с casper для live-образа..."

      # Создаём symlink /sbin/init для systemd
      chroot "${CHROOT_DIR}" /bin/bash -c '
        if [ ! -e /sbin/init ]; then
          ln -sf /lib/systemd/systemd /sbin/init
        fi
      '

      # Получаем версию ядра
      KERNEL_VERSION=$(chroot "${CHROOT_DIR}" ls /lib/modules/ | head -n 1)
      log "Версия ядра: ${KERNEL_VERSION}"

      # === Конфигурация initramfs для casper ===
      log "Настройка initramfs для casper..."
      
      # Создаём conf.d/casper.conf для включения casper hook
      chroot "${CHROOT_DIR}" /bin/bash -c "
        mkdir -p /etc/initramfs-tools/conf.d
        echo 'BOOT=casper' > /etc/initramfs-tools/conf.d/casper.conf
        echo 'CASPERFLAGS=\"noprompt\"' >> /etc/initramfs-tools/conf.d/casper.conf
      "
      
      # Добавляем необходимые модули для live-системы
      chroot "${CHROOT_DIR}" /bin/bash -c "
        mkdir -p /etc/initramfs-tools/modules
        cat >> /etc/initramfs-tools/modules << 'MODULES'
overlay
squashfs
loop
aufs
MODULES
      "

      # Генерируем initrd (стандартный hook из пакета casper автоматически включается)
      log "Генерация initrd..."
      chroot "${CHROOT_DIR}" /bin/bash -c "update-initramfs -u -k ${KERNEL_VERSION}" || die "Ошибка update-initramfs"

      # Используем правильное имя initrd для этой версии ядра
      INITRD_BASE="initrd.img-${KERNEL_VERSION}"
      log "Initrd: ${INITRD_BASE}"

      # Проверяем что initrd существует
      if ! chroot "${CHROOT_DIR}" test -f "/boot/${INITRD_BASE}"; then
        die "initrd не был создан: /boot/${INITRD_BASE}"
      fi

      if chroot "${CHROOT_DIR}" lsinitramfs "/boot/${INITRD_BASE}" 2>/dev/null | grep -q "scripts/casper"; then
        log "OK: initrd содержит casper скрипты"
      else
        log "WARNING: initrd не содержит scripts/casper — проверяем casper hook"
        # Пробуем пересоздать с явным указанием casper
        chroot "${CHROOT_DIR}" /bin/bash -c "
          echo 'BOOT=casper' > /etc/initramfs-tools/conf.d/casper.conf
          update-initramfs -u -k ${KERNEL_VERSION}
        " || true
      fi

      # Обновляем symlink на initrd
      chroot "${CHROOT_DIR}" ln -sf "${INITRD_BASE}" /boot/initrd.img

      # === Проверка: systemd и /sbin/init ===
      log "Проверка /sbin/init..."
      chroot "${CHROOT_DIR}" /bin/bash -c '
        if [ ! -x /lib/systemd/systemd ]; then
          echo "ERROR: /lib/systemd/systemd не найден!"
          exit 1
        fi
        if [ ! -e /sbin/init ]; then
          ln -sf /lib/systemd/systemd /sbin/init
        fi
        echo "OK: /sbin/init -> $(readlink /sbin/init)"
      '

      chroot "${CHROOT_DIR}" /bin/bash -c "test -x /sbin/init" || die "В chroot отсутствует исполняемый /sbin/init"

      # Создание пользователя vibecode (casper использует его как шаблон)
      chroot "${CHROOT_DIR}" /bin/bash -c '
        if ! id "vibecode" &>/dev/null; then
          useradd -m -s /bin/bash vibecode
          echo "vibecode:vibecode" | chpasswd
          usermod -a -G sudo vibecode
        fi
      '

      log "Генерация manifest для live-образа..."
      mkdir -p "${IMAGE_DIR}/casper"
      chroot "${CHROOT_DIR}" dpkg-query -W -f='${Package} ${Version}\n' > "${IMAGE_DIR}/casper/filesystem.manifest"
      cp "${IMAGE_DIR}/casper/filesystem.manifest" "${IMAGE_DIR}/casper/filesystem.manifest-remove"

      chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/cleanup.sh"

      # Шаг 4: Размонтирование
      log "Шаг 4: Размонтирование..."
      cleanup_mounts
    else
      log "Пропускаем шаги 1-4 и переходим к пересборке образа"
      [[ -x "${CHROOT_DIR}/sbin/init" ]] || die "KEEP_CHROOT=1, но в chroot нет /sbin/init. Нужен полный прогон без KEEP_CHROOT."
    fi

    # Шаг 5: SquashFS
    log "Шаг 5: Создание SquashFS..."
    mkdir -p "${IMAGE_DIR}/casper"
    rm -f "${IMAGE_DIR}/casper/filesystem.squashfs"
    mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" \
      -comp zstd \
      -e boot proc sys dev run tmp

    # Шаг 6: Подготовка ISO структуры
    log "Шаг 6: Подготовка структуры ISO..."
    mkdir -p "${IMAGE_DIR}/casper"
    mkdir -p "${IMAGE_DIR}/boot/grub"
    mkdir -p "${IMAGE_DIR}/boot/grub/i386-pc"
    mkdir -p "${IMAGE_DIR}/boot/grub/x86_64-efi"
    mkdir -p "${IMAGE_DIR}/.disk"
    mkdir -p "${IMAGE_DIR}/EFI/boot"

    # Копирование ядра и initrd
    log "Копирование ядра и initrd..."

    KERNEL_FOUND="$(latest_kernel_path)"
    INITRD_FOUND="$(latest_initrd_path)"

    [[ -n "${KERNEL_FOUND}" ]] && log "Найдено ядро: ${KERNEL_FOUND}"
    [[ -n "${INITRD_FOUND}" ]] && log "Найден initrd: ${INITRD_FOUND}"

    if [[ -n "${KERNEL_FOUND}" ]] && [[ -n "${INITRD_FOUND}" ]]; then
        cp "${KERNEL_FOUND}" "${IMAGE_DIR}/casper/vmlinuz"
        cp "${INITRD_FOUND}" "${IMAGE_DIR}/casper/initrd"
        cp "${IMAGE_DIR}/casper/vmlinuz" "${IMAGE_DIR}/boot/vmlinuz"
        cp "${IMAGE_DIR}/casper/initrd" "${IMAGE_DIR}/boot/initrd.img"
        log "Ядро и initrd скопированы в casper/ и boot/"
    else
        log "ERROR: Ядро или initrd не найдены!"
        log "Возможные причины:"
        log "  1. Ядро не установилось в chroot"
        log "  2. Initramfs не обновился после установки ядра"
        die "Сборка прервана: ядро не найдено"
    fi

    log "Подготовка метаданных live-образа..."
    du -sx "${CHROOT_DIR}" --block=1M | awk '{print $1}' > "${IMAGE_DIR}/casper/filesystem.size"
    echo "VibeCode OS Minimal" > "${IMAGE_DIR}/.disk/info"
    echo "system" > "${IMAGE_DIR}/.disk/cd_type"
    date > "${IMAGE_DIR}/.disk/build_time"
    echo "VibeCodeMinimal" > "${IMAGE_DIR}/.disk/ubuntu_dist"

    log "Копирование модулей GRUB..."
    if [[ -d "/usr/lib/grub/i386-pc" ]]; then
      cp -r /usr/lib/grub/i386-pc/*.mod "${IMAGE_DIR}/boot/grub/i386-pc/" 2>/dev/null || true
    fi
    if [[ -d "/usr/lib/grub/x86_64-efi" ]]; then
      cp -r /usr/lib/grub/x86_64-efi/*.mod "${IMAGE_DIR}/boot/grub/x86_64-efi/" 2>/dev/null || true
    fi

    # Шаг 7: Конфиг GRUB
    log "Шаг 7: Настройка GRUB..."

    log "Копирование шрифта GRUB..."
    mkdir -p "${IMAGE_DIR}/boot/grub/fonts"
    if [[ -f /usr/share/grub/unicode.pf2 ]]; then
      cp /usr/share/grub/unicode.pf2 "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2"
    elif command -v grub-mkfont >/dev/null 2>&1; then
      for font in /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf \
                  /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
                  /usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf; do
        if [[ -f "$font" ]]; then
          grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 "$font" 2>/dev/null && break || true
        fi
      done
    fi

    cat > "${IMAGE_DIR}/boot/grub/grub.cfg" << 'GRUBEOF'
set default=0
set timeout=10
set timeout_style=menu
set gfxpayload=text

terminal_output console

menuentry "VibeCode OS Minimal (Live)" {
    linux /casper/vmlinuz boot=casper noprompt quiet username=vibecode hostname=vibecode-minimal ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (Live - toram)" {
    linux /casper/vmlinuz boot=casper toram noprompt quiet username=vibecode hostname=vibecode-minimal ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (safe graphics)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset quiet username=vibecode hostname=vibecode-minimal ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt rescue username=vibecode hostname=vibecode-minimal ---
    initrd /casper/initrd
}

menuentry "VibeCode OS Minimal (debug mode)" {
    linux /casper/vmlinuz boot=casper noprompt debug break=bottom username=vibecode hostname=vibecode-minimal ---
    initrd /casper/initrd
}
GRUBEOF

    # Шаг 8: Создание загрузочных образов GRUB
    log "Шаг 8: Создание загрузочных образов GRUB..."

    GRUB_MBR="/usr/lib/grub/i386-pc/boot_hybrid.img"
    if [[ ! -f "${GRUB_MBR}" ]]; then
      GRUB_MBR="/usr/lib/grub/i386-pc/boot.img"
    fi
    if [[ ! -f "${GRUB_MBR}" ]]; then
      die "Не найден GRUB MBR. Установите grub-pc-bin."
    fi

    GRUB_EMBED_CFG="$(mktemp)"
    cat > "${GRUB_EMBED_CFG}" << 'GRUBEMBEDEOF'
set root=(cd)
set prefix=(cd)/boot/grub
if [ -f ${prefix}/grub.cfg ]; then
    configfile ${prefix}/grub.cfg
fi

search --set=root --file /boot/grub/grub.cfg
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
GRUBEMBEDEOF

    log "Создание BIOS boot image..."
    grub-mkstandalone \
      --format=i386-pc \
      --output="${WORK_DIR}/core.img" \
      --install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_label configfile part_gpt part_msdos fat all_video font" \
      --modules="linux normal iso9660 biosdisk search search_fs_file configfile part_gpt part_msdos fat all_video font" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=${GRUB_EMBED_CFG}"

    if [[ -f "/usr/lib/grub/i386-pc/cdboot.img" ]]; then
      cat /usr/lib/grub/i386-pc/cdboot.img "${WORK_DIR}/core.img" > "${IMAGE_DIR}/boot/grub/bios.img"
    else
      die "Не найден /usr/lib/grub/i386-pc/cdboot.img. Установите grub-pc-bin."
    fi

    log "Создание UEFI boot image..."
    EFI_TEMP_DIR="$(mktemp -d)"
    mkdir -p "${EFI_TEMP_DIR}/boot/grub/fonts"

    if [[ -f "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2" ]]; then
      cp "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2" "${EFI_TEMP_DIR}/boot/grub/fonts/"
    fi
    if [[ -f "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" ]]; then
      cp "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" "${EFI_TEMP_DIR}/boot/grub/fonts/"
    fi

    cp "${IMAGE_DIR}/boot/grub/grub.cfg" "${EFI_TEMP_DIR}/boot/grub/"

    grub-mkstandalone \
      --format=x86_64-efi \
      --output="${WORK_DIR}/bootx64.efi" \
      --install-modules="linux normal iso9660 search search_fs_file configfile part_gpt part_msdos fat all_video font" \
      --modules="linux normal iso9660 search search_fs_file configfile part_gpt part_msdos fat all_video font" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=${GRUB_EMBED_CFG}"

    EFI_IMG="${IMAGE_DIR}/boot/grub/efi.img"
    mkdir -p "${IMAGE_DIR}/EFI/boot"
    dd if=/dev/zero of="${EFI_IMG}" bs=1M count=4 2>/dev/null
    mkfs.vfat "${EFI_IMG}" 2>/dev/null
    mmd -i "${EFI_IMG}" ::/EFI ::/EFI/boot
    mcopy -i "${EFI_IMG}" "${WORK_DIR}/bootx64.efi" ::/EFI/boot/bootx64.efi

    cp "${WORK_DIR}/bootx64.efi" "${IMAGE_DIR}/EFI/boot/bootx64.efi"
    rm -rf "${EFI_TEMP_DIR}"
    rm -f "${GRUB_EMBED_CFG}"

    # Шаг 9: Создание ISO через xorriso (BIOS + UEFI hybrid)
    log "Шаг 9: Создание ISO..."

    xorriso -as mkisofs \
      -iso-level 3 \
      -r -V "VibeCodeMinimal" \
      -J -joliet-long \
      -o "${ISO_OUTPUT}" \
      --grub2-mbr "${GRUB_MBR}" \
      --mbr-force-bootable \
      -partition_offset 16 \
      -b boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --grub2-boot-info \
      -eltorito-alt-boot \
      -e boot/grub/efi.img \
        -no-emul-boot \
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
