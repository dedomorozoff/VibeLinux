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

# 3b) Fetch dmsh into airootfs.
# Primary source — pre-built Arch package from GitHub releases
# (https://github.com/dedomorozoff/dmsh), always the latest stable version.
# Local soft/dmsh/*.pkg.tar.zst kept as an offline fallback; icon/desktop
# assets are still taken from soft/dmsh (they are not shipped in releases).
DMSH_RELEASES_API="https://api.github.com/repos/dedomorozoff/dmsh/releases/latest"
DMSH_DST="$PROFILE_DIR/airootfs/root/dmsh"
SOFT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/../../soft" 2>/dev/null && pwd || true)"
log "Fetching dmsh into airootfs..."
mkdir -p "$DMSH_DST"
# Вычищаем старые пакеты/бинарники, чтобы в профиле не копилось мусор
# и ls не подсовывал устаревшие версии
rm -f "$DMSH_DST"/*.pkg.tar.zst "$DMSH_DST/dmsh"

DMSH_OK=0
DMSH_JSON="$(curl -fsSL --retry 3 "$DMSH_RELEASES_API" 2>/dev/null || true)"
DMSH_URL="$(grep -o 'https://[^"]*x86_64\.pkg\.tar\.zst' <<<"$DMSH_JSON" | head -1 || true)"
if [[ -n "$DMSH_URL" ]]; then
    if curl -fsSL --retry 3 "$DMSH_URL" -o "$DMSH_DST/$(basename "$DMSH_URL")"; then
        DMSH_OK=1
        log "dmsh downloaded from GitHub releases: $(basename "$DMSH_URL")"
    else
        warn "dmsh download failed: $DMSH_URL"
    fi
else
    warn "dmsh release info unavailable (network?) — trying local fallback"
fi

if [[ $DMSH_OK -eq 0 && -d "$SOFT_DIR/dmsh" ]] && compgen -G "$SOFT_DIR/dmsh/*.pkg.tar.zst" >/dev/null; then
    cp "$SOFT_DIR"/dmsh/*.pkg.tar.zst "$DMSH_DST/"
    DMSH_OK=1
    log "Using local pre-built dmsh package from soft/dmsh/"
fi

# Иконка и .desktop в релизы не входят — берём из soft/dmsh, если есть
if [[ -d "$SOFT_DIR/dmsh" ]]; then
    [[ -f "$SOFT_DIR/dmsh/dmsh.svg" ]] && cp "$SOFT_DIR/dmsh/dmsh.svg" "$DMSH_DST/"
    [[ -f "$SOFT_DIR/dmsh/dmsh.desktop" ]] && cp "$SOFT_DIR/dmsh/dmsh.desktop" "$DMSH_DST/"
fi

if [[ $DMSH_OK -eq 1 ]]; then
    log "dmsh ready in airootfs/root/dmsh/"
else
    warn "dmsh package unavailable (no network and none in soft/dmsh/) — skipping"
fi

# 3c) Copy AI/helper scripts to /opt/vibecode/scripts (post-install helpers).
# В live-сессии доустановка AI-инструментов невозможна (оверлей в RAM),
# поэтому тяжёлый AI-стек (WebUI / ComfyUI / Python-venv / модели)
# ставится ПОСЛЕ установки на диск: sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh
SCRIPTS_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
if [[ -d "$SCRIPTS_DIR/ai" ]]; then
    log "Copying scripts/ai to airootfs/opt/vibecode/scripts/..."
    mkdir -p "$PROFILE_DIR/airootfs/opt/vibecode/scripts"
    cp -r "$SCRIPTS_DIR/ai" "$PROFILE_DIR/airootfs/opt/vibecode/scripts/"
    log "AI scripts copied to airootfs/opt/vibecode/scripts/"
else
    warn "scripts/ai not found — skipping /opt/vibecode copy"
fi

# 3d) Seed AUR package cache (calamares/yay-bin): host → profile airootfs.
#     customize_airootfs.sh ставит из кэша без компиляции; свежесобранное
#     складывает обратно в /root/aur-cache, откуда мы забираем после сборки.
AUR_CACHE_DIR="${AUR_CACHE_DIR:-/srv/vibe-aur-cache}"
mkdir -p "$AUR_CACHE_DIR" "$PROFILE_DIR/airootfs/root/aur-cache"
if compgen -G "$AUR_CACHE_DIR/*.pkg.tar.zst" >/dev/null; then
    cp -u "$AUR_CACHE_DIR"/*.pkg.tar.zst "$PROFILE_DIR/airootfs/root/aur-cache/"
    log "AUR cache seeded: $(ls "$AUR_CACHE_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l) pkg(s)"
else
    log "AUR cache empty — calamares/yay-bin будут собраны и закэшированы"
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

# 4a) Unmount leftover chroot mounts from previously interrupted builds.
#     Если proc/sys/dev остались смонтированы в airootfs, mksquashfs начнёт
#     «сжимать» псевдо-файлы ядра (например /proc/kcore) и зависнет.
if grep -qs "$WORKDIR" /proc/mounts; then
    log "Unmounting leftover chroot mounts in $WORKDIR..."
    awk -v w="$WORKDIR" 'index($2, w) == 1 {print $2}' /proc/mounts | sort -r | while read -r m; do
        umount -l "$m" 2>/dev/null || true
    done
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
KVER=$(ls "$WORKDIR"/x86_64/airootfs/usr/lib/modules/ 2>/dev/null | grep -v extramodules | sort -V | tail -1 || true)
if [[ -n "$KVER" && -f "$WORKDIR/x86_64/airootfs/usr/lib/modules/$KVER/vmlinuz" ]]; then
  # kernel already installed (incremental build) – copy it directly
  # Remove any dangling symlink from a previous run first
  rm -f "$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux"
  cp --sparse=never "$WORKDIR/x86_64/airootfs/usr/lib/modules/$KVER/vmlinuz" \
     "$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux"
  log "Pre-populated /boot/vmlinuz-linux from /usr/lib/modules/$KVER/vmlinuz (non-sparse)"
else
  # first build – placeholder (non-sparse, 1 block); pacstrap + mkinitcpio hook will fill it
  dd if=/dev/zero bs=1024 count=1 of="$WORKDIR/x86_64/airootfs/boot/vmlinuz-linux" status=none 2>/dev/null
  log "Pre-populated /boot/vmlinuz-linux (1024-byte placeholder, non-sparse)"
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
    # Harvest freshly built AUR packages back to host cache
    if compgen -G "$WORKDIR/x86_64/airootfs/root/aur-cache/*.pkg.tar.zst" >/dev/null; then
        cp -u "$WORKDIR/x86_64/airootfs/root/aur-cache/"*.pkg.tar.zst "$AUR_CACHE_DIR/"
        log "AUR cache updated: $(ls "$AUR_CACHE_DIR"/*.pkg.tar.zst | wc -l) pkg(s)"
    fi
    log "Done! ISO at: $ISO_FILE"
    log "Size: $(du -h "$ISO_FILE" | cut -f1)"
    xorriso -indev "$ISO_FILE" -report_el_torito plain 2>&1 | head -20
else
    err "Build failed. Check /tmp/vibelinux-build.log"
    exit 1
fi
