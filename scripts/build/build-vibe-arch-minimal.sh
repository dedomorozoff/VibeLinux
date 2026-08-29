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

# 3b) dmed — terminal-native AI editor (Go binary, no AUR package)
#     Источник: soft/dmed/dmed (вне git). Если бинарника нет — пытаемся собрать
#     через Go, иначе предупреждаем. Кладём в airootfs/usr/local/bin (попадает
#     в /usr/local/bin установленной live-системы).
DMED_DST="$PROFILE_DIR/airootfs/usr/local/bin/dmed"
DMED_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../soft/dmed" 2>/dev/null && pwd)"
DMED_SRC="$DMED_DIR/dmed"
if [[ -f "$DMED_SRC" ]]; then
    if [[ ! -x "$DMED_SRC" ]]; then
        chmod +x "$DMED_SRC"
    fi
    mkdir -p "$(dirname "$DMED_DST")"
    cp -f "$DMED_SRC" "$DMED_DST"
    log "dmed copied from soft/dmed/dmed -> $DMED_DST"
elif command -v dmed >/dev/null 2>&1; then
    mkdir -p "$(dirname "$DMED_DST")"
    cp -f "$(command -v dmed)" "$DMED_DST"
    log "dmed copied from PATH -> $DMED_DST"
elif command -v go >/dev/null 2>&1; then
    log "dmed binary not found; building via Go..."
    mkdir -p "$(dirname "$DMED_DST")"
    if go install github.com/dedomorozoff/dmed@latest 2>/dev/null; then
        cp -f "$(go env GOPATH)/bin/dmed" "$DMED_DST"
        log "dmed built from source -> $DMED_DST"
    else
        warn "dmed build failed — skipping"
    fi
else
    warn "dmed binary unavailable (no soft/dmed, no PATH binary, no Go) — skipping"
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
