#!/usr/bin/env bash
# VibeLinux Minimal ISO builder — CLI-only Arch Linux
set -euo pipefail

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="${WORKDIR:-/srv/vibe-iso-mini-work}"
OUTDIR="${OUTDIR:-$PWD/out}"
PROFILE_DIR="$(dirname "$(readlink -f "$0")")/../../archiso-vibelinux-minimal"
PROFILE_DIR="$(cd "$PROFILE_DIR" && pwd)"

log() { printf "\033[1;36m[mini]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

mkdir -p "$OUTDIR"

# 1) Check dependencies
log "Checking dependencies..."
if ! command -v mkarchiso >/dev/null 2>&1; then
    log "Installing archiso..."
    pacman -Sy --noconfirm archiso
fi

# 2) Check profile
if [[ ! -d "$PROFILE_DIR" ]]; then
    err "Profile directory not found: $PROFILE_DIR"
    exit 1
fi

log "Using profile: $PROFILE_DIR"
log "Work dir: $WORKDIR"
log "Output dir: $OUTDIR"

# 3) Cleanup / force rebuild
if [[ "${CLEAN:-0}" == "1" ]]; then
    log "Cleaning working directory..."
    rm -rf "$WORKDIR"
elif [[ -d "$WORKDIR" ]]; then
    log "Removing run-once markers (incremental rebuild)..."
    find "$WORKDIR" -maxdepth 1 -type f \
        -name 'base.*' \
        ! -name 'base._make_work_dir' \
        ! -name 'base._make_pacman_conf' \
        ! -name 'base._make_version' \
        ! -name 'base._make_packages' \
        -delete
    rm -f "$WORKDIR"/build._build_buildmode_iso \
          "$WORKDIR"/iso._build_iso_image
fi

# 3aa) Freshness checks: mkarchiso's _run_once() only checks marker EXISTENCE,
#      not freshness. If packages.x86_64 / pacman.conf / profiledef.sh changed
#      since the last build, drop the corresponding marker, otherwise the step
#      (e.g. pacstrap with the new package list) is silently skipped and the
#      ISO gets the OLD package set.
if [[ -f "$PROFILE_DIR/packages.x86_64" && -f "$WORKDIR/base._make_packages" \
      && "$PROFILE_DIR/packages.x86_64" -nt "$WORKDIR/base._make_packages" ]]; then
    rm -f "$WORKDIR/base._make_packages" "$WORKDIR/base._make_pkglist"
    log "packages.x86_64 changed → re-running pacstrap"
fi
if [[ -f "$PROFILE_DIR/pacman.conf" && -f "$WORKDIR/base._make_pacman_conf" \
      && "$PROFILE_DIR/pacman.conf" -nt "$WORKDIR/base._make_pacman_conf" ]]; then
    rm -f "$WORKDIR/base._make_pacman_conf"
    log "pacman.conf changed → regenerating pacman.conf"
fi
if [[ -f "$PROFILE_DIR/profiledef.sh" && -f "$WORKDIR/base._make_version" \
      && "$PROFILE_DIR/profiledef.sh" -nt "$WORKDIR/base._make_version" ]]; then
    rm -f "$WORKDIR/base._make_version"
    log "profiledef.sh changed → regenerating version"
fi

# 3a) Unmount leftover chroot mounts
if grep -qs "$WORKDIR" /proc/mounts; then
    log "Unmounting leftover chroot mounts in $WORKDIR..."
    awk -v w="$WORKDIR" 'index($2, w) == 1 {print $2}' /proc/mounts | sort -r | while read -r m; do
        umount -l "$m" 2>/dev/null || true
    done
fi

# --- GitHub releases helpers -------------------------------------------------
# Свои AI-утилиты (dmed, dmsh, dmcode) ставим из GitHub-релизов, а не из файлов
# в профиле — в ISO всегда свежая версия. api.github.com без токена лимитирован
# (60 запросов/час на IP), поэтому при наличии GITHUB_TOKEN он используется; если
# API недоступен — версию и ассеты берём с HTML-страницы релиза.
SOFT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../soft" 2>/dev/null && pwd || true)"
GH_AUTH=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    GH_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

gh_latest_url() {
    local repo="$1" pattern="$2" url tag
    url="$(curl -fsSL --retry 3 "${GH_AUTH[@]}" \
        "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -o 'https://[^"]*'"${pattern}" | grep -v -- '-debug' | head -1 || true)"
    if [[ -n "$url" ]]; then
        printf '%s\n' "$url"
        return 0
    fi

    # API лимитирован/недоступен: получаем тег из редиректа и парсим ассеты
    tag="$(curl -fsSLI --retry 3 -o /dev/null -w '%{url_effective}' \
        "https://github.com/${repo}/releases/latest" 2>/dev/null \
        | sed -n 's#.*/tag/##p' || true)"
    [[ -z "$tag" ]] && return 1
    url="$(curl -fsSL --retry 3 "https://github.com/${repo}/releases/expanded_assets/${tag}" 2>/dev/null \
        | grep -o "/${repo}/releases/download/[^\"]*${pattern}" | grep -v -- '-debug' | head -1 || true)"
    [[ -n "$url" ]] || return 1
    printf 'https://github.com%s\n' "$url"
}

# fetch_gh_pkg <tool> <owner/repo> <dst>
# Кладёт свежий x86_64 .pkg.tar.zst в <dst>; офлайн-фоллбек — soft/<tool>/.
fetch_gh_pkg() {
    local tool="$1" repo="$2" dst="$3" url
    mkdir -p "$dst"
    rm -f "$dst"/*.pkg.tar.zst "$dst/$tool"

    url="$(gh_latest_url "$repo" 'x86_64\.pkg\.tar\.zst' || true)"
    if [[ -n "$url" ]] && curl -fsSL --retry 3 "$url" -o "$dst/$(basename "$url")"; then
        log "$tool ← GitHub release: $(basename "$url")"
        return 0
    fi

    if [[ -n "$SOFT_DIR" ]] && compgen -G "$SOFT_DIR/$tool/*.pkg.tar.zst" >/dev/null; then
        cp "$SOFT_DIR/$tool"/*.pkg.tar.zst "$dst/"
        log "$tool ← локальный пакет soft/$tool/"
        return 0
    fi

    warn "$tool недоступен (GitHub недоступен и нет soft/$tool/)"
    return 1
}

# 3b) dmed — terminal-native AI editor (Go).
# Основной источник — Arch-пакет из GitHub-релизов (регистрируется в pacman-БД).
# Если пакета нет — raw binary `dmed-linux-amd64` из того же релиза, затем
# soft/dmed/dmed → PATH → сборка через Go.
DMED_DST="$PROFILE_DIR/airootfs/root/dmed"
DMED_BIN="$PROFILE_DIR/airootfs/usr/local/bin/dmed"
log "Fetching dmed into airootfs..."
DMED_OK=0
if fetch_gh_pkg dmed dedomorozoff/dmed "$DMED_DST"; then
    DMED_OK=1
    # Пакет ставится в /usr/bin/dmed — старый raw-бинарник в профиле не нужен
    rm -f "$DMED_BIN"
fi

if [[ $DMED_OK -eq 0 ]]; then
    mkdir -p "$(dirname "$DMED_BIN")"
    DMED_URL="$(gh_latest_url dedomorozoff/dmed 'dmed-linux-amd64' || true)"
    if [[ -n "$DMED_URL" ]] && curl -fsSL --retry 3 "$DMED_URL" -o "$DMED_BIN"; then
        chmod +x "$DMED_BIN"
        DMED_OK=1
        log "dmed ← GitHub binary: $(basename "$DMED_URL")"
    fi
fi

DMED_DIR="$SOFT_DIR/dmed"
DMED_SRC="$DMED_DIR/dmed"
if [[ $DMED_OK -eq 0 && -f "$DMED_SRC" ]]; then
    [[ -x "$DMED_SRC" ]] || chmod +x "$DMED_SRC"
    install -Dm755 "$DMED_SRC" "$DMED_BIN"
    DMED_OK=1
    log "dmed copied from soft/dmed/dmed -> $DMED_BIN"
fi

if [[ $DMED_OK -eq 0 ]] && command -v dmed >/dev/null 2>&1; then
    install -Dm755 "$(command -v dmed)" "$DMED_BIN"
    DMED_OK=1
    log "dmed copied from PATH -> $DMED_BIN"
fi

if [[ $DMED_OK -eq 0 ]] && command -v go >/dev/null 2>&1; then
    log "dmed unavailable; building via Go..."
    if go install github.com/dedomorozoff/dmed@latest 2>/dev/null; then
        install -Dm755 "$(go env GOPATH)/bin/dmed" "$DMED_BIN"
        DMED_OK=1
        log "dmed built from source -> $DMED_BIN"
    else
        warn "dmed build failed"
    fi
fi

if [[ $DMED_OK -eq 0 ]]; then
    warn "dmed binary unavailable (no GitHub, no soft/dmed, no PATH, no Go) — skipping"
fi

# 3b2) dmsh / dmcode — Arch-пакеты из GitHub-релизов (те же, что в полной
#      редакции). Их разворачивает customize_airootfs.sh: pacman -U в
#      archiso-chroot не работает, поэтому пакет просто распаковывается.
fetch_gh_pkg dmsh   dedomorozoff/dmsh   "$PROFILE_DIR/airootfs/root/dmsh"   || true
fetch_gh_pkg dmcode dedomorozoff/dmcode "$PROFILE_DIR/airootfs/root/dmcode" || true

# 3c2) vinstall — текстовый инсталлятор (обёртка над archinstall)
#     Источник: scripts/build/installer/. Копируем в airootfs (попадает в
#     /usr/local/bin и /usr/local/share установленной live-системы).
VINSTALL_DIR="$(cd "$(dirname "$(readlink -f "$0")")/installer" && pwd)"
if [[ -f "$VINSTALL_DIR/vinstall" ]]; then
    mkdir -p "$PROFILE_DIR/airootfs/usr/local/bin" \
             "$PROFILE_DIR/airootfs/usr/local/share/vibelinux"
    install -Dm755 "$VINSTALL_DIR/vinstall" "$PROFILE_DIR/airootfs/usr/local/bin/vinstall"
    install -Dm644 "$VINSTALL_DIR/share/archinstall-config.json" \
        "$PROFILE_DIR/airootfs/usr/local/share/vibelinux/archinstall-config.json"
    install -Dm644 "$VINSTALL_DIR/share/archinstall-config-en.json" \
        "$PROFILE_DIR/airootfs/usr/local/share/vibelinux/archinstall-config-en.json"
    log "vinstall installer copied -> airootfs/usr/local"
else
    warn "vinstall installer not found in scripts/build/installer/ — skipping"
fi

# 3b2) Copy AI/helper scripts to /opt/vibecode/scripts (post-install helpers).
#     Тяжёлый AI-стек (WebUI / ComfyUI / Python-venv / модели) ставится ПОСЛЕ
#     установки на диск: sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh.
#     Единый источник — scripts/ai/ (общий с полной редакцией, DRY).
SCRIPTS_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
if [[ -d "$SCRIPTS_DIR/ai" ]]; then
    log "Copying scripts/ai to airootfs/opt/vibecode/scripts/..."
    mkdir -p "$PROFILE_DIR/airootfs/opt/vibecode/scripts"
    cp -r "$SCRIPTS_DIR/ai" "$PROFILE_DIR/airootfs/opt/vibecode/scripts/"
    log "AI scripts copied to airootfs/opt/vibecode/scripts/"
else
    warn "scripts/ai not found — skipping /opt/vibecode copy"
fi

# 3c) Pre-populate /boot/vmlinuz-linux
mkdir -p "$WORKDIR/x86_64/airootfs/boot"
KVER=$(ls "$WORKDIR"/x86_64/airootfs/usr/lib/modules/ 2>/dev/null | grep -v extramodules | sort -V | tail -1 || true)
if [[ -n "$KVER" && -f "$WORKDIR/x86_64/airootfs/usr/lib/modules/$KVER/vmlinuz" ]]; then
  rm -f "$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux"
  cp --sparse=never "$WORKDIR/x86_64/airootfs/usr/lib/modules/$KVER/vmlinuz" \
     "$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux"
  log "Pre-populated /boot/vmlinuz-linux from modules/$KVER/vmlinuz"
else
  dd if=/dev/zero bs=1024 count=1 of="$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux" status=none 2>/dev/null
  log "Pre-populated /boot/vmlinuz-linux (placeholder)"
fi

# 4) Build ISO
log "Starting build with mkarchiso..."
BUILD_EXIT=0
mkarchiso -v \
    -w "$WORKDIR" \
    -o "$OUTDIR" \
    "$PROFILE_DIR" 2>&1 | tee /tmp/vibelinux-mini-build.log || BUILD_EXIT=${PIPESTATUS[0]}

if [[ $BUILD_EXIT -ne 0 ]]; then
    err "Build failed (exit $BUILD_EXIT). Check /tmp/vibelinux-mini-build.log"
    exit $BUILD_EXIT
fi

# 5) Verify result
ISO_FILE=$(ls -t "$OUTDIR"/vibelinux-*.iso 2>/dev/null | head -1)
if [[ -f "$ISO_FILE" ]]; then
    log "Done! ISO at: $ISO_FILE"
    log "Size: $(du -h "$ISO_FILE" | cut -f1)"
else
    err "Build failed. Check /tmp/vibelinux-mini-build.log"
    exit 1
fi
