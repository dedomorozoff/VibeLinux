#!/bin/sh
# VibeBSD — шаг 1.8: поставить в jail локальные сборки из soft/.
#
# В soft/ лежат .pkg, которых нет в официальном репозитории FreeBSD:
#   - opencode — AI-агент в терминале (динамическая сборка, 212 МБ)
#   - dmcode    — терминальный агент на google/adk-go (статический Go, 36 МБ)
#   - dmed      — редактор кода dmEd, AI-агенты как первоклассные участники (17 МБ)
#   - dmsh      — Direct Model Shell, вшитый llama.cpp через CGO (12 МБ)
#
# Ставим ПОСЛЕ утоньшения (17-slim-rootfs.sh): эти пакеты состоят только из
# одного бинаря, clean-фильтры их не трогают, а наш бинарь гарантированно
# попадает в образ целиком.
#
# Про -M (--accept-missing): jail собран из base-сета (poudriere jail -m http),
# поэтому libc++/libcxxrt/libexecinfo лежат в нём файлами, но НЕ являются
# pkg-пакетами. Без -M pkg отказывается ставить opencode:
#   "Missing shlib libc++.so.1 required by opencode"
# Ставить пакет libc++ не нужно — он бы перезаписал файлы base-системы.
#
# Использование:
#   ./18-install-soft.sh [JAIL_NAME] [SOFT_DIR]
#
# Переменные:
#   VIBEBSD_SOFT_OPTIONAL=1  — не падать, если soft/ пуст

set -eu

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
JAIL_NAME="${1:-vibebsd}"
SOFT_DIR="${2:-$SCRIPT_DIR/../../soft}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"
LOG="$SCRIPT_DIR/../.work/install-soft.log"

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

SOFT_DIR="$(realpath "$SOFT_DIR" 2>/dev/null || echo "$SOFT_DIR")"
mkdir -p "$(dirname "$LOG")"

BEFORE="$(du -sm "$JAIL" | awk '{print $1}')"

# Список пакетов: только .pkg верхнего уровня, по имени (порядок = порядок установки)
PKGS=$(find "$SOFT_DIR" -maxdepth 1 -name '*.pkg' -type f 2>/dev/null | sort || true)

if [ -z "$PKGS" ]; then
    if [ "${VIBEBSD_SOFT_OPTIONAL:-0}" = "1" ]; then
        warn "no .pkg in $SOFT_DIR, skipping (VIBEBSD_SOFT_OPTIONAL=1)"
        exit 0
    fi
    err "no .pkg files in $SOFT_DIR"
    err "put prebuilt packages there (see soft/README.md) or set VIBEBSD_SOFT_OPTIONAL=1"
    exit 1
fi

log "Soft dir: $SOFT_DIR"
log "Jail size before: ${BEFORE} MB"

# Мажорная ветка jail: сперва его собственный freebsd-version, потом newvers.sh,
# потом хост (jail и хост — одна ветка по построению пайплайна).
jail_branch() {
    v=""
    if [ -x "$JAIL/bin/freebsd-version" ]; then
        v=$("$JAIL/bin/freebsd-version" -u 2>/dev/null || true)
    fi
    if [ -z "$v" ] && [ -f "$JAIL/usr/src/sys/conf/newvers.sh" ]; then
        v=$(sed -n 's/^BRANCH=[^0-9]*\([0-9]*\).*/\1/p' "$JAIL/usr/src/sys/conf/newvers.sh" 2>/dev/null | head -1)
    fi
    [ -n "$v" ] || v=$(freebsd-version -u 2>/dev/null || echo "")
    printf '%s' "$v" | tr -cd '0-9' | cut -c1-2
}

BRANCH=$(jail_branch)
if [ -n "$BRANCH" ]; then
    log "Jail branch: FreeBSD:$BRANCH"
else
    warn "could not determine jail branch — ABI check skipped"
fi

for pkg_file in $PKGS; do
    name=$(basename "$pkg_file")

    [ -r "$pkg_file" ] || { err "$name: not readable"; exit 1; }

    # ABI пакета должен совпадать с веткой jail, иначе pkg откажется ставить
    # бинарь, собранный под другую мажорную версию FreeBSD.
    pkg_abi=$(tar -xOf "$pkg_file" +MANIFEST 2>/dev/null | sed -n 's/.*"abi":"\([^"]*\)".*/\1/p' || true)
    if [ -n "$BRANCH" ] && [ -n "$pkg_abi" ]; then
        case "$pkg_abi" in
            *":${BRANCH}:"*) : ;;
            *) err "$name: ABI $pkg_abi does not match jail (FreeBSD:$BRANCH)"
               exit 1 ;;
        esac
    fi

    log "Installing $name ..."
    if ! pkg -r "$JAIL" add -M "$pkg_file" >>"$LOG" 2>&1; then
        err "$name: pkg add failed (см. $LOG)"
        tail -5 "$LOG" >&2 || true
        exit 1
    fi
done

# Проверка: пакет зарегистрирован в БД jail и его бинарь на месте.
# (pkg info -q в режиме pattern молчит на FreeBSD 15 — берём версию через query.)
log "Verifying installed packages..."
INSTALLED_DB=$(pkg -r "$JAIL" query -a '%n-%v' 2>/dev/null || true)
for pkg_file in $PKGS; do
    name=$(basename "$pkg_file")
    pkg_name=$(tar -xOf "$pkg_file" +MANIFEST 2>/dev/null | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' || true)
    [ -n "$pkg_name" ] || { err "$name: cannot read package name from +MANIFEST"; exit 1; }

    version=$(printf '%s\n' "$INSTALLED_DB" | grep -E "^${pkg_name}-" | head -1 || true)
    if [ -z "$version" ]; then
        err "$pkg_name: файлы извлечены, но пакета нет в БД jail"
        exit 1
    fi
    if [ ! -x "$JAIL/usr/local/bin/$pkg_name" ]; then
        err "$pkg_name: нет исполняемого /usr/local/bin/$pkg_name в jail"
        exit 1
    fi
    log "  ok: $version -> /usr/local/bin/$pkg_name"
done

AFTER="$(du -sm "$JAIL" | awk '{print $1}')"
log "Jail size after: ${AFTER} MB (added $(( AFTER - BEFORE )) MB)"
log "Done. Next: ./20-build-iso.sh"
