#!/usr/bin/env bash
# Pre-build AUR packages for VibeLinux ISO
# Creates a local pacman repo that mkarchiso uses for installation
set -euo pipefail

AUR_DIR="${AUR_DIR:-/tmp/vibe-aur-build}"
REPO_DIR="${REPO_DIR:-/srv/vibe-aur-repo}"
REPO_NAME="${REPO_NAME:-aur-local}"

if [[ $EUID -eq 0 ]]; then
  echo "Do not run as root. Run as a regular user with sudo access."
  exit 1
fi

log() { printf "\033[1;34m[vibe-aur]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }

AUR_PACKAGES=(
  "yay-bin"
  "bruno-bin"
  "calamares"
  "pinta-appimage"
)

mkdir -p "$AUR_DIR" "$REPO_DIR"
BUILT_PKGS=()

for pkg in "${AUR_PACKAGES[@]}"; do
  log "Building $pkg..."
  cd "$AUR_DIR"
  rm -rf "$pkg"
  git clone --depth 1 "https://aur.archlinux.org/$pkg.git" 2>&1 | tail -1 || true
  cd "$pkg" || continue
  if makepkg --noconfirm --skippgpcheck 2>&1 | tail -5; then
    log "$pkg built successfully"
    PKG_FILE=$(ls *.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -n "$PKG_FILE" ]]; then
      cp "$PKG_FILE" "$REPO_DIR/"
      BUILT_PKGS+=("$REPO_DIR/$PKG_FILE")
    fi
  else
    warn "$pkg build failed"
  fi
done

if [[ ${#BUILT_PKGS[@]} -eq 0 ]]; then
  warn "No packages were built"
  exit 1
fi

log "Creating local repo $REPO_NAME at $REPO_DIR..."
cd "$REPO_DIR"
repo-add --new "$REPO_NAME.db.tar.gz" "${BUILT_PKGS[@]}" 2>&1 | tail -3

log "Local repo ready at $REPO_DIR"
log "Packages: ${BUILT_PKGS[*]}"
echo ""
echo "Add to pacman.conf:"
echo "  [$REPO_NAME]"
echo "  SigLevel = Never"
echo "  Server = file://$REPO_DIR"
echo ""
echo "Add to packages.x86_64: ${AUR_PACKAGES[*]}"
