#!/bin/sh
# VibeBSD — шаг 1.7: вычистить из jail то, что не нужно в live-образе.
#   - rust: 1.3 ГБ, ставится post-install (pkg install rust)
#   - postgresql18-client: нужен только gdal (PG-драйвер), в live не нужен
#   - samba416: нужен только для smb:// в kioslave — режем по требованию
# Остальное (go, node, python, ollama, Plasma) остаётся.
set -eu
JAIL="/usr/local/poudriere/jails/vibebsd"
log() { printf '\033[1;34m[vibebsd]\033[0m %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }

mount -t devfs devfs "$JAIL/dev" 2>/dev/null || true
trap 'umount "$JAIL/dev" 2>/dev/null || true' EXIT

log "Removing rust (post-install instead)..."
chroot "$JAIL" pkg delete -y rust || true

log "Removing postgresql18-client (only gdal's PG driver uses it)..."
chroot "$JAIL" pkg delete -y -f postgresql18-client || true

log "Removing samba416 (drops smb:// kioslave only)..."
chroot "$JAIL" pkg delete -y -f samba416 || true

log "Autoremove orphans + clean cache..."
chroot "$JAIL" pkg autoremove -y
chroot "$JAIL" pkg clean -y

log "Jail size: $(du -sm "$JAIL" | awk '{print $1}') MB"
