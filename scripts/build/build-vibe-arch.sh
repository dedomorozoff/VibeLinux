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
if [[ -d "$BRANDING_DIR" ]]; then
    log "Copying branding assets to airootfs..."
    mkdir -p "$PROFILE_DIR/airootfs/root/branding"
    cp -r "$BRANDING_DIR/wallpapers" "$PROFILE_DIR/airootfs/root/branding/" 2>/dev/null || true
    cp -r "$BRANDING_DIR/logos" "$PROFILE_DIR/airootfs/root/branding/" 2>/dev/null || true
    cp -r "$BRANDING_DIR/plymouth" "$PROFILE_DIR/airootfs/root/branding/" 2>/dev/null || true
    cp -r "$BRANDING_DIR/config" "$PROFILE_DIR/airootfs/root/branding/" 2>/dev/null || true

    # Convert wallpaper SVG to PNG for GRUB (GRUB doesn't support SVG)
    if [[ -f "$BRANDING_DIR/wallpapers/vibecode-dark.svg" ]]; then
        if command -v convert &>/dev/null; then
            log "Converting wallpaper to PNG (ImageMagick)..."
            convert "$BRANDING_DIR/wallpapers/vibecode-dark.svg" \
                "$PROFILE_DIR/airootfs/root/branding/wallpapers/vibecode-dark.png" 2>/dev/null || true
        elif command -v rsvg-convert &>/dev/null; then
            log "Converting wallpaper to PNG (librsvg)..."
            rsvg-convert -w 1920 -h 1080 "$BRANDING_DIR/wallpapers/vibecode-dark.svg" \
                -o "$PROFILE_DIR/airootfs/root/branding/wallpapers/vibecode-dark.png" 2>/dev/null || true
        else
            warn "Cannot convert SVG to PNG — install imagemagick or librsvg"
        fi
    fi

    # Convert logo SVG to PNG for Calamares
    if [[ -f "$BRANDING_DIR/logos/vibecodeos-logo.svg" ]] && [[ ! -f "$PROFILE_DIR/airootfs/root/branding/logos/vibecodeos-logo.png" ]]; then
        if command -v convert &>/dev/null; then
            log "Converting logo to PNG..."
            convert -background none "$BRANDING_DIR/logos/vibecodeos-logo.svg" \
                "$PROFILE_DIR/airootfs/root/branding/logos/vibecodeos-logo.png" 2>/dev/null || true
        elif command -v rsvg-convert &>/dev/null; then
            rsvg-convert -w 256 -h 256 "$BRANDING_DIR/logos/vibecodeos-logo.svg" \
                -o "$PROFILE_DIR/airootfs/root/branding/logos/vibecodeos-logo.png" 2>/dev/null || true
        fi
    fi
fi

# 3b) Copy nlsh to airootfs
SOFT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../soft" 2>/dev/null && pwd)"
if [[ -d "$SOFT_DIR/nlsh" ]]; then
    log "Copying nlsh to airootfs..."
    mkdir -p "$PROFILE_DIR/airootfs/root/nlsh"
    if [[ -f "$SOFT_DIR/nlsh/nlsh" ]]; then
        cp "$SOFT_DIR/nlsh/nlsh" "$PROFILE_DIR/airootfs/root/nlsh/"
        chmod +x "$PROFILE_DIR/airootfs/root/nlsh/nlsh"
    fi
    if [[ -f "$SOFT_DIR/nlsh/nlsh.svg" ]]; then
        cp "$SOFT_DIR/nlsh/nlsh.svg" "$PROFILE_DIR/airootfs/root/nlsh/"
    fi
    if [[ -f "$SOFT_DIR/nlsh/nlsh.desktop" ]]; then
        cp "$SOFT_DIR/nlsh/nlsh.desktop" "$PROFILE_DIR/airootfs/root/nlsh/"
    fi
    log "nlsh copied to airootfs/root/nlsh/"
else
    warn "nlsh not found in soft/nlsh/ — skipping"
fi

log "Using profile: $PROFILE_DIR"
log "Work dir: $WORKDIR"
log "Output dir: $OUTDIR"

# 4) Cleanup / force rebuild
if [[ "${CLEAN:-0}" == "1" ]]; then
    log "Cleaning working directory..."
    rm -rf "$WORKDIR"
elif [[ -d "$WORKDIR" ]]; then
    # Incremental rebuild: remove mkarchiso _run_once markers for steps after
    # _make_packages (keep it to avoid re-installing packages).
    log "Removing run-once markers (incremental rebuild)..."
    # Remove all markers except work_dir, pacman_conf, version, and packages
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

# 4b) Pre-populate /boot/vmlinuz-linux before mkarchiso runs pacstrap.
#     The mkinitcpio hook (90-mkinitcpio-install) expects this file to exist
#     when it calls mkinitcpio -P, but the linux package does not ship it
#     directly — the hook's install_kernel() copies it from /usr/lib/modules/.
#     If that copy fails (relative-path race), /boot/vmlinuz-linux stays 0‑byte
#     and mkinitcpio -P errors: "must be readable".
#     Copying the kernel here (rather than using a symlink) ensures the host-side
#     install/cp in mkarchiso's _make_boot_on_iso9660 can stat the file.
mkdir -p "$WORKDIR/x86_64/airootfs/boot"
KVER=$(ls "$WORKDIR"/x86_64/airootfs/usr/lib/modules/ 2>/dev/null | grep -v extramodules | sort -V | tail -1)
if [[ -n "$KVER" && -f "$WORKDIR/x86_64/airootfs/usr/lib/modules/$KVER/vmlinuz" ]]; then
  # kernel already installed (incremental build) – copy it directly
  cp "$WORKDIR/x86_64/airootfs/usr/lib/modules/$KVER/vmlinuz" \
     "$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux"
  log "Pre-populated /boot/vmlinuz-linux from /usr/lib/modules/$KVER/vmlinuz"
else
  # first build – placeholder; pacstrap + mkinitcpio hook will fill it
  touch "$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux"
  log "Pre-populated /boot/vmlinuz-linux (empty placeholder)"
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
