#!/bin/sh
# VibeBSD — шаг 1.5: установка бинарных пакетов в jail из официального
# репозитория FreeBSD.
#
# Почему не poudriere bulk: образ собирает Plasma6 + dev + AI-стек, а сборка
# всех портов из исходников занимает сутки. Для прототипа берём бинарные
# пакеты; свой репозиторий через bulk — путь к продакшн-сборке (как у GhostBSD).
#
# Почему НЕ `chroot $JAIL pkg`: jail, созданный через `poudriere jail -m http`,
# собирается из base-сета релиза и не содержит /usr/bin/pkg. Ставим пакеты
# бинарником pkg с ХОСТА через `-r jail` — ровно так делает сам poudriere
# (см. jail.sh: `pkg -o ABI=... -r ${JAILMNT} install`).
#
# Использование:
#   ./15-install-packages.sh [JAIL_NAME]
#
# Переменные окружения:
#   VIBEBSD_ALLOW_MISSING=1  не падать, если часть пакетов не установилась

set -eu

JAIL_NAME="${1:-vibebsd}"
JAIL="/usr/local/poudriere/jails/$JAIL_NAME"
BASE_DIR="$(dirname "$(realpath "$0")")/.."
WORK="$BASE_DIR/.work"
PKGLIST="$WORK/pkglist.txt"
LOG="$WORK/pkg-install.log"

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

if ! command -v pkg >/dev/null 2>&1; then
    err "pkg not found on host — install pkg-tools"
    exit 1
fi

mkdir -p "$WORK"

# 1) Объединённый список пакетов
log "Merging package lists (packages/*.txt)..."
cat "$BASE_DIR"/packages/*.txt \
    | grep -v '^[[:space:]]*#' \
    | grep -v '^[[:space:]]*$' \
    | tr -d '\r' \
    | sort -u > "$PKGLIST"

CNT="$(wc -l < "$PKGLIST" | tr -d ' ')"
[ "$CNT" -gt 0 ] || { err "Empty package list — check packages/*.txt"; exit 1; }
log "Total packages: $CNT"

# Имена портов вида category/port идут только в poudriere bulk; pkg их не ест
if grep -q '/' "$PKGLIST"; then
    err "Package list contains port paths (category/port) — pkg expects plain names:"
    grep '/' "$PKGLIST" >&2
    exit 1
fi

# 2) ABI jail. Порядок источников:
#    a) URL из /usr/local/etc/pkg/repos — ровно тот ABI, на который jail настроен
#    b) BRANCH из usr/src/sys/conf/newvers.sh (у -RELEASE он может быть пустым)
#    c) мажорная ветка хоста + arch хоста (с предупреждением)
ABI=""
REPOS="$JAIL/usr/local/etc/pkg/repos"
[ -f "$REPOS" ] || REPOS="$JAIL/etc/pkg/repos"

if [ -f "$REPOS" ]; then
    ABI="$(sed -n 's|.*FreeBSD:\([0-9]\{1,2\}:[a-z0-9_]*\).*|FreeBSD:\1|p' "$REPOS" | head -1)"
fi
if [ -z "$ABI" ] && [ -r "$JAIL/usr/src/sys/conf/newvers.sh" ]; then
    JBRANCH="$(awk -F'"' '/^BRANCH=/ { print $2; exit }' "$JAIL/usr/src/sys/conf/newvers.sh" 2>/dev/null || true)"
    if [ -n "$JBRANCH" ] && [ "$JBRANCH" != "trunk" ]; then
        ABI="FreeBSD:${JBRANCH}:$(uname -m)"
    fi
fi
if [ -z "$ABI" ]; then
    HOST_MAJOR="$(freebsd-version 2>/dev/null | cut -d. -f1 || true)"
    if [ -n "$HOST_MAJOR" ]; then
        ABI="FreeBSD:${HOST_MAJOR}:$(uname -m)"
    else
        warn "ABI jail не определён по файлам jail — беру ветку хоста"
    fi
fi
[ -n "$ABI" ] || { err "Could not determine ABI (no repos, no newvers.sh, no freebsd-version)"; exit 1; }
log "Jail ABI: $ABI"
PKG_OPTS="-o ABI=$ABI"

# 3) Репозитории: jail из base-сета может остаться без конфига — записываем
#    официальный, как это делает установщик FreeBSD.
#    URL без префикса pkg+ : SRV-резолвинг для зеркал не везде работает
#    (проверено на хосте — pkg+https падает с "packagesite URL error").
if [ ! -f "$JAIL/usr/local/etc/pkg/repos" ] && [ ! -f "$JAIL/etc/pkg/repos" ]; then
    log "Writing /usr/local/etc/pkg/repos in jail..."
    mkdir -p "$JAIL/usr/local/etc/pkg"
    cat > "$JAIL/usr/local/etc/pkg/repos" <<EOF
FreeBSD: {
    url: "https://pkg.FreeBSD.org/${ABI}/latest",
    enabled: yes
}
FreeBSD-kmods: {
    url: "https://pkg.FreeBSD.org/${ABI}/latest",
    enabled: yes,
    priority: 1
}
EOF
fi

log "Updating repository catalog..."
# shellcheck disable=SC2086
pkg -r "$JAIL" $PKG_OPTS update > "$WORK/pkg-update.log" 2>&1 || {
    err "pkg update failed — see $WORK/pkg-update.log"
    tail -20 "$WORK/pkg-update.log" >&2
    exit 1
}

# 4) Установка. Статус не маскируем пайпом: лог пишем в файл, в консоль — хвост.
log "Installing packages into jail (large download, be patient)..."
set +e
# shellcheck disable=SC2086
pkg -r "$JAIL" $PKG_OPTS install -y $(cat "$PKGLIST") > "$LOG" 2>&1
RC=$?
set -e
tail -15 "$LOG" || true
[ "$RC" -eq 0 ] || warn "pkg install exited with $RC — checking what landed in the jail"

# 5) Проверка: все ли запрошенные пакеты реально стоят
pkg -r "$JAIL" query -a '%n' 2>/dev/null | sort -u > "$WORK/installed.txt" || true
comm -23 "$PKGLIST" "$WORK/installed.txt" > "$WORK/missing.txt" || true
MISSING="$(wc -l < "$WORK/missing.txt" | tr -d ' ')"
INSTALLED="$(wc -l < "$WORK/installed.txt" | tr -d ' ')"

if [ "$MISSING" -gt 0 ]; then
    err "Not installed ($MISSING of $CNT):"
    sed 's/^/  - /' "$WORK/missing.txt" >&2
    if [ "${VIBEBSD_ALLOW_MISSING:-0}" = "1" ]; then
        warn "VIBEBSD_ALLOW_MISSING=1 — continuing despite missing packages"
    else
        err "Check names in packages/*.txt (freshports search) or set VIBEBSD_ALLOW_MISSING=1"
        exit 1
    fi
fi
log "Installed in jail: $INSTALLED packages"

# 6) Сессия Plasma для SDDM: имя должно совпадать с *.desktop в xsessions,
#    иначе autologin уводит в чёрный экран
XSESSIONS="$JAIL/usr/local/share/xsessions"
if [ -d "$XSESSIONS" ]; then
    SESSION=""
    for want in plasma plasma-x11 plasma-wayland; do
        if [ -f "$XSESSIONS/$want.desktop" ]; then
            SESSION="$want"
            break
        fi
    done
    if [ -n "$SESSION" ]; then
        if grep -q "^Session=" "$JAIL/usr/local/etc/sddm.conf" 2>/dev/null; then
            sed -i '' "s/^Session=.*/Session=$SESSION/" "$JAIL/usr/local/etc/sddm.conf"
        fi
        log "SDDM session: $SESSION"
    else
        warn "No plasma*.desktop in $XSESSIONS — SDDM autologin may fail"
    fi
else
    warn "$XSESSIONS not found — is sddm/plasma6-plasma installed?"
fi

log "Log: $LOG"
log "Done. Next: ./16-drop-postinstall.sh"
