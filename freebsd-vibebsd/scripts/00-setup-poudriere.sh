#!/bin/sh
# VibeBSD — шаг 0: развёртывание окружения сборки (Poudriere + jail).
#
# Требования:
#   - Хост FreeBSD 14.0+ (рекомендуется 15.x)
#   - ZFS пул (по умолчанию zroot) или RAM-диск при -m null
#   - Выполнять от root
#
# Использование:
#   ./00-setup-poudriere.sh [FREEBSD_VERSION]
#     FREEBSD_VERSION — ветка для jail (default: 15.1-RELEASE)
#
# Переменные окружения:
#   VIBEBSD_PORTS=1   создать portstree (2–4 ГБ). Нужна только для
#                     продакшн-сборки через `poudriere bulk`; прототип
#                     (бинарные пакеты + poudriere image) обходится без неё.

set -eu

FREEBSD_VERSION="${1:-15.1-RELEASE}"
JAIL_NAME="vibebsd"
PORTS_NAME="vibebsdports"
BASE_DIR="$(dirname "$(realpath "$0")")/.."

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Run as root"
    exit 1
fi

# 1) Установка poudriere
if ! command -v poudriere >/dev/null 2>&1; then
    log "Installing poudriere..."
    env ASSUME_ALWAYS_YES=YES pkg install -y poudriere
fi

# 2) Минимальная конфигурация poudriere
# (пакет poudriere кладёт шаблон poudriere.conf без ZPOOL — перечитываем, если он неполный)
if [ ! -f /usr/local/etc/poudriere.conf ] || ! grep -q '^ZPOOL=' /usr/local/etc/poudriere.conf; then
    log "Generating /usr/local/etc/poudriere.conf..."
    ZPOOL="$(zpool list -H -o name 2>/dev/null | head -1 || true)"
    if [ -n "$ZPOOL" ]; then
        cat > /usr/local/etc/poudriere.conf <<EOF
ZPOOL=$ZPOOL
ZROOTFS=$ZPOOL/poudriere
BASEFS=/usr/local/poudriere
FREEBSD_HOST=https://download.FreeBSD.org
RESOLV_CONF=/etc/resolv.conf
NO_ZFS=no
CCACHE_DIR=/var/cache/ccache
PKG_REPO_SIGNING=NO
EOF
        log "Using ZFS pool: $ZPOOL"
    else
        cat > /usr/local/etc/poudriere.conf <<EOF
NO_ZFS=yes
BASEFS=/usr/local/poudriere
FREEBSD_HOST=https://download.FreeBSD.org
RESOLV_CONF=/etc/resolv.conf
PKG_REPO_SIGNING=NO
EOF
        log "No ZFS pool found — using directory backend"
    fi
fi

# 3) Создание jail (если ещё нет)
if ! poudriere jail -l | grep -q "^$JAIL_NAME"; then
    log "Creating jail $JAIL_NAME ($FREEBSD_VERSION)..."
    poudriere jail -c -j "$JAIL_NAME" -v "$FREEBSD_VERSION" -m http
else
    log "Jail $JAIL_NAME already exists — updating..."
    poudriere jail -u -j "$JAIL_NAME"
fi

# 4) Portstree — только когда планируется `poudriere bulk` (нужен -p и -f)
if [ "${VIBEBSD_PORTS:-0}" = "1" ]; then
    if ! poudriere ports -l | grep -q "^$PORTS_NAME"; then
        log "Creating portstree $PORTS_NAME (2-4 GB on disk)..."
        poudriere ports -c -p "$PORTS_NAME"
    else
        log "Portstree $PORTS_NAME already exists — updating..."
        poudriere ports -u -p "$PORTS_NAME"
    fi
else
    log "Portstree skipped (VIBEBSD_PORTS=1 to create — нужен для bulk)"
fi

# 5) Проверка: списки пакетов непустые и без путей портов
log "Checking package lists..."
TOTAL=0
for f in "$BASE_DIR/packages"/*.txt; do
    n="$(grep -v '^[[:space:]]*#' "$f" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')"
    log "  $(basename "$f"): ${n} пакетов"
    TOTAL=$((TOTAL + n))
done
[ "$TOTAL" -gt 0 ] || { err "No packages in packages/*.txt"; exit 1; }
if grep -h '/' "$BASE_DIR/packages"/*.txt | grep -v '^[[:space:]]*#' | grep -q .; then
    err "In packages/*.txt found category/port paths — pkg expects plain package names"
    exit 1
fi

log "Done. Next: ./10-customize-rootfs.sh"
