#!/bin/sh
# VibeBSD — шаг 1.6: выкинуть из jail то, что не нужно в live-образе.
#
# Шаг идёт ДО утоньшения (17-slim-rootfs.sh): не тратим время на чистку
# документации и локалей того, что сейчас удалим.
#
#   - rust (1.3 ГБ)                 → ставится post-install (pkg install rust)
#   - postgresqlNN-client (25 МБ)   → нужен только PG-драйверу gdal, в live нет
#   - sambaNN (100+ МБ)             → нужен только для smb:// в kioslave
#
# Остальное (go, node, python, ollama, Plasma) остаётся в образе.
#
# Использование:
#   ./16-drop-postinstall.sh [JAIL_NAME]

set -eu

JAIL_NAME="${1:-vibebsd}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"
LOG="$(dirname "$(realpath "$0")")/../.work/drop-postinstall.log"

log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Run as root"
    exit 1
fi

if [ ! -d "$JAIL/etc" ]; then
    err "Jail $JAIL_NAME not found — run 00-setup-poudriere.sh first"
    exit 1
fi

mkdir -p "$(dirname "$LOG")"
BEFORE="$(du -sm "$JAIL" | awk '{print $1}')"
log "Jail size before: ${BEFORE} MB"

# Шаблоны имён: версии между релизами меняются (samba416 → samba417,
# postgresql18-client → postgresql19-client), поэтому globs, а не хардкод.
DROP_PATTERNS="rust postgresql.*-client samba.*"

drop_pattern() {
    pat="$1"
    list="$(pkg -r "$JAIL" query -a '%n' 2>/dev/null | grep -E "^${pat}\$" || true)"
    if [ -z "$list" ]; then
        log "not installed, skipping: ${pat}"
        return 0
    fi
    for p in $list; do
        log "removing $p"
        if ! pkg -r "$JAIL" delete -y "$p" >>"$LOG" 2>&1; then
            warn "$p: есть зависимые пакеты — удаляю принудительно"
            pkg -r "$JAIL" delete -y -f "$p" >>"$LOG" 2>&1 \
                || warn "не удалось удалить $p (см. $LOG)"
        fi
    done
}

for pat in $DROP_PATTERNS; do
    drop_pattern "$pat"
done

log "Removing orphans and package cache..."
pkg -r "$JAIL" autoremove -y >>"$LOG" 2>&1 || warn "autoremove failed (см. $LOG)"
rm -rf "$JAIL/var/cache/pkg"/* 2>/dev/null || true

AFTER="$(du -sm "$JAIL" | awk '{print $1}')"
log "Jail size after: ${AFTER} MB (freed $(( BEFORE - AFTER )) MB)"
log "Done. Next: ./17-slim-rootfs.sh"
