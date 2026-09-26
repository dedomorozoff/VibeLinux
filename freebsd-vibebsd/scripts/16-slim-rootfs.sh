#!/bin/sh
# VibeBSD — шаг 1.6: утоньшение rootfs перед сборкой образа.
#
# Удаляет всё, что не нужно в live-системе: кэш pkg, исходники base,
# документацию, лишние локали, static-библиотеки, тесты Go и кеши Python.
# Экономит ~3.5–4 ГБ и держит ISO в разумных границах.
#
# Использование:
#   ./16-slim-rootfs.sh [JAIL_NAME]

set -eu

JAIL_NAME="${1:-vibebsd}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"

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

BEFORE="$(du -sm "$JAIL" | awk '{print $1}')"
log "Jail size before: ${BEFORE} MB"

log "Cleaning pkg cache and orphans..."
chroot "$JAIL" pkg clean -y >/dev/null 2>&1 || true
chroot "$JAIL" pkg autoremove -y >/dev/null 2>&1 || true

log "Removing base tests (src оставляем: нужен poudriere для delete-old)..."
rm -rf "$JAIL/usr/tests" "$JAIL/rescue" 2>/dev/null || true

log "Removing docs, man, info, static libs..."
rm -rf "$JAIL/usr/local/share/doc" "$JAIL/usr/local/share/examples" \
       "$JAIL/usr/local/info" "$JAIL/usr/share/doc" "$JAIL/usr/share/examples" 2>/dev/null || true
find "$JAIL/usr/local/lib" -name '*.a' -delete 2>/dev/null || true

log "Pruning locales (keeping en_US, ru_RU, POSIX/C)..."
cd "$JAIL/usr/local/share" 2>/dev/null && [ -d locale ] && {
    find locale -mindepth 1 -maxdepth 1 -type d \
        ! -name 'en_US*' ! -name 'ru_RU*' ! -name 'locale.alias' \
        -exec rm -rf {} + 2>/dev/null || true
}
cd "$JAIL/usr/share" 2>/dev/null && [ -d locale ] && {
    find locale -mindepth 1 -maxdepth 1 -type d \
        ! -name 'en_US*' ! -name 'ru_RU*' ! -name 'C' \
        -exec rm -rf {} + 2>/dev/null || true
}
cd "$JAIL" || true

log "Removing Go tests and Python caches..."
rm -rf "$JAIL/usr/local/go125/test" "$JAIL/usr/local/go/test" 2>/dev/null || true
find "$JAIL/usr/local/lib/python3.12" -name '__pycache__' -type d \
    -exec rm -rf {} + 2>/dev/null || true

log "Removing build/prerm scripts and .build-id..."
find "$JAIL/usr/local/lib" -name '.build-id' -type d \
    -exec rm -rf {} + 2>/dev/null || true
rm -f "$JAIL/usr/local/libexec/cherry_pick_pull.py" 2>/dev/null || true

AFTER="$(du -sm "$JAIL" | awk '{print $1}')"
log "Jail size after: ${AFTER} MB (saved $(( BEFORE - AFTER )) MB)"
