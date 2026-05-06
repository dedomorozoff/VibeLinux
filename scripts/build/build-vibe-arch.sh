#!/usr/bin/env bash
# VibeLinux ISO builder — Arch Linux (rolling release)
# Сборка через стандартный mkarchiso (reliable method)
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

# 1) Проверка зависимостей
log "Checking dependencies..."
if ! command -v mkarchiso >/dev/null 2>&1; then
    log "Installing archiso..."
    pacman -Sy --noconfirm archiso
fi

# 2) Проверка профиля
if [[ ! -d "$PROFILE_DIR" ]]; then
    err "Profile directory not found: $PROFILE_DIR"
    err "Expected archiso-vibelinux/ next to scripts/"
    exit 1
fi

log "Using profile: $PROFILE_DIR"
log "Work dir: $WORKDIR"
log "Output dir: $OUTDIR"

# 3) Очистка (опционально)
if [[ "${CLEAN:-0}" == "1" ]]; then
    log "Cleaning working directory..."
    rm -rf "$WORKDIR"
fi

# 4) Сборка ISO
log "Starting build with mkarchiso..."
mkarchiso -v \
    -w "$WORKDIR" \
    -o "$OUTDIR" \
    "$PROFILE_DIR" 2>&1 | tee /tmp/vibelinux-build.log; exit ${PIPESTATUS[0]}

# 5) Проверка результата
ISO_FILE=$(ls -t "$OUTDIR"/vibelinux-*.iso 2>/dev/null | head -1)
if [[ -f "$ISO_FILE" ]]; then
    log "Done! ISO at: $ISO_FILE"
    log "Size: $(du -h "$ISO_FILE" | cut -f1)"
    
    # Проверка загрузочных секторов
    log "Verifying boot structure..."
    xorriso -indev "$ISO_FILE" -report_el_torito plain 2>&1 | head -20
else
    err "Build failed. Check /tmp/vibelinux-build.log"
    exit 1
fi
