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

    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/base-packages.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-distro-info.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/setup-bootloader.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/cleanup.sh"
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive /root/install-mate.sh"

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

    # Настройка LightDM для autologin - полное отключение greeter
    mkdir -p "${CHROOT_DIR}/etc/lightdm"
    cat > "${CHROOT_DIR}/etc/lightdm/lightdm.conf" << 'LIGHTDMEOF'
[Seat:*]
autologin-user=vibecode
autologin-user-timeout=0
autologin-guest=false
allow-guest=false
greeter-session=lightdm-gtk-greeter
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

    # Обновляем dconf базу для применения системных настроек
    log "Обновление dconf базы..."
    chroot "${CHROOT_DIR}" /bin/bash -c "dconf update"

    # Устанавливаем casper для live-сессии (до размонтирования!)
    log "Установка casper для live-сессии..."
    chroot "${CHROOT_DIR}" /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y casper"

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
    mkdir -p "${IMAGE_DIR}/casper"
    mksquashfs "${CHROOT_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" \
      -comp zstd \
      -e boot proc sys dev run tmp

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
# ВАЖНО: не указываем init= явно - casper использует собственный механизм
menuentry "VibeCode OS (Live)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS Live Try" {
    linux /casper/vmlinuz boot=casper only-ubiquity nomodeset vga=normal fb=false quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS (compatibility mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false ---
    initrd /casper/initrd
}

menuentry "VibeCode OS (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false rescue ---
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
# ВАЖНО: не указываем init= явно - casper использует собственный механизм
menuentry "VibeCode OS (Live)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS (Live - Try VibeCode OS without installing)" {
    linux /casper/vmlinuz boot=casper only-ubiquity nomodeset vga=normal fb=false quiet splash --
    initrd /casper/initrd
}

menuentry "VibeCode OS (compatibility mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false ---
    initrd /casper/initrd
}

menuentry "VibeCode OS (rescue mode)" {
    linux /casper/vmlinuz boot=casper noprompt nomodeset vga=normal fb=false rescue ---
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
