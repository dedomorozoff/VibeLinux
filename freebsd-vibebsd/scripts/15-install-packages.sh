#!/bin/sh
# VibeBSD — шаг 1.5: установка бинарных пакетов в jail из официального
# репозитория FreeBSD.
#
# Почему не poudriere bulk: образ собирает Plasma6 + rust + node и т.д.,
# сборка всех портов из исходников занимает сутки. Для прототипа берём
# бинарные пакеты; свой репозиторий через bulk — путь к продакшн-сборке
# (как у GhostBSD).
#
# Использование:
#   ./15-install-packages.sh [JAIL_NAME]

set -eu

JAIL_NAME="${1:-vibebsd}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"
BASE_DIR="$(dirname "$(realpath "$0")")/.."
PKGLIST="$BASE_DIR/.pkglist.merged"

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Run as root"
    exit 1
fi

if [ ! -d "$JAIL/etc" ]; then
    err "Jail $JAIL_NAME not found — run 00-setup-poudriere.sh first"
    exit 1
fi

# 1) Обновлённый объединённый список пакетов
cat "$BASE_DIR"/packages/*.txt \
    | grep -v '^[[:space:]]*#' \
    | grep -v '^[[:space:]]*$' \
    | sort -u > "$PKGLIST"
log "Total packages: $(wc -l < "$PKGLIST")"

# 2) Montages для chroot (resolv.conf — файлом, devfs — каталогом)
mkdir -p "$JAIL/dev"
[ -e "$JAIL/etc/resolv.conf" ] || touch "$JAIL/etc/resolv.conf"
grep -q "^$JAIL/dev " /etc/fstab 2>/dev/null || true
cp /etc/resolv.conf "$JAIL/etc/resolv.conf"
mount -t devfs devfs "$JAIL/dev" 2>/dev/null || true

cleanup() { umount "$JAIL/dev" 2>/dev/null || true; }
trap cleanup EXIT

# 3) Установка из официального репозитория
log "Installing binary packages into jail (this downloads a lot)..."
xargs chroot "$JAIL" env ASSUME_ALWAYS_YES=YES pkg install < "$PKGLIST" 2>&1 \
    | tee /tmp/vibebsd-pkg-install.log

log "Packages installed: $(chroot "$JAIL" pkg query -a '%n' 2>/dev/null | wc -l || true)"
log "Done. Next: ./20-build-iso.sh"
