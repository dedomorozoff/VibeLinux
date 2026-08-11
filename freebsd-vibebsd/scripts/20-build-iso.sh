#!/bin/sh
# VibeBSD — шаг 2: сборка загрузочного live-ISO через poudriere image.
#
# poudriere image берёт jail как rootfs, ставит пакеты из объединённого
# списка packages/*.txt и генерирует загрузочный ISO (UEFI+BIOS, UFS).
#
# Использование:
#   ./20-build-iso.sh [JAIL_NAME] [PORTS_NAME]

set -eu

JAIL_NAME="${1:-vibebsd}"
PORTS_NAME="${2:-vibebsd-ports}"
BASE_DIR="$(dirname "$(realpath "$0")")/.."
WORKDIR="/tmp/vibebsd-image"
OUTDIR="$PWD/out"
PKGLIST="$WORKDIR/pkglist.txt"

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Run as root"
    exit 1
fi

# 1) Объединение пакетных списков
log "Merging package lists..."
mkdir -p "$WORKDIR" "$OUTDIR"
cat "$BASE_DIR"/packages/*.txt \
    | grep -v '^[[:space:]]*#' \
    | grep -v '^[[:space:]]*$' \
    | sort -u > "$PKGLIST"
log "Total packages: $(wc -l < "$PKGLIST")"

# 2) Сборка ISO
log "Building ISO via poudriere image..."
poudriere image \
    -j "$JAIL_NAME" \
    -p "$PORTS_NAME" \
    -t iso \
    -c "$PKGLIST" \
    -o "$OUTDIR"

# 3) Переименование результата
ISO_FILE="$(ls -t "$OUTDIR"/*.iso 2>/dev/null | head -1 || true)"
if [ -n "$ISO_FILE" ] && [ -f "$ISO_FILE" ]; then
    TARGET="$OUTDIR/vibebsd-live-$(date +%Y%m%d).iso"
    [ "$ISO_FILE" != "$TARGET" ] && mv -f "$ISO_FILE" "$TARGET"
    log "Done! ISO: $TARGET ($(du -h "$TARGET" | cut -f1))"
    log "Test in VM:  bhyve / VirtualBox (FreeBSD 15 guest)"
else
    err "Build failed — no ISO produced. Check poudriere logs."
    exit 1
fi
