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

install_deps() {
  log "Проверка и установка недостающих зависимостей (debootstrap, squashfs-tools, xorriso, grub-common, mtools)..."
  local deps=()
  command -v debootstrap >/dev/null 2>&1 || deps+=(debootstrap)
  command -v mksquashfs >/dev/null 2>&1 || deps+=(squashfs-tools)
  command -v xorriso >/dev/null 2>&1 || deps+=(xorriso)
  command -v grub-mkstandalone >/dev/null 2>&1 || deps+=(grub-common)
  command -v mkfs.vfat >/dev/null 2>&1 || deps+=(dosfstools)
  command -v mcopy >/dev/null 2>&1 || deps+=(mtools)

  if [ ${#deps[@]} -ne 0 ]; then
    log "Установка: ${deps[*]}"
    
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y "${deps[@]}"
    elif command -v pacman >/dev/null 2>&1; then
      local pacman_deps=()
      for d in "${deps[@]}"; do
        case "$d" in
          debootstrap) pacman_deps+=(archiso) ;;
          squashfs-tools) pacman_deps+=(squashfs-tools) ;;
          xorriso) pacman_deps+=(xorriso) ;;
          grub-common) pacman_deps+=(grub) ;;
          dosfstools) pacman_deps+=(dosfstools) ;;
          mtools) pacman_deps+=(mtools) ;;
        esac
      done
      pacman -Sy --noconfirm "${pacman_deps[@]}"
    elif command -v dnf >/dev/null 2>&1; then
      dnf -y install "${deps[@]}"
    else
      die "Не найден пакетный менеджер (apt-get/pacman/dnf). Установите зависимости вручную."
    fi
  else
    log "Все зависимости на хосте уже установлены."
  fi
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
    need_cmd grub-mkstandalone
    need_cmd mkfs.vfat
    need_cmd mcopy
    need_cmd mformat

    # Базовая структура scripts/
    need_dir "${ROOT_DIR}/scripts"
    need_file "${ROOT_DIR}/scripts/base/base-packages.sh"
    need_file "${ROOT_DIR}/scripts/base/cleanup.sh"
    need_file "${ROOT_DIR}/scripts/base/setup-distro-info.sh"
    need_file "${ROOT_DIR}/scripts/base/setup-bootloader.sh"
    need_file "${ROOT_DIR}/scripts/desktop/install-i3wm.sh"
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
    install_deps

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
    cp "${ROOT_DIR}/scripts/desktop/install-i3wm.sh" "${CHROOT_DIR}/root/install-i3wm.sh"
    cp "${ROOT_DIR}/scripts/desktop/setup-installer.sh" "${CHROOT_DIR}/root/setup-installer.sh"
    cp "${ROOT_DIR}/scripts/desktop/apply-branding.sh" "${CHROOT_DIR}/root/apply-branding.sh"
    cp "${ROOT_DIR}/scripts/drivers/install-nvidia.sh" "${CHROOT_DIR}/root/install-nvidia.sh"

    need_file "${ROOT_DIR}/scripts/dev/chroot-configs/kitty.conf"
    need_file "${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json"
    need_file "${ROOT_DIR}/scripts/dev/configs/vscodium-extensions.txt"

    # Копируем брендинг
    if [[ -d "${ROOT_DIR}/branding" ]]; then
      log "Копирование брендинга в chroot..."
      cp -r "${ROOT_DIR}/branding" "${CHROOT_DIR}/root/"

      # Копируем конфиги в корень chroot для скриптов dev-стека
      if [[ -d "${ROOT_DIR}/branding/config" ]]; then
        log "Копирование конфигов в chroot..."
        cp -r "${ROOT_DIR}/branding/config" "${CHROOT_DIR}/root/"
      fi
    fi

    # Делаем скрипты исполняемыми
    chmod +x "${CHROOT_DIR}/root"/*.sh

    # На всякий случай нормализуем окончания строк у скриптов в chroot (убираем CRLF),
    # чтобы избежать '/usr/bin/env: bash\r' даже если где-то просочился Windows-формат
    chroot "${CHROOT_DIR}" /bin/bash -c "
      if command -v sed >/dev/null 2>&1; then
        for f in /root/*.sh; do
          [ -f \"\$f\" ] && sed -i 's/\\r$//' \"\$f\" || true
        done
      fi
    "

    # Установка необходимых пакетов для работы загрузчика GRUB и создания ISO (внутри chroot)
    log "Установка необходимых пакетов загрузчика в chroot..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y grub-common grub-pc-bin grub-efi-amd64-bin binutils xorriso"

    # Установка переменных для избежания интерактивных запросов
    export DEBIAN_FRONTEND=noninteractive

    # === КРИТИЧЕСКОЕ: Установка ядра в chroot ===
    # Ядро должно быть установлено ДО выполнения base-packages.sh
    log "Установка ядра Linux в chroot..."
    chroot "${CHROOT_DIR}" /bin/bash -c "
      DEBIAN_FRONTEND=noninteractive apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        linux-image-generic \
        linux-headers-generic \
        linux-modules-extra-generic \
        || true

      # Проверяем что ядро установлено
      if ls /lib/modules/*/vmlinuz 1>/dev/null 2>&1; then
        echo '✅ Ядро найдено: ' \$(ls -1 /lib/modules/ | head -n1)
      else
        echo '⚠️ Ядро не найдено после установки, пробуем конкретную версию...'
        # Попробуем установить конкретное ядро для Ubuntu 24.04
        KERNEL_PKG=\$(apt-cache search linux-image- | grep 'linux-image-[0-9]' | grep generic | head -n1 | cut -d' ' -f1)
        if [[ -n \"\$KERNEL_PKG\" ]]; then
          DEBIAN_FRONTEND=noninteractive apt-get install -y \"\$KERNEL_PKG\" || true
        fi
      fi
    "

    # Проверка что ядро установлено
    KERNEL_VER=$(chroot "${CHROOT_DIR}" bash -c 'ls -1 /lib/modules/ 2>/dev/null | head -n1')
    if [[ -z "$KERNEL_VER" ]]; then
      log "ERROR: Ядро не установлено в chroot"
      chroot "${CHROOT_DIR}" bash -c 'dpkg -l | grep linux-image || true'
      chroot "${CHROOT_DIR}" bash -c 'ls -la /lib/modules/ 2>/dev/null || echo "/lib/modules/ пуст или отсутствует"'
      die "Не найдено ядро в /lib/modules/ - проверьте установку ядра выше"
    fi
    log "✅ Ядро установлено: $KERNEL_VER"

    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/base-packages.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-distro-info.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-bootloader.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/cleanup.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/install-i3wm.sh"

    # === Критическая проверка: systemd и /sbin/init ===
    log "Проверка установки systemd и init-процесса..."
    chroot "${CHROOT_DIR}" /bin/bash -c '
      if [ ! -f /lib/systemd/systemd ]; then
        echo "ERROR: /lib/systemd/systemd не найден! Установка systemd..."
        apt-get install -y systemd systemd-sysv
      fi

      # Проверяем symlink /sbin/init
      if [ ! -e /sbin/init ]; then
        echo "Creating /sbin/init symlink to /lib/systemd/systemd"
        ln -sf /lib/systemd/systemd /sbin/init
      fi

      # Проверяем что symlink правильный
      if [ -L /sbin/init ]; then
        INIT_TARGET=$(readlink /sbin/init)
        echo "OK: /sbin/init -> $INIT_TARGET"
      else
        echo "WARNING: /sbin/init не является symlink"
      fi

      # Проверка что systemd исполняемый
      if [ -x /lib/systemd/systemd ]; then
        echo "OK: /lib/systemd/systemd исполняемый"
      else
        echo "ERROR: /lib/systemd/systemd не исполняемый!"
        exit 1
      fi
    '

    # Создаём пользователя vibecode ДО установки dev-инструментов
    log "Создание пользователя vibecode..."
    chroot "${CHROOT_DIR}" /bin/bash -c '
      if ! id "vibecode" &>/dev/null; then
        useradd -m -s /bin/bash vibecode
        echo "vibecode:vibecode" | chpasswd
        usermod -a -G sudo vibecode 2>/dev/null || true
      fi
    '

    # === Фаза 2: Code Forge (Инструменты разработки) ===
    log "Фаза 2: Установка инструментов разработки..."

    # Копируем скрипты dev-стека
    cp "${ROOT_DIR}/scripts/dev/setup-terminal.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/dev/setup-shell.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/dev/setup-langs.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/dev/setup-editors.sh" "${CHROOT_DIR}/root/"
    cp "${ROOT_DIR}/scripts/dev/setup-devtools.sh" "${CHROOT_DIR}/root/"
    chmod +x "${CHROOT_DIR}/root"/setup-*.sh

    # Конвертация CRLF в LF для dev-скриптов
    log "Конвертация окончаний строк в Unix-формат (dev-скрипты)..."
    chroot "${CHROOT_DIR}" /bin/bash -c "
      if command -v sed >/dev/null 2>&1; then
        for f in /root/setup-*.sh; do
          [ -f \"\$f\" ] && sed -i 's/\r$//' \"\$f\" || true
        done
      fi
    "

    # Копируем конфиги для VSCodium в chroot
    mkdir -p "${CHROOT_DIR}/root/configs"
    if [[ -f "${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json" ]]; then
      cp "${ROOT_DIR}/scripts/dev/configs/vscodium-settings.json" "${CHROOT_DIR}/root/configs/"
    fi
    if [[ -f "${ROOT_DIR}/scripts/dev/configs/vscodium-extensions.txt" ]]; then
      cp "${ROOT_DIR}/scripts/dev/configs/vscodium-extensions.txt" "${CHROOT_DIR}/root/configs/"
    fi

    # Установка терминала (Kitty + Zsh + Starship)
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-terminal.sh vibecode"

    # Установка оболочки (Zsh + Oh My Zsh + Starship)
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-shell.sh vibecode"

    # Установка языков программирования
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-langs.sh vibecode"

    # Установка редакторов (VSCodium, Neovim, Zed)
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-editors.sh vibecode"

    # Установка devtools (Git, lazygit, Docker)
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-devtools.sh vibecode"

    # Установка проприетарных драйверов NVIDIA
    log "Установка драйверов NVIDIA..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/install-nvidia.sh"

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

    # Настройка LightDM для autologin (i3wm)
    mkdir -p "${CHROOT_DIR}/etc/lightdm/lightdm.conf.d"
    cat > "${CHROOT_DIR}/etc/lightdm/lightdm.conf.d/vibecode.conf" << 'LIGHTDMEOF'
[Seat:*]
autologin-user=vibecode
autologin-user-timeout=0
user-session=i3

LIGHTDMEOF

    # Настройка пользовательских конфигов i3wm
    log "Настройка i3wm конфигурации..."

    # Создаём директорию для настроек i3
    mkdir -p "${CHROOT_DIR}/home/vibecode/.config/i3"
    mkdir -p "${CHROOT_DIR}/home/vibecode/.config/picom"
    mkdir -p "${CHROOT_DIR}/home/vibecode/.config/i3status"
    mkdir -p "${CHROOT_DIR}/home/vibecode/.config/kitty"

    # Копирование конфигураций из scripts/desktop/configs/
    if [[ -d "${ROOT_DIR}/scripts/desktop/configs/i3wm" ]]; then
      log "Копирование конфигурации i3wm..."
      cp -r "${ROOT_DIR}/scripts/desktop/configs/i3wm/"* "${CHROOT_DIR}/home/vibecode/.config/i3/"
    fi

    if [[ -d "${ROOT_DIR}/scripts/desktop/configs/i3status" ]]; then
      log "Копирование конфигурации i3status..."
      cp -r "${ROOT_DIR}/scripts/desktop/configs/i3status/"* "${CHROOT_DIR}/home/vibecode/.config/i3status/"
    fi

    if [[ -d "${ROOT_DIR}/scripts/desktop/configs/picom" ]]; then
      log "Копирование конфигурации picom..."
      cp -r "${ROOT_DIR}/scripts/desktop/configs/picom/"* "${CHROOT_DIR}/home/vibecode/.config/picom/"
    fi

    if [[ -d "${ROOT_DIR}/scripts/desktop/configs/kitty" ]]; then
      log "Копирование конфигурации Kitty..."
      cp -r "${ROOT_DIR}/scripts/desktop/configs/kitty/"* "${CHROOT_DIR}/home/vibecode/.config/kitty/"
    fi

    # Устанавливаем права на файлы настроек
    chroot "${CHROOT_DIR}" /bin/bash -c '
      chown -R vibecode:vibecode /home/vibecode/.config
    '

    # Установка и настройка установщика
    log "Установка установщика (ubiquity)..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-installer.sh"

    # Применение брендинга
    log "Применение брендинга VibeCode OS..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/apply-branding.sh /root/branding vibecode"

    # Устанавливаем casper для live-сессии (до размонтирования!)
    log "Установка casper для live-сессии..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y casper"

    # === КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Пересборка initrd с casper hook ===
    log "Пересборка initrd с casper hook для live-образа..."
    
    # Исправляем casper hook для копирования всех скриптов
    cat > "${CHROOT_DIR}/usr/share/initramfs-tools/hooks/casper" << 'CASPERHOOK'
#!/bin/sh -e
# initramfs hook for casper - FIXED version

PREREQS=""

prereqs()
{
       echo "$PREREQS"
}

case "$1" in
    prereqs)
       prereqs
       exit 0
       ;;
esac

. /usr/share/initramfs-tools/hook-functions

# DESTDIR устанавливается initramfs-tools автоматически
# Если не установлена, используем /tmp/initrd-workaround
DESTDIR="${DESTDIR:-}"
if [ -z "$DESTDIR" ]; then
    echo "WARNING: DESTDIR not set, using workaround"
    DESTDIR="/tmp/initrd-root"
    mkdir -p "$DESTDIR"
fi

manual_add_modules overlay

copy_exec /sbin/losetup /sbin
copy_exec /sbin/mkfs.ext4 /sbin
copy_exec /sbin/sfdisk /sbin

mkdir -p ${DESTDIR}/lib/casper
copy_exec /usr/share/casper/casper-reconfigure /bin
copy_exec /usr/share/casper/casper-preseed /bin
copy_exec /usr/share/casper/casper-set-selections /bin

mkdir -p ${DESTDIR}/lib/udev/rules.d
cp -p /lib/udev/rules.d/60-cdrom_id.rules ${DESTDIR}/lib/udev/rules.d/ 2>/dev/null || true
copy_exec /lib/udev/cdrom_id /lib/udev 2>/dev/null || true
copy_exec /usr/bin/eject /bin
copy_exec /sbin/swapon /sbin

if [ -x /sbin/mount.cifs ]; then
    copy_exec /sbin/mount.cifs /sbin
    for x in cifs md4 des_generic; do
        manual_add_modules ${x}
    done
fi

if [ -x /usr/bin/hmcdrvfs ]; then
    mkdir -p ${DESTDIR}/usr/bin
    copy_exec /usr/bin/hmcdrvfs /usr/bin
    manual_add_modules hmcdrv
fi

manual_add_modules squashfs
manual_add_modules loop
manual_add_modules vfat
manual_add_modules ext3
manual_add_modules ext4
manual_add_modules btrfs
manual_add_modules nls_cp437
manual_add_modules nls_utf8
manual_add_modules nls_iso8859-1
manual_add_modules sr_mod
manual_add_modules ide-cd
manual_add_modules sbp2
manual_add_modules ohci1394

# Копируем основные скрипты casper В ОБЯЗАТЕЛЬНОМ ПОРЯДКЕ
echo "[casper hook] Copying casper scripts to $DESTDIR/scripts/"
mkdir -p $DESTDIR/scripts

if [ -f /usr/share/initramfs-tools/scripts/casper ]; then
    cp /usr/share/initramfs-tools/scripts/casper $DESTDIR/scripts/
    chmod +x $DESTDIR/scripts/casper
    echo "[casper hook] OK: scripts/casper copied"
else
    echo "[casper hook] ERROR: /usr/share/initramfs-tools/scripts/casper not found!"
    ls -la /usr/share/initramfs-tools/scripts/ || true
fi

if [ -f /usr/share/initramfs-tools/scripts/casper-functions ]; then
    cp /usr/share/initramfs-tools/scripts/casper-functions $DESTDIR/scripts/
    echo "[casper hook] OK: scripts/casper-functions copied"
fi

if [ -f /usr/share/initramfs-tools/scripts/casper-helpers ]; then
    cp /usr/share/initramfs-tools/scripts/casper-helpers $DESTDIR/scripts/
    echo "[casper hook] OK: scripts/casper-helpers copied"
fi

# Копируем casper-premount скрипты
if ls /usr/share/initramfs-tools/scripts/casper-premount/* >/dev/null 2>&1; then
    mkdir -p $DESTDIR/scripts/casper-premount
    cp /usr/share/initramfs-tools/scripts/casper-premount/* $DESTDIR/scripts/casper-premount/
    chmod +x $DESTDIR/scripts/casper-premount/*
    echo "[casper hook] OK: casper-premount copied"
fi

# Копируем casper-bottom скрипты
if ls /usr/share/initramfs-tools/scripts/casper-bottom/* >/dev/null 2>&1; then
    mkdir -p $DESTDIR/scripts/casper-bottom
    cp /usr/share/initramfs-tools/scripts/casper-bottom/* $DESTDIR/scripts/casper-bottom/
    chmod +x $DESTDIR/scripts/casper-bottom/*
    echo "[casper hook] OK: casper-bottom copied"
fi

auto_add_modules net

if [ -e /etc/casper.conf ]; then
    mkdir -p ${DESTDIR}/etc
    cp /etc/casper.conf ${DESTDIR}/etc
    echo "[casper hook] OK: casper.conf copied"
fi

if [ "$CASPER_GENERATE_UUID" ]; then
    mkdir -p $DESTDIR/conf $DESTDIR/conf/conf.d
    uuidgen -r > $DESTDIR/conf/uuid.conf
    cat <<EOF > $DESTDIR/conf/conf.d/default-boot-to-casper.conf
if [ -z "\$BOOT" ]; then
    export BOOT=casper
fi
EOF
fi

echo "[casper hook] Completed successfully"
CASPERHOOK

    # Создаём conf.d/casper для включения casper hook
    cat > "${CHROOT_DIR}/etc/initramfs-tools/conf.d/casper.conf" << 'CASPERCONF'
# Casper hook для live-образа
BOOT=casper
CASPERFLAGS="noprompt"
CASPERCONF

    # Получаем версию ядра (должно быть установлено выше)
    if [[ -z "$KERNEL_VER" ]]; then
      KERNEL_VER=$(chroot "${CHROOT_DIR}" bash -c 'ls -1 /lib/modules/ 2>/dev/null | head -n1')
    fi
    
    if [[ -z "$KERNEL_VER" ]]; then
      log "ERROR: Ядро не найдено на этапе mkinitramfs"
      chroot "${CHROOT_DIR}" bash -c 'dpkg -l | grep linux-image || true'
      chroot "${CHROOT_DIR}" bash -c 'ls -la /lib/modules/ 2>/dev/null || echo "/lib/modules/ пуст или отсутствует"'
      die "Не найдено ядро в /lib/modules/ - проверьте установку ядра выше"
    fi
    log "Генерация initrd для ядра: $KERNEL_VER"

    # === ВАЖНАЯ ПРОВЕРКА: убеждаемся что casper файлы существуют в chroot ===
    log "Проверка наличия casper файлов в chroot..."
    if ! chroot "${CHROOT_DIR}" test -f /usr/share/initramfs-tools/scripts/casper; then
      log "ERROR: /usr/share/initramfs-tools/scripts/casper НЕ НАЙДЕН в chroot!"
      log "Проверяем установку пакета casper..."
      chroot "${CHROOT_DIR}" dpkg -l | grep casper || log "  casper package not found!"
      chroot "${CHROOT_DIR}" ls -la /usr/share/initramfs-tools/scripts/ 2>/dev/null || log "  scripts/ directory not found!"
      die "casper скрипты не найдены - переустановите пакет casper в chroot"
    fi
    log "OK: casper файлы найдены в chroot"

    # Проверяем что hook файл существует и исполняемый
    if ! chroot "${CHROOT_DIR}" test -f /usr/share/initramfs-tools/hooks/casper; then
      die "Hook файл /usr/share/initramfs-tools/hooks/casper НЕ НАЙДЕН!"
    fi
    chroot "${CHROOT_DIR}" chmod +x /usr/share/initramfs-tools/hooks/casper
    log "OK: hook файл найден и сделан исполняемым"

    # Генерируем initrd с casper hook
    log "Генерация initrd с casper hook..."
    chroot "${CHROOT_DIR}" mkinitramfs -o /boot/initrd.img.new "$KERNEL_VER" || die "Ошибка mkinitramfs"

    # === КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: проверяем нужно ли добавлять scripts/casper ===
    # Оригинальный hook casper в Ubuntu 24.04 может НЕ копировать scripts/casper
    # Проверяем есть ли он уже в initrd
    log "Проверка наличия scripts/casper в initrd..."
    
    HAS_CASPER=false
    if chroot "${CHROOT_DIR}" lsinitramfs /boot/initrd.img.new 2>/dev/null | grep -q "^scripts/casper$"; then
      log "  OK: scripts/casper уже есть в initrd (hook сработал)"
      HAS_CASPER=true
    elif chroot "${CHROOT_DIR}" lsinitramfs /boot/initrd.img.new 2>/dev/null | grep -q "scripts/casper$"; then
      # Проверяем без ^ - может быть с другим префиксом
      log "  OK: scripts/casper найден (с возможным префиксом)"
      HAS_CASPER=true
    else
      log "  WARNING: scripts/casper НЕ найден в initrd!"
      log "  Содержимое scripts/ в initrd:"
      chroot "${CHROOT_DIR}" lsinitramfs /boot/initrd.img.new 2>/dev/null | grep "^scripts/" | head -10 || log "    (scripts/ пуст)"
    fi
    
    if [[ "$HAS_CASPER" == "true" ]]; then
      log "OK: initrd содержит scripts/casper (hook сработал правильно)"
    else
      # scripts/casper отсутствует - нужно добавить вручную
      log "Добавление scripts/casper в initrd (workaround для Ubuntu 24.04)..."
      
      WORK_DIR=$(mktemp -d /tmp/initrd-work-XXXXXX)
      
      # Распаковываем initrd
      cp "${CHROOT_DIR}/boot/initrd.img.new" "${WORK_DIR}/initrd.img.new"
      INITRD_FILE="${WORK_DIR}/initrd.img.new"
      mkdir -p "${WORK_DIR}/initrd-extracted"
      
      # Определяем формат через file
      INITRD_TYPE=$(file -b "${INITRD_FILE}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
      log "  Тип initrd: ${INITRD_TYPE}"
      
      # Пробуем разные методы распаковки
      EXTRACTED=false
      for method in "gzip -dc" "xz -dc" "zstd -dc" "lz4 -dc" "cat"; do
        if (cd "${WORK_DIR}/initrd-extracted" && ${method} "${INITRD_FILE}" | cpio -idm 2>/dev/null); then
          if [[ -d "${WORK_DIR}/initrd-extracted/scripts" ]] || [[ -d "${WORK_DIR}/initrd-extracted/bin" ]]; then
            log "  Распаковка успешна: ${method}"
            EXTRACTED=true
            break
          fi
        fi
      done
      
      if [[ "$EXTRACTED" == "false" ]]; then
        log "ERROR: Не удалось распаковать initrd!"
        log "  Пробуем универсальный метод..."
        # Универсальный метод - cpio сам определит формат
        (cd "${WORK_DIR}/initrd-extracted" && cpio -idm < "${INITRD_FILE}" 2>/dev/null) || true
        
        if [[ ! -d "${WORK_DIR}/initrd-extracted/scripts" ]] && [[ ! -d "${WORK_DIR}/initrd-extracted/bin" ]]; then
          log "  FATAL: распаковка не удалась, пропускаем workaround"
          rm -rf "${WORK_DIR}"
          cd /
        fi
      fi
      
      # Копируем casper скрипты
      CASPER_SCRIPTS_SRC="${CHROOT_DIR}/usr/share/initramfs-tools/scripts"
      if [[ -d "${CASPER_SCRIPTS_SRC}" ]]; then
        mkdir -p "${WORK_DIR}/initrd-extracted/scripts"
        
        if [[ -f "${CASPER_SCRIPTS_SRC}/casper" ]]; then
          cp "${CASPER_SCRIPTS_SRC}/casper" "${WORK_DIR}/initrd-extracted/scripts/casper"
          chmod +x "${WORK_DIR}/initrd-extracted/scripts/casper"
          log "  OK: scripts/casper добавлен"
        fi
        
        [[ -f "${CASPER_SCRIPTS_SRC}/casper-functions" ]] && \
          cp "${CASPER_SCRIPTS_SRC}/casper-functions" "${WORK_DIR}/initrd-extracted/scripts/"
        [[ -f "${CASPER_SCRIPTS_SRC}/casper-helpers" ]] && \
          cp "${CASPER_SCRIPTS_SRC}/casper-helpers" "${WORK_DIR}/initrd-extracted/scripts/"
      fi
      
      # Запаковываем initrd обратно (gzip)
      rm -f "${CHROOT_DIR}/boot/initrd.img.new"
      (cd "${WORK_DIR}/initrd-extracted" && find . | cpio --quiet -o -H newc | gzip -9) > "${CHROOT_DIR}/boot/initrd.img.new"
      
      rm -rf "${WORK_DIR}"
      cd /
      log "OK: initrd обновлён с scripts/casper"
    fi

    # Проверяем что initrd содержит casper скрипты (ПРЯМАЯ ПРОВЕРКА без chroot)
    log "Финальная проверка initrd..."
    CASPER_CHECK=$(lsinitramfs "${CHROOT_DIR}/boot/initrd.img.new" 2>/dev/null | grep "scripts/casper" || true)
    
    if [[ -z "$CASPER_CHECK" ]]; then
      log "ERROR: initrd не содержит scripts/casper"
      log "=== Все файлы с 'casper' в имени: ==="
      lsinitramfs "${CHROOT_DIR}/boot/initrd.img.new" 2>/dev/null | grep -i casper || log "  (нет файлов с 'casper')"
      log "=== Содержимое scripts/: ==="
      lsinitramfs "${CHROOT_DIR}/boot/initrd.img.new" 2>/dev/null | grep "^scripts/" | head -20 || log "  (scripts/ пуст)"
      die "initrd не содержит scripts/casper - ошибка hook"
    fi
    
    log "OK: initrd содержит casper скрипты:"
    echo "$CASPER_CHECK" | head -5 | while read -r line; do
      log "  Найдено: $line"
    done
    
    # Заменяем старый initrd
    chroot "${CHROOT_DIR}" mv /boot/initrd.img.new /boot/initrd.img-"$KERNEL_VER"
    chroot "${CHROOT_DIR}" ln -sf initrd.img-"$KERNEL_VER" /boot/initrd.img
    chroot "${CHROOT_DIR}" ln -sf initrd.img-"$KERNEL_VER" /boot/initrd.img.old
    
    log "OK: initrd создан с casper hook"

    # Генерируем манифест пакетов (нужен chroot с /proc)
    log "Генерация манифеста пакетов..."
    mkdir -p "${IMAGE_DIR}/casper"
    # shellcheck disable=SC2016
    chroot "${CHROOT_DIR}" dpkg-query -W -f='${Package} ${Version}\n' > "${IMAGE_DIR}/casper/filesystem.manifest" || true
    cp "${IMAGE_DIR}/casper/filesystem.manifest" "${IMAGE_DIR}/casper/filesystem.manifest-remove"

    # Шаг 4: Очистка и выключение
    log "Шаг 4: Очистка chroot"
    umount "${CHROOT_DIR}/proc"
    umount "${CHROOT_DIR}/sys"
    umount "${CHROOT_DIR}/dev"

    # Шаг 5: Подготовка SquashFS (zstd для баланса скорость/сжатие)
    log "Шаг 5: Упаковка rootfs в SquashFS"
    # Создаём пустые mount-точки внутри chroot, чтобы они попали в squashfs
    mkdir -p "${CHROOT_DIR}/proc" "${CHROOT_DIR}/sys" "${CHROOT_DIR}/dev" "${CHROOT_DIR}/run" "${CHROOT_DIR}/tmp"
    mkdir -p "${IMAGE_DIR}/casper"
    mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" \
      -comp zstd \
      -e boot

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

    # Копируем ядро и initrd из chroot ПЕРЕД созданием образов GRUB
    log "Копирование ядра и initrd..."

    # Копируем в casper (для live-сессии)
    if [[ -f "${CHROOT_DIR}/boot/vmlinuz" ]]; then
      cp "${CHROOT_DIR}/boot/vmlinuz" "${IMAGE_DIR}/casper/vmlinuz"
      cp "${CHROOT_DIR}/boot/vmlinuz" "${IMAGE_DIR}/boot/vmlinuz"
    else
      # Ищем первое подходящее ядро по шаблону vmlinuz-*
      kernel_candidates=( "${CHROOT_DIR}"/boot/vmlinuz-* )
      if [[ -n "${kernel_candidates[0]:-}" && -f "${kernel_candidates[0]}" ]]; then
        cp "${kernel_candidates[0]}" "${IMAGE_DIR}/casper/vmlinuz"
        cp "${kernel_candidates[0]}" "${IMAGE_DIR}/boot/vmlinuz"
      else
        die "Не удалось найти ядро vmlinuz в chroot/boot"
      fi
    fi

    if [[ -f "${CHROOT_DIR}/boot/initrd.img" ]]; then
      cp "${CHROOT_DIR}/boot/initrd.img" "${IMAGE_DIR}/casper/initrd"
      cp "${CHROOT_DIR}/boot/initrd.img" "${IMAGE_DIR}/boot/initrd"
    else
      # Ищем первое подходящее initrd по шаблону initrd.img-*
      initrd_candidates=( "${CHROOT_DIR}"/boot/initrd.img-* )
      if [[ -n "${initrd_candidates[0]:-}" && -f "${initrd_candidates[0]}" ]]; then
        cp "${initrd_candidates[0]}" "${IMAGE_DIR}/casper/initrd"
        cp "${initrd_candidates[0]}" "${IMAGE_DIR}/boot/initrd"
      else
        die "Не удалось найти initrd в chroot/boot"
      fi
    fi

    log "Ядро и initrd скопированы в casper/ и boot/"

    # Копируем модули GRUB для графики
    log "Копирование модулей GRUB..."
    if [[ -d "/usr/lib/grub/x86_64-efi" ]]; then
      cp -r /usr/lib/grub/x86_64-efi/*.mod "${IMAGE_DIR}/boot/grub/x86_64-efi/" 2>/dev/null || true
    fi
    if [[ -d "/usr/lib/grub/i386-pc" ]]; then
      cp -r /usr/lib/grub/i386-pc/*.mod "${IMAGE_DIR}/boot/grub/i386-pc/" 2>/dev/null || true
    fi

    # Создаём шрифт для GRUB
    log "Создание шрифта GRUB..."

    # Сначала пробуем использовать встроенный шрифт GRUB (самый надёжный вариант)
    if [[ -f /usr/share/grub/unicode.pf2 ]]; then
      log "Используем встроенный шрифт GRUB unicode.pf2"
      cp /usr/share/grub/unicode.pf2 "${IMAGE_DIR}/boot/grub/fonts/unicode.pf2"
      cp /usr/share/grub/unicode.pf2 "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2"
    elif command -v grub-mkfont >/dev/null 2>&1; then
      # Пробуем разные источники шрифтов (Ubuntu 24.04)
      FONT_FOUND=0

      # DejaVu Sans Mono (есть в fonts-dejavu-core)
      if [[ -f /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf ]]; then
        log "Используем шрифт DejaVuSansMono.ttf"
        grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf 2>/dev/null && FONT_FOUND=1 || true
      fi

      # DejaVu Sans (альтернатива)
      if [[ ${FONT_FOUND} -eq 0 ]] && [[ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]]; then
        log "Используем шрифт DejaVuSans.ttf"
        grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf 2>/dev/null && FONT_FOUND=1 || true
      fi

      # Ubuntu Font (если есть)
      if [[ ${FONT_FOUND} -eq 0 ]] && [[ -f /usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf ]]; then
        log "Используем шрифт Ubuntu-R.ttf"
        grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 /usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf 2>/dev/null && FONT_FOUND=1 || true
      fi

      # Fallback - ищем любые truetype шрифты
      if [[ ${FONT_FOUND} -eq 0 ]]; then
        log "Ищем доступные truetype шрифты..."
        while IFS= read -r -d '' font; do
          if [[ -f "$font" ]]; then
            log "Пытаемся использовать: $font"
            if grub-mkfont -o "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" -s 16 "$font" 2>/dev/null; then
              FONT_FOUND=1
              break
            fi
          fi
        done < <(find /usr/share/fonts -name "*.ttf" -print0 2>/dev/null | head -z -n 10)
      fi

      if [[ ${FONT_FOUND} -eq 0 ]]; then
        log "WARNING: Не удалось создать шрифт GRUB из системных шрифтов"
      fi
    else
      log "WARNING: grub-mkfont не найден. Установите пакет grub-common."
    fi

    # Проверяем что шрифт создан
    if [[ ! -f "${IMAGE_DIR}/boot/grub/fonts/DejaVuSans.pf2" ]]; then
      log "WARNING: Не удалось создать шрифт GRUB. Графический режим может не работать."
      log "INFO: Для исправления установите: sudo apt install fonts-dejavu-core grub-common"
    else
      log "OK: Шрифт GRUB создан успешно"
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

    # Создаём конфигурацию GRUB (графический режим с поддержкой EFI и BIOS)
    log "Создание конфигурации GRUB..."
    cat > "${IMAGE_DIR}/boot/grub/grub.cfg" << 'GRUBEOF'
set default=0
set timeout=10
set timeout_style=menu

# Загружаем шрифт и включаем графический режим
if loadfont ${prefix}/fonts/DejaVuSans.pf2 ; then
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

# Safe video режим по умолчанию для VirtualBox и проблемных видеокарт
# quiet splash - могут быть удалены для отладки
menuentry "VibeCode OS (Live)" {
    linux /casper/vmlinuz boot=casper noprompt nvidia-drm.modeset=1 quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS Live Try" {
    linux /casper/vmlinuz boot=casper only-ubiquity nvidia-drm.modeset=1 quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS (compatibility mode — nomodeset)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset nouveau.modeset=0 ---
    initrd /casper/initrd
}

menuentry "VibeCode OS (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt nvidia-drm.modeset=1 rescue ---
    initrd /casper/initrd
}
GRUBEOF

    # Конфиг для EFI (с графическим режимом и темой)
    cat > "${IMAGE_DIR}/boot/grub/x86_64-efi/grub.cfg" << 'EOF'
set default=0
set timeout=10
set timeout_style=menu

# Графические модули для EFI
if loadfont ${prefix}/fonts/DejaVuSans.pf2 ; then
    set gfxmode=auto,1024x768,800x600,640x480
    insmod all_video
    insmod gfxterm
    terminal_output gfxterm
fi

# Применяем тему (если есть)
if [ -f ${prefix}/themes/vibecode/theme.txt ]; then
    set theme=${prefix}/themes/vibecode/theme.txt
fi

# Safe video режим по умолчанию
menuentry "VibeCode OS (Live)" {
    linux /casper/vmlinuz boot=casper noprompt nvidia-drm.modeset=1 quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS (Live - Try VibeCode OS without installing)" {
    linux /casper/vmlinuz boot=casper only-ubiquity nvidia-drm.modeset=1 quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS (compatibility mode — nomodeset)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset nouveau.modeset=0 ---
    initrd /casper/initrd
}

menuentry "VibeCode OS (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt nvidia-drm.modeset=1 rescue ---
    initrd /casper/initrd
}
EOF

    # Шаг 7: Подготовка файлов для casper
    log "Шаг 7: Подготовка файлов для casper..."

    # Создаём файл с размером squashfs (манифест уже создан до размонтирования)
    du -sx "${CHROOT_DIR}" --block=1M | awk '{print $1}' > "${IMAGE_DIR}/casper/filesystem.size"

    # Шаг 8: Создание загрузочных образов GRUB (BIOS + UEFI)
    log "Шаг 8: Создание загрузочных образов GRUB..."

    # Встроенный конфиг GRUB для поиска основного grub.cfg
    GRUB_EMBED_CFG="$(mktemp)"
    cat > "${GRUB_EMBED_CFG}" << 'GRUBEMBEDEOF'
set echo=1
echo "Searching for GRUB config..."
set root=
search --no-floppy --file --set=root /boot/grub/grub.cfg
if [ -z "$root" ]; then
    search --no-floppy --file --set=root /casper/vmlinuz
fi
if [ -z "$root" ]; then
    search --no-floppy --label --set=root VibeCodeOS
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
    grub-mkstandalone \
      --format=i386-pc \
      --output="${WORK_DIR}/core.img" \
      --install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_label tar ls part_gpt part_msdos fat ntfs configfile loopback" \
      --modules="linux normal iso9660 biosdisk search search_fs_file search_label configfile part_gpt part_msdos" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=${GRUB_EMBED_CFG}"

    cat /usr/lib/grub/i386-pc/cdboot.img "${WORK_DIR}/core.img" \
      > "${IMAGE_DIR}/boot/grub/bios.img"

    # --- UEFI boot image ---
    grub-mkstandalone \
      --format=x86_64-efi \
      --output="${WORK_DIR}/bootx64.efi" \
      --install-modules="linux normal iso9660 search search_fs_file search_label tar ls part_gpt part_msdos fat ntfs configfile loopback" \
      --modules="linux normal iso9660 search search_fs_file search_label configfile part_gpt part_msdos fat" \
      --locales="" \
      --fonts="" \
      "boot/grub/grub.cfg=${GRUB_EMBED_CFG}"

    # Создаём FAT-образ EFI System Partition
    EFI_IMG="${IMAGE_DIR}/boot/grub/efi.img"
    mkdir -p "${IMAGE_DIR}/EFI/boot"
    dd if=/dev/zero of="${EFI_IMG}" bs=1M count=4
    mkfs.vfat "${EFI_IMG}"
    mmd -i "${EFI_IMG}" ::/EFI ::/EFI/boot
    mcopy -i "${EFI_IMG}" "${WORK_DIR}/bootx64.efi" ::/EFI/boot/bootx64.efi

    # Копируем EFI-загрузчик в дерево ISO
    cp "${WORK_DIR}/bootx64.efi" "${IMAGE_DIR}/EFI/boot/bootx64.efi"

    rm -f "${GRUB_EMBED_CFG}"

    # Шаг 9: Создание ISO через xorriso (BIOS + UEFI hybrid)
    log "Шаг 9: Создание ISO"

    xorriso -as mkisofs \
      -iso-level 3 \
      -full-iso9660-filenames \
      -volid "VibeCodeOS" \
      -J -joliet-long \
      -output "${ISO_OUTPUT}" \
      --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
      --mbr-force-bootable \
      -partition_offset 16 \
      -isohybrid-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
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

    log "✅ ISO собран: ${ISO_OUTPUT}"
    log "Проверьте файл: ${ISO_OUTPUT}"
    ;;

  *)
    die "Неизвестный BUILD_MODE='${BUILD_MODE}'. Допустимо: dry-run|full"
    ;;
esac
