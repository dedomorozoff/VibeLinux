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
  [[ -f "$path" ]] || die "Не найден файл: ${path#"$ROOT_DIR"/}"
}
need_dir() {
  local path="$1"
  [[ -d "$path" ]] || die "Не найден каталог: ${path#"$ROOT_DIR"/}"
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
    need_file "${ROOT_DIR}/scripts/base/setup-distro-info.sh"
    need_file "${ROOT_DIR}/scripts/base/setup-bootloader.sh"
    need_file "${ROOT_DIR}/scripts/desktop/install-mate.sh"
    need_file "${ROOT_DIR}/scripts/desktop/configure-mate-panel.sh"
    need_file "${ROOT_DIR}/scripts/desktop/setup-installer.sh"
    need_file "${ROOT_DIR}/scripts/desktop/apply-branding.sh"
    need_file "${ROOT_DIR}/scripts/drivers/install-nvidia.sh"
    
    # Брендинг
    need_dir "${ROOT_DIR}/branding"

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

    # Поддержка KEEP_CHROOT для экономии времени при повторной сборке
    # Проверяем, что chroot валидный (есть /root, /etc)
    CHROOT_VALID=0
    if [[ -d "${CHROOT_DIR}/root" ]] && [[ -d "${CHROOT_DIR}/etc" ]]; then
      CHROOT_VALID=1
    fi
    
    if [[ "${KEEP_CHROOT:-0}" == "1" ]] && [[ ${CHROOT_VALID} -eq 1 ]]; then
      log "Шаг 1: Пропускаем bootstrap (KEEP_CHROOT=1, chroot валидный)"
    else
      if [[ "${KEEP_CHROOT:-0}" == "1" ]] && [[ ${CHROOT_VALID} -eq 0 ]]; then
        log "ВНИМАНИЕ: KEEP_CHROOT=1, но chroot неполный. Пересоздаём..."
      fi
      # Сначала размонтируем, если что-то осталось от предыдущей сборки
      log "Шаг 1: Очистка предыдущей сборки..."
      # Агрессивное размонтирование
      umount -l -f "${CHROOT_DIR}/proc" 2>/dev/null || true
      umount -l -f "${CHROOT_DIR}/sys" 2>/dev/null || true
      umount -l -f "${CHROOT_DIR}/dev" 2>/dev/null || true
      umount -l -f "${CHROOT_DIR}/dev/pts" 2>/dev/null || true
      
      # Удаляем старый chroot (игнорируем ошибки)
      rm -rf "${CHROOT_DIR}" 2>/dev/null || true
      # Если не удалось удалить — пробуем ещё раз после небольшой паузы
      if [[ -d "${CHROOT_DIR}" ]]; then
        sleep 1
        rm -rf "${CHROOT_DIR}" 2>/dev/null || true
      fi
      
      # Bootstrap Ubuntu 24.04 в chroot
      log "Шаг 1: Bootstrap Ubuntu 24.04 (noble) в ${CHROOT_DIR}"
      debootstrap --arch=amd64 noble "${CHROOT_DIR}" http://archive.ubuntu.com/ubuntu
    fi

    # Шаг 2: Настройка chroot
    log "Шаг 2: Настройка chroot"
    # Сначала размонтируем, если уже примонтировано (от предыдущей сборки)
    umount -l "${CHROOT_DIR}/proc" 2>/dev/null || true
    umount -l "${CHROOT_DIR}/sys" 2>/dev/null || true
    umount -l "${CHROOT_DIR}/dev" 2>/dev/null || true
    
    mount -t proc proc "${CHROOT_DIR}/proc"
    mount -t sysfs sys "${CHROOT_DIR}/sys"
    mount -o bind /dev "${CHROOT_DIR}/dev"

    # Шаг 3: Установка базовых пакетов
    log "Шаг 3: Установка базовых пакетов"
    cp "${ROOT_DIR}/scripts/base/base-packages.sh" "${CHROOT_DIR}/root/base-packages.sh"
    cp "${ROOT_DIR}/scripts/base/cleanup.sh" "${CHROOT_DIR}/root/cleanup.sh"
    cp "${ROOT_DIR}/scripts/base/setup-distro-info.sh" "${CHROOT_DIR}/root/setup-distro-info.sh"
    cp "${ROOT_DIR}/scripts/base/setup-bootloader.sh" "${CHROOT_DIR}/root/setup-bootloader.sh"
    cp "${ROOT_DIR}/scripts/desktop/install-mate.sh" "${CHROOT_DIR}/root/install-mate.sh"
    cp "${ROOT_DIR}/scripts/desktop/configure-mate-panel.sh" "${CHROOT_DIR}/root/configure-mate-panel.sh"
    cp "${ROOT_DIR}/scripts/desktop/setup-installer.sh" "${CHROOT_DIR}/root/setup-installer.sh"
    cp "${ROOT_DIR}/scripts/desktop/apply-branding.sh" "${CHROOT_DIR}/root/apply-branding.sh"
    cp "${ROOT_DIR}/scripts/drivers/install-nvidia.sh" "${CHROOT_DIR}/root/install-nvidia.sh"
    
    # Копируем брендинг
    if [[ -d "${ROOT_DIR}/branding" ]]; then
      log "Копирование брендинга в chroot..."
      cp -r "${ROOT_DIR}/branding" "${CHROOT_DIR}/root/"
    fi
    
    # Делаем скрипты исполняемыми
    chmod +x "${CHROOT_DIR}/root"/*.sh

    # На всякий случай нормализуем окончания строк у скриптов в chroot (убираем CRLF),
    # чтобы избежать '/usr/bin/env: bash\r' даже если где-то просочился Windows-формат
    chroot "${CHROOT_DIR}" /bin/bash -c "
      if command -v sed >/dev/null 2>&1; then
        for f in /root/*.sh; do
          [ -f \"\$f\" ] && sed -i 's/\r$//' \"\$f\" || true
        done
      fi
    "

    # Установка переменных для избежания интерактивных запросов
    export DEBIAN_FRONTEND=noninteractive

    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/base-packages.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-distro-info.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-bootloader.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/cleanup.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/install-mate.sh"
    
    # Настройка autologin для live сессии
    log "Настройка autologin и локали..."
    
    # Устанавливаем русскую локаль
    chroot "${CHROOT_DIR}" /bin/bash -c '
      DEBIAN_FRONTEND=noninteractive apt-get install -y language-pack-ru-base
      locale-gen ru_RU.UTF-8
    '
    
    # Настройка системной локали по умолчанию
    echo "LANG=ru_RU.UTF-8" > "${CHROOT_DIR}/etc/default/locale"
    echo "LANGUAGE=ru_RU.UTF-8" >> "${CHROOT_DIR}/etc/default/locale"
    
    # Создаём пользователя vibecode если его нет
    chroot "${CHROOT_DIR}" /bin/bash -c '
      if ! id "vibecode" &>/dev/null; then
        useradd -m -s /bin/bash vibecode
        echo "vibecode:vibecode" | chpasswd
        usermod -a -G sudo vibecode 2>/dev/null || true
      fi
    '
    
    # Настройка LightDM для autologin - полное отключение greeter
    mkdir -p "${CHROOT_DIR}/etc/lightdm"
    cat > "${CHROOT_DIR}/etc/lightdm/lightdm.conf" << 'LIGHTDMEOF'
[Seat:*]
autologin-user=vibecode
autologin-user-timeout=0
autologin-guest=false
allow-guest=false
greeter-session=
user-session=mate
LIGHTDMEOF
    
    # Настройка пользовательских настроек MATE
    log "Настройка MATE панели..."
    
    # Создаём директорию для настроек
    mkdir -p "${CHROOT_DIR}/home/vibecode/.config/mate-panel"
    mkdir -p "${CHROOT_DIR}/home/vibecode/.config/dconf"
    
    # Dconf настройки для MATE - часы с датой (пропускаем, настроим позже)
    # Настройки панели будут применены при первом входе пользователя
    
    # Создаём backup настроек панели
    cat > "${CHROOT_DIR}/home/vibecode/.config/mate-panel/default-layout" << 'MATEPANELEOF'
[top]
orientation=bottom
size=24
expand=true
auto-hide=false

[Object:clock]
applet-iid=ClockAppletFactory::ClockApplet
toplevel=top
position=1000
clock-format=24h
clock-show-date=true
MATEPANELEOF

    # Устанавливаем права на файлы настроек
    chroot "${CHROOT_DIR}" /bin/bash -c '
      chown -R vibecode:vibecode /home/vibecode
    '
    
    # Настройка панели MATE
    log "Настройка панели MATE..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/configure-mate-panel.sh vibecode"
    
    # Установка и настройка установщика
    log "Установка установщика (ubiquity)..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-installer.sh"
    
    # Применение брендинга
    log "Применение брендинга VibeCode OS..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/apply-branding.sh /root/branding vibecode"

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
    mkdir -p "${IMAGE_DIR}/boot/grub/x86_64-efi"
    mkdir -p "${IMAGE_DIR}/boot/grub/fonts"
    mkdir -p "${IMAGE_DIR}/boot/grub/i386-pc"
    mkdir -p "${IMAGE_DIR}/casper"
    mkdir -p "${IMAGE_DIR}/.disk"
    mkdir -p "${IMAGE_DIR}/EFI"
    mkdir -p "${IMAGE_DIR}/EFI/boot"
    mkdir -p "${IMAGE_DIR}/boot"
    
    # Копируем модули GRUB для графики
    log "Копирование модулей GRUB..."
    if [[ -d "/usr/lib/grub/x86_64-efi" ]]; then
      cp -r /usr/lib/grub/x86_64-efi/*.mod "${IMAGE_DIR}/boot/grub/x86_64-efi/" 2>/dev/null || true
    fi
    if [[ -d "/usr/lib/grub/i386-pc" ]]; then
      cp -r /usr/lib/grub/i386-pc/*.mod "${IMAGE_DIR}/boot/grub/i386-pc/" 2>/dev/null || true
    fi
    
    # Устанавливаем темы GRUB
    log "Установка тем GRUB..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y grub2-themes-" 2>/dev/null || true
    
    # Создаём шрифт для GRUB
    log "Создание шрифта GRUB..."
    if command -v grub-mkfont >/dev/null 2>&1; then
      # Пробуем разные источники шрифтов
      if [[ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]]; then
        grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf 2>/dev/null || true
      fi
      if [[ -f /usr/share/grub/unicode.pf2 ]]; then
        cp /usr/share/grub/unicode.pf2 "${IMAGE_DIR}/boot/grub/fonts/" 2>/dev/null || true
      fi
    fi
    
    # Создаём графическую тему для GRUB
    log "Создание темы GRUB..."
    mkdir -p "${IMAGE_DIR}/boot/grub/themes/vibecode"
    
    # Простой theme.txt для GRUB
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
    selected_item_pixmap = "selected.png"
    
    item_font = "DejaVu Sans:16"
    selected_item_font = "DejaVu Sans:bold:16"
}
THEMEEOF

    # Создаём простой pixmap для выбранного элемента (чёрный прямоугольник)
    mkdir -p "${IMAGE_DIR}/boot/grub/themes/vibecode"
    
    # Копируем стандартные изображения если есть
    if [[ -d "/usr/share/grub/themes" ]]; then
      cp -r /usr/share/grub/themes/* "${IMAGE_DIR}/boot/grub/themes/" 2>/dev/null || true
    fi

    # Создаём файл метаданных
    echo "VibeCode OS alpha" > "${IMAGE_DIR}/.disk/info"
    echo "system" > "${IMAGE_DIR}/.disk/cd_type"
    date > "${IMAGE_DIR}/.disk/build_time"
    echo "VibeCodeOS-alpha" > "${IMAGE_DIR}/.disk/ubuntu_dist"

    # Копируем ядро и initrd из chroot
    log "Копирование ядра и initrd..."
    if [[ -f "${CHROOT_DIR}/boot/vmlinuz" ]]; then
      cp "${CHROOT_DIR}/boot/vmlinuz" "${IMAGE_DIR}/boot/vmlinuz"
    else
      # Ищем первое подходящее ядро по шаблону vmlinuz-*
      kernel_candidates=( "${CHROOT_DIR}"/boot/vmlinuz-* )
      if [[ -n "${kernel_candidates[0]:-}" && -f "${kernel_candidates[0]}" ]]; then
        cp "${kernel_candidates[0]}" "${IMAGE_DIR}/boot/vmlinuz"
      else
        die "Не удалось найти ядро vmlinuz в chroot/boot"
      fi
    fi
    
    if [[ -f "${CHROOT_DIR}/boot/initrd.img" ]]; then
      cp "${CHROOT_DIR}/boot/initrd.img" "${IMAGE_DIR}/boot/initrd.img"
    else
      # Ищем первое подходящее initrd по шаблону initrd.img-*
      initrd_candidates=( "${CHROOT_DIR}"/boot/initrd.img-* )
      if [[ -n "${initrd_candidates[0]:-}" && -f "${initrd_candidates[0]}" ]]; then
        cp "${initrd_candidates[0]}" "${IMAGE_DIR}/boot/initrd.img"
      else
        die "Не удалось найти initrd в chroot/boot"
      fi
    fi

    # Создаём конфигурацию GRUB (чисто текстовый режим для максимальной совместимости)
    log "Создание конфигурации GRUB..."
    cat > "${IMAGE_DIR}/boot/grub/grub.cfg" << 'GRUBEOF'
set default=0
set timeout=10
set timeout_style=menu
terminal_output console
menuentry "VibeCode OS (Live)" {
    echo "Loading kernel..."
    linux /boot/vmlinuz boot=casper noprompt splash --
    echo "Loading initrd..."
    initrd /boot/initrd.img
}
menuentry "VibeCode OS Live Try" {
    echo "Loading kernel..."
    linux /boot/vmlinuz boot=casper only-ubiquity --
    echo "Loading initrd..."
    initrd /boot/initrd.img
}
GRUBEOF

    # Конфиг для EFI (также в текстовом режиме)
    cat > "${IMAGE_DIR}/boot/grub/x86_64-efi/grub.cfg" << 'EOF'
set default=0
set timeout=10
set timeout_style=menu
terminal_output console

menuentry "VibeCode OS (Live)" {
    linux /boot/vmlinuz boot=casper noprompt splash --
    initrd /boot/initrd.img
}

menuentry "VibeCode OS (Live - Try VibeCode OS without installing)" {
    linux /boot/vmlinuz boot=casper only-ubiquity --
    initrd /boot/initrd.img
}
EOF

    # Шаг 7: Подготовка файлов для casper
    log "Шаг 7: Подготовка файлов для casper..."
    
    # Устанавливаем squashfs в chroot для генерации squashfs подержки в initrd
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y squashfs-tools casper" || true
    
    # Создаём файл с размером squashfs
    du -sx "${CHROOT_DIR}" --block=1M | awk '{print $1}' > "${IMAGE_DIR}/casper/filesystem.size"
    
    # Создаём файл манифеста
    # shellcheck disable=SC2016  # шаблон формата обрабатывается dpkg-query, а не shell
    chroot "${CHROOT_DIR}" dpkg-query -W -f='${Package} ${Version}\n' > "${IMAGE_DIR}/casper/filesystem.manifest" || true
    cp "${IMAGE_DIR}/casper/filesystem.manifest" "${IMAGE_DIR}/casper/filesystem.manifest-remove"

    # Создаём файлы для EFI
    # Т.к. grub-mkrescue не включает ядро автоматически, нужно подготовить загрузчик иначе
    # Используем более простой подход с созданием boot файлов

    # Шаг 8: Создание ISO через grub-mkrescue
    log "Шаг 8: Создание ISO с grub-mkrescue"
    
    # Добавляем пустую директорию для boot, чтобы избежать ошибки
    touch "${IMAGE_DIR}/boot/grub/grub.cfg"
    
    grub-mkrescue -o "${ISO_OUTPUT}" "${IMAGE_DIR}" --compress=xz || die "Ошибка при создании ISO"

    log "✅ ISO собран: ${ISO_OUTPUT}"
    log "Проверьте файл: ${ISO_OUTPUT}"
    ;;

  *)
    die "Неизвестный BUILD_MODE='${BUILD_MODE}'. Допустимо: dry-run|full"
    ;;
esac

