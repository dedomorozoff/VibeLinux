#!/usr/bin/env bash
# VibeLinux ISO builder — Arch Linux (rolling release)
set -euo pipefail

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="${WORKDIR:-/srv/vibe-iso-work}"
OUTDIR="${OUTDIR:-$PWD/out}"
PROFILE_DIR="$(dirname "$(readlink -f "$0")")/../../archiso-vibelinux"
PROFILE_DIR="$(cd "$PROFILE_DIR" && pwd)"
REPO_DIR="${REPO_DIR:-/srv/vibe-aur-repo}"

log() { printf "\033[1;34m[vibe]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }

cleanup_pacman_conf() {
    if grep -q "^\[aur-local\]" "$PROFILE_DIR/pacman.conf" 2>/dev/null; then
        sed -i '/^\[aur-local\]/,/^$/d' "$PROFILE_DIR/pacman.conf"
    fi
}
trap cleanup_pacman_conf EXIT

mkdir -p "$OUTDIR"

# 1) Check dependencies
log "Checking dependencies..."
if ! command -v mkarchiso >/dev/null 2>&1; then
    log "Installing archiso..."
    pacman -Sy --noconfirm archiso
fi

# 2) Pre-build AUR packages
AUR_SCRIPT="$(dirname "$(readlink -f "$0")")/prepare-aur.sh"
if [[ -x "$AUR_SCRIPT" ]]; then
    log "Pre-building AUR packages..."
    ORIG_USER="${SUDO_USER:-}"
    if [[ -n "$ORIG_USER" ]]; then
        AUR_DIR=/tmp/vibe-aur-build \
        REPO_DIR="$REPO_DIR" \
        sudo -u "$ORIG_USER" bash "$AUR_SCRIPT" || warn "AUR pre-build had failures"
    else
        warn "SUDO_USER not set, skipping AUR pre-build"
    fi

    # Add local repo to pacman.conf if AUR repo was created
    if [[ -f "$REPO_DIR/aur-local.db.tar.gz" ]]; then
        log "Adding local AUR repo to pacman.conf..."
        if ! grep -q "^\[aur-local\]" "$PROFILE_DIR/pacman.conf" 2>/dev/null; then
            cat >> "$PROFILE_DIR/pacman.conf" << EOF

[aur-local]
SigLevel = Never
Server = file://$REPO_DIR
EOF
        fi
    fi
else
    warn "AUR pre-build script not found: $AUR_SCRIPT"
fi

# 3) Check profile
if [[ ! -d "$PROFILE_DIR" ]]; then
    err "Profile directory not found: $PROFILE_DIR"
    exit 1
fi

# 4) Copy branding
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

# 5) Cleanup (optional)
if [[ "${CLEAN:-0}" == "1" ]]; then
    log "Cleaning working directory..."
    rm -rf "$WORKDIR"
fi

# 6) Build ISO
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

# 7) Verify result
ISO_FILE=$(ls -t "$OUTDIR"/vibelinux-*.iso 2>/dev/null | head -1)
if [[ -f "$ISO_FILE" ]]; then
    log "Done! ISO at: $ISO_FILE"
    log "Size: $(du -h "$ISO_FILE" | cut -f1)"
    xorriso -indev "$ISO_FILE" -report_el_torito plain 2>&1 | head -20
else
    err "Build failed. Check /tmp/vibelinux-build.log"
    exit 1
fi
