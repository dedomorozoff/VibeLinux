#!/usr/bin/env bash
# VibeLinux ISO builder — Arch Linux (rolling release)
# Сборка через стандартный mkarchiso
set -euo pipefail

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="${WORKDIR:-/srv/vibe-iso-work}"
OUTDIR="${OUTDIR:-$PWD/out}"
PROFILE_DIR="$(dirname "$(readlink -f "$0")")/../../archiso-vibelinux"
PROFILE_DIR="$(cd "$PROFILE_DIR" && pwd)"

log() { printf "\033[1;34m[vibe]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }

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

# 3) Copy branding to airootfs
BRANDING_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../branding" 2>/dev/null && pwd)"
if [[ -d "$BRANDING_DIR/wallpapers" ]]; then
    log "Copying branding assets to airootfs..."
    mkdir -p "$PROFILE_DIR/airootfs/root/branding"
    cp -r "$BRANDING_DIR/wallpapers" "$PROFILE_DIR/airootfs/root/branding/"
    cp -r "$BRANDING_DIR/logos" "$PROFILE_DIR/airootfs/root/branding/" 2>/dev/null || true
fi

log "Using profile: $PROFILE_DIR"
log "Work dir: $WORKDIR"
log "Output dir: $OUTDIR"

# 4) Cleanup (optional)
if [[ "${CLEAN:-0}" == "1" ]]; then
    log "Cleaning working directory..."
    rm -rf "$WORKDIR"
fi

# 5) Build ISO
log "Starting build with mkarchiso..."
BUILD_EXIT=0
mkarchiso -v \
    -w "$WORKDIR" \
    -o "$OUTDIR" \
    "$PROFILE_DIR" 2>&1 | tee /tmp/vibelinux-build.log || BUILD_EXIT=${PIPESTATUS[0]}

if [[ $BUILD_EXIT -ne 0 ]]; then
    err "Build failed (exit $BUILD_EXIT). Check /tmp/vibelinux-build.log"
    exit $BUILD_EXIT
fi

# 6) Verify result
ISO_FILE=$(ls -t "$OUTDIR"/vibelinux-*.iso 2>/dev/null | head -1)
if [[ -f "$ISO_FILE" ]]; then
    log "Done! ISO at: $ISO_FILE"
    log "Size: $(du -h "$ISO_FILE" | cut -f1)"
    xorriso -indev "$ISO_FILE" -report_el_torito plain 2>&1 | head -20
else
    err "Build failed. Check /tmp/vibelinux-build.log"
    exit 1
fi
