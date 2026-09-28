#!/bin/sh
# VibeBSD — шаг 1.7: утоньшение rootfs перед сборкой образа.
#
# Удаляет всё, что не нужно в live-системе: кэш pkg, документацию, man, info,
# статические библиотеки, лишние локали, тесты Go/Python, кэши сборки.
# Экономит ~3.5–4 ГБ на диске jail.
#
# НЕ удаляем /usr/src: poudriere image делает `make delete-old` прямо в jail
# (image.sh → install_world), а в образ usr/src и так исключён excludelist.
#
# Использование:
#   ./17-slim-rootfs.sh [JAIL_NAME]
#
# Переменные окружения:
#   VIBEBSD_KEEP_MAN=1  оставить man-страницы (если нужен man в live)

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

# 1) Кэш пакетов
log "Cleaning pkg cache..."
rm -rf "$JAIL/var/cache/pkg"/* "$JAIL/root/.cache" 2>/dev/null || true

# 2) Тесты и rescue
# rescue — mountpoint релиза, гасим только если это не гора
log "Removing base tests..."
rm -rf "$JAIL/usr/tests" 2>/dev/null || true
if mount | grep -q "on $JAIL/rescue "; then
    log "  /rescue is a mountpoint — keeping"
else
    rm -rf "$JAIL/rescue" 2>/dev/null || true
fi

# 3) Документация
log "Removing docs, info and static libs..."
rm -rf "$JAIL/usr/local/share/doc" "$JAIL/usr/local/share/examples" \
       "$JAIL/usr/local/share/licenses" "$JAIL/usr/local/info" \
       "$JAIL/usr/share/doc" "$JAIL/usr/share/examples" 2>/dev/null || true
if [ "${VIBEBSD_KEEP_MAN:-0}" != "1" ]; then
    log "Removing man pages (VIBEBSD_KEEP_MAN=1 to keep)..."
    rm -rf "$JAIL/usr/local/man" "$JAIL/usr/share/man" 2>/dev/null || true
fi
find "$JAIL/usr/local/lib" -name '*.a' -delete 2>/dev/null || true

# 4) Локали: оставляем en_US, ru_RU, C/POSIX
log "Pruning locales (keeping en_US, ru_RU, C)..."
if [ -d "$JAIL/usr/local/share/locale" ]; then
    find "$JAIL/usr/local/share/locale" -mindepth 1 -maxdepth 1 -type d \
        ! -name 'en_US*' ! -name 'ru_RU*' ! -name 'C' ! -name 'POSIX' \
        -exec rm -rf {} + 2>/dev/null || true
fi
if [ -d "$JAIL/usr/share/locale" ]; then
    find "$JAIL/usr/share/locale" -mindepth 1 -maxdepth 1 -type d \
        ! -name 'en_US*' ! -name 'ru_RU*' ! -name 'C' ! -name 'POSIX' \
        -exec rm -rf {} + 2>/dev/null || true
fi

# 5) Go: тесты и исходники пакетов
log "Removing Go tests..."
for godir in "$JAIL"/usr/local/go*; do
    [ -d "$godir" ] || continue
    rm -rf "$godir/test" "$godir/api" "$godir/misc" 2>/dev/null || true
done

# 6) Python: __pycache__ и тесты в site-packages (реально много весит torch и т.п.)
log "Removing Python caches and tests..."
for pydir in "$JAIL"/usr/local/lib/python3.*; do
    [ -d "$pydir" ] || continue
    find "$pydir" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
    if [ -d "$pydir/site-packages" ]; then
        find "$pydir/site-packages" -type d \( -name tests -o -name test \) \
            -prune -exec rm -rf {} + 2>/dev/null || true
    fi
done

# 7) Служебное от сборки
log "Removing build leftovers..."
find "$JAIL/usr/local/lib" -name '.build-id' -type d \
    -exec rm -rf {} + 2>/dev/null || true
rm -f "$JAIL/usr/local/libexec/cherry_pick_pull.py" 2>/dev/null || true
rm -rf "$JAIL/usr/local/share/vim"/vim*/doc 2>/dev/null || true
rm -rf "$JAIL/usr/local/lib/node_modules/npm/docs" 2>/dev/null || true

AFTER="$(du -sm "$JAIL" | awk '{print $1}')"
log "Jail size after: ${AFTER} MB (freed $(( BEFORE - AFTER )) MB)"
log "Done. Next: ./20-build-iso.sh"
