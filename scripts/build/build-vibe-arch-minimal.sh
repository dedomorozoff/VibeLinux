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

# 3a) Unmount leftover chroot mounts
if grep -qs "$WORKDIR" /proc/mounts; then
    log "Unmounting leftover chroot mounts in $WORKDIR..."
    awk -v w="$WORKDIR" 'index($2, w) == 1 {print $2}' /proc/mounts | sort -r | while read -r m; do
        umount -l "$m" 2>/dev/null || true
    done
fi

# 3b) dmed — terminal-native AI editor (Go binary, no AUR package).
#     Источники (по приоритету): soft/dmed/dmed → официальный GitHub release →
#     сборка через Go. Релиз-фоллбек нужен, т.к. soft/dmed вне git и при чистой
#     сборке/CI бинарника на хосте может не быть. Кладём в /usr/local/bin.
DMED_DST="$PROFILE_DIR/airootfs/usr/local/bin/dmed"
mkdir -p "$(dirname "$DMED_DST")"
DMED_COPIED=0

# Безопасно вычисляем источник (без set -e-риска от cd в отсутствующий каталог).
DMED_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../soft/dmed" 2>/dev/null && pwd || true)"
DMED_SRC="$DMED_DIR/dmed"
if [[ -f "$DMED_SRC" ]]; then
    [[ -x "$DMED_SRC" ]] || chmod +x "$DMED_SRC"
    cp -f "$DMED_SRC" "$DMED_DST"
    DMED_COPIED=1
    log "dmed copied from soft/dmed/dmed -> $DMED_DST"
elif command -v dmed >/dev/null 2>&1; then
    cp -f "$(command -v dmed)" "$DMED_DST"
    DMED_COPIED=1
    log "dmed copied from PATH -> $DMED_DST"
fi

if [[ $DMED_COPIED -eq 0 ]] && command -v curl >/dev/null 2>&1; then
    log "dmed binary not on host; trying official GitHub release..."
    DMED_VER="$(curl -fsSL --retry 3 https://api.github.com/repos/dedomorozoff/dmed/releases/latest 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)"
    if [[ -n "$DMED_VER" ]]; then
        DMED_TMP="$(mktemp -d)"
        if curl -fsSL --retry 3 \
            "https://github.com/dedomorozoff/dmed/releases/download/${DMED_VER}/dmed-linux-amd64" \
            -o "$DMED_TMP/dmed"; then
            chmod +x "$DMED_TMP/dmed"
            cp -f "$DMED_TMP/dmed" "$DMED_DST"
            DMED_COPIED=1
            log "dmed ${DMED_VER} downloaded from GitHub -> $DMED_DST"
        else
            warn "dmed download failed"
        fi
        rm -rf "$DMED_TMP"
    fi
fi

if [[ $DMED_COPIED -eq 0 ]] && command -v go >/dev/null 2>&1; then
    log "dmed unavailable; building via Go..."
    if go install github.com/dedomorozoff/dmed@latest 2>/dev/null; then
        cp -f "$(go env GOPATH)/bin/dmed" "$DMED_DST"
        DMED_COPIED=1
        log "dmed built from source -> $DMED_DST"
    else
        warn "dmed build failed"
    fi
fi

if [[ $DMED_COPIED -eq 0 ]]; then
    warn "dmed binary unavailable (no soft/dmed, no PATH, offline, no Go) — skipping"
fi

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
