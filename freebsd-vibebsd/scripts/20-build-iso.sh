#!/bin/sh
# VibeBSD — шаг 2: сборка загрузочного live-образа через poudriere image.
#
# Как это работает (проверено по исходникам poudriere 3.4.8, image.sh):
#   install_world() делает `tar -C <jail> -cf - . | tar -xf - -C $WRKDIR/world`,
#   то есть rootfs образа — это СОДЕРЖИМОЕ JAIL (вместе с пакетами из шага 15 и
#   кастомизацией из шага 10), а не чистый world.
#   Опцию -f (список пакетов) НЕ используем: она ставит пакеты из
#   poudriere-репозитория ($POUDRIERE_DATA/packages/<master>), который у нас
#   пустой — сборки через `poudriere bulk` не было. Список пакетов нужен
#   только как отчёт, поэтому он собирается в .work/pkglist.txt.
#
# Важно: -t iso и -t hybridiso дают root на cd9660 в режиме ro
#   (fstab в образе: /dev/iso9660/VIBEBSD / cd9660 ro + tmpfs /tmp).
#   Запись в /var и /home в live-сессии закрыта — это известное ограничение,
#   см. docs/VIBEBSD.md.
#
# Использование:
#   ./20-build-iso.sh [JAIL_NAME] [IMAGE_TYPE]
#     JAIL_NAME  — jail с установленными пакетами (default: vibebsd)
#     IMAGE_TYPE — iso | hybridiso (default: iso, см. VIBEBSD_IMAGE_TYPE)
#
# Переменные окружения:
#   VIBEBSD_IMAGE_TYPE  тип образа: iso (default) | hybridiso
#   VIBEBSD_IMAGE_NAME  имя образа внутри poudriere (default: vibebsd)

set -eu

JAIL_NAME="${1:-vibebsd}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"
BASE_DIR="$(dirname "$(realpath "$0")")/.."
REPO_DIR="$(cd "$BASE_DIR/.." && pwd)"
IMAGE_TYPE="${2:-${VIBEBSD_IMAGE_TYPE:-iso}}"
IMAGE_NAME="${VIBEBSD_IMAGE_NAME:-vibebsd}"
HOST_NAME="vibebsd"
WORKDIR="$REPO_DIR/.work"
OUTDIR="$REPO_DIR/out"
PKGLIST="$WORKDIR/pkglist.txt"
START_TS="$(date +%s)"

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Run as root"
    exit 1
fi

case "$IMAGE_TYPE" in
    iso|hybridiso) ;;
    *) err "Unsupported image type: $IMAGE_TYPE (use iso or hybridiso)"; exit 1 ;;
esac

if [ ! -d "$JAIL/etc" ]; then
    err "Jail $JAIL_NAME not found — run 00-setup-poudriere.sh first"
    exit 1
fi

# 1) Преflight: без ядра и загрузчика poudriere image упадёт на iso_check
log "Preflight checks..."
[ -f "$JAIL/boot/kernel/kernel" ] || {
    err "$JAIL/boot/kernel/kernel is missing — image needs a kernel in the jail"
    err "Fix: poudriere jail -d -j $JAIL_NAME && ./00-setup-poudriere.sh $JAIL_NAME"
    exit 1
}
[ -f "$JAIL/boot/loader.efi" ] || warn "$JAIL/boot/loader.efi missing — UEFI boot will not work"

# 2) Отчёт по составу образа
mkdir -p "$WORKDIR" "$OUTDIR"
cat "$BASE_DIR"/packages/*.txt \
    | grep -v '^[[:space:]]*#' \
    | grep -v '^[[:space:]]*$' \
    | tr -d '\r' \
    | sort -u > "$PKGLIST"
log "Packages in profile: $(wc -l < "$PKGLIST" | tr -d ' ') (уже стоят в jail)"

# 3) Место: poudriere раскладывает world в $POUDRIERE_DATA/images + сам ISO
JAIL_MB="$(du -sm "$JAIL" | awk '{print $1}')"
AVAIL_MB="$(df -m "$OUTDIR" | awk 'NR == 2 {print $4}')"
log "Jail size: ${JAIL_MB} MB, free on $(df -h "$OUTDIR" | awk 'NR == 2 {print $1}'): ${AVAIL_MB} MB"
if [ "$AVAIL_MB" -lt "$JAIL_MB" ]; then
    err "Мало места: нужно минимум ~${JAIL_MB} MB под ISO (staging — рядом с jail)"
    exit 1
fi
if [ "$JAIL_MB" -gt 4096 ]; then
    warn "Jail больше 4 ГБ — ISO будет жирным; проверь шаги 16/17"
fi

# 4) Сборка
log "Building image ($IMAGE_TYPE) via poudriere image..."
# -h важен: без него poudriere подставляет hostname=poudriere-image
# в /etc/rc.conf готового образа и затирает наш брендинг.
poudriere image \
    -j "$JAIL_NAME" \
    -t "$IMAGE_TYPE" \
    -n "$IMAGE_NAME" \
    -h "$HOST_NAME" \
    -o "$OUTDIR"

# 5) Результат: poudriere всегда пишет ${IMAGE_NAME}.iso
ISO_FILE="$OUTDIR/$IMAGE_NAME.iso"
if [ ! -f "$ISO_FILE" ]; then
    err "Build finished but $ISO_FILE is missing — check poudriere output"
    exit 1
fi
ISO_MB="$(stat -f %z "$ISO_FILE" | awk '{printf "%d", $1 / 1048576}')"
if [ "$(stat -f %m "$ISO_FILE")" -lt "$START_TS" ]; then
    err "$ISO_FILE is older than this run — poudriere did not rebuild the image"
    exit 1
fi

# Переименовываем (а не копируем): ISO — это гигабайты, держать две копии
# на диске с 10+ ГБ свободного места смысла нет.
TARGET="$OUTDIR/vibebsd-live-$(date +%Y%m%d).iso"
if [ "$ISO_FILE" != "$TARGET" ]; then
    mv -f "$ISO_FILE" "$TARGET"
fi
log "Done! ISO: $TARGET (${ISO_MB} MB)"
log "Root в образе — cd9660 ro: /tmp в tmpfs, /var и /home только для чтения."
if [ "$IMAGE_TYPE" = "iso" ]; then
    log "Для загрузки UEFI с USB по dd: VIBEBSD_IMAGE_TYPE=hybridiso"
fi
log "Test in VM:  bhyve / VirtualBox (FreeBSD 15 guest)"
