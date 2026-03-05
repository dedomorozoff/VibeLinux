#!/usr/bin/env bash
set -euo pipefail

# Draft ISO build script for VibeCode OS (alpha).
# Stack choice: debootstrap + squashfs-tools + xorriso + GRUB.
#
# Modes:
#   - dry-run (default)  — проверить наличие зависимостей и базовую структуру.
#   - full               — зарезервировано для полноценной сборки ISO.
#
# Пример использования:
#   BUILD_MODE=dry-run ./scripts/build/build-iso.sh
#   BUILD_MODE=full    ./scripts/build/build-iso.sh   # в будущем, при готовности

BUILD_MODE="${BUILD_MODE:-dry-run}"

WORK_DIR="${WORK_DIR:-$PWD/build}"
CHROOT_DIR="${CHROOT_DIR:-$WORK_DIR/chroot}"
IMAGE_DIR="${IMAGE_DIR:-$WORK_DIR/image}"
ISO_OUTPUT="${ISO_OUTPUT:-$WORK_DIR/vibecode-alpha.iso}"

UBUNTU_CODENAME="${UBUNTU_CODENAME:-noble}"
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu/}"

log() {
  echo "[build-iso] $*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[build-iso] ERROR: required command '$cmd' not found in PATH" >&2
    exit 1
  fi
}

check_dependencies() {
  log "Checking required tools for debootstrap-based build..."
  require_cmd debootstrap
  require_cmd mksquashfs
  require_cmd xorriso
  require_cmd grub-mkrescue
  if ! command -v mformat >/dev/null 2>&1; then
    echo "[build-iso] ERROR: required command 'mformat' (package 'mtools') not found in PATH" >&2
    exit 1
  fi
  log "All required tools are available."
}

prepare_dirs() {
  log "Preparing build directories under '$WORK_DIR'..."
  if [[ "${KEEP_CHROOT:-0}" = "1" && -d "$CHROOT_DIR" ]]; then
    log "KEEP_CHROOT=1: preserving existing chroot at '$CHROOT_DIR', cleaning image dir only."
    rm -rf "$IMAGE_DIR"
    mkdir -p "$IMAGE_DIR"
  else
    rm -rf "$WORK_DIR"
    mkdir -p "$CHROOT_DIR" "$IMAGE_DIR"
  fi
}

mount_chroot_fs() {
  log "Mounting virtual filesystems into chroot..."
  mount --bind /dev "$CHROOT_DIR/dev"
  mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
  mount --bind /proc "$CHROOT_DIR/proc"
  mount --bind /sys "$CHROOT_DIR/sys"
}

umount_chroot_fs() {
  log "Unmounting virtual filesystems from chroot..."
  for mp in dev/pts dev proc sys; do
    if mountpoint -q "$CHROOT_DIR/$mp"; then
      umount "$CHROOT_DIR/$mp"
    fi
  done
}

chroot_run() {
  chroot "$CHROOT_DIR" /bin/bash -c "$*"
}

dry_run() {
  log "Running in dry-run mode. No ISO will be produced."
  check_dependencies
  prepare_dirs
  cat <<EOF
[build-iso] Draft pipeline (not executed in dry-run):
  1) debootstrap --arch=amd64 "$UBUNTU_CODENAME" "$CHROOT_DIR" "$UBUNTU_MIRROR"
  2) chroot into "$CHROOT_DIR" and:
       - configure apt sources
       - install base CLI tools and KDE Plasma
       - apply cleanup and branding
  3) Create SquashFS from chroot:
       mksquashfs "$CHROOT_DIR" "$IMAGE_DIR"/filesystem.squashfs
  4) Prepare ISO tree with kernel/initrd/bootloader config under "$IMAGE_DIR"
  5) Build bootable ISO with GRUB:
       grub-mkrescue -o "$ISO_OUTPUT" "$IMAGE_DIR"

This dry-run only validates:
  - choice of stack (debootstrap + squashfs-tools + xorriso + GRUB)
  - that required tools are installed
  - that build directories are prepared correctly
EOF
  log "Dry-run completed successfully."
}

full_build() {
  if [[ $EUID -ne 0 ]]; then
    echo "[build-iso] ERROR: full build must be run as root (use sudo)." >&2
    exit 1
  fi

  check_dependencies
  prepare_dirs

  if [[ "${KEEP_CHROOT:-0}" = "1" && -f "$CHROOT_DIR/etc/os-release" ]]; then
    log "KEEP_CHROOT=1 and existing chroot detected at '$CHROOT_DIR' – skipping debootstrap bootstrap step."
  else
    log "Bootstrapping Ubuntu '$UBUNTU_CODENAME' into chroot..."
    debootstrap --arch=amd64 "$UBUNTU_CODENAME" "$CHROOT_DIR" "$UBUNTU_MIRROR"
  fi

  log "Preparing chroot environment..."
  cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"
  # Включаем universe/multiverse внутри chroot, чтобы были доступны MATE/LightDM и др.
  cat > "$CHROOT_DIR/etc/apt/sources.list" <<EOF
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
  mkdir -p "$CHROOT_DIR/run"
  mount_chroot_fs
  trap umount_chroot_fs EXIT

  log "Configuring base system inside chroot..."
  chroot_run "export DEBIAN_FRONTEND=noninteractive; apt-get update -y"

  log "Installing kernel and live-related base packages..."
  chroot_run "export DEBIAN_FRONTEND=noninteractive; apt-get install -y systemd-sysv linux-image-generic casper network-manager sudo"

  log "Copying VibeCode scripts into chroot (base/desktop/drivers only)..."
  SCRIPTS_DIR_HOST="$(cd "$(dirname "$0")/.." && pwd)"
  mkdir -p "$CHROOT_DIR/opt/vibecode/scripts"
  cp -r "$SCRIPTS_DIR_HOST/base" "$CHROOT_DIR/opt/vibecode/scripts/" || true
  cp -r "$SCRIPTS_DIR_HOST/desktop" "$CHROOT_DIR/opt/vibecode/scripts/" || true
  cp -r "$SCRIPTS_DIR_HOST/drivers" "$CHROOT_DIR/opt/vibecode/scripts/" || true
  chroot_run "chmod +x /opt/vibecode/scripts/base/"*.sh || true
  chroot_run "chmod +x /opt/vibecode/scripts/desktop/"*.sh || true

  log "Installing base CLI utilities via scripts/base/base-packages.sh..."
  chroot_run "cd /opt/vibecode/scripts/base && ./base-packages.sh"

  log "Installing MATE desktop via scripts/desktop/install-mate.sh..."
  chroot_run "PROFILE=standard /opt/vibecode/scripts/desktop/install-mate.sh"

  log "Running cleanup script..."
  chroot_run "/opt/vibecode/scripts/base/cleanup.sh"

  log "Creating SquashFS for live filesystem (excluding virtual FS)..."
  # Стандартный путь для casper-окружения Ubuntu — каталог 'casper'.
  mkdir -p "$IMAGE_DIR/casper"
  # Исключаем виртуальные ФС из образа: proc/sys/dev/run/tmp и собственный boot (ядро/initrd мы копируем отдельно).
  mksquashfs "$CHROOT_DIR" "$IMAGE_DIR/casper/filesystem.squashfs" \
    -e boot proc sys dev run tmp

  log "Copying kernel and initrd to ISO tree..."
  mkdir -p "$IMAGE_DIR/boot"
  KERNEL_PATH="$(ls -1 "$CHROOT_DIR"/boot/vmlinuz-* | head -n1)"
  INITRD_PATH="$(ls -1 "$CHROOT_DIR"/boot/initrd.img-* | head -n1)"
  if [[ -z "${KERNEL_PATH:-}" || -z "${INITRD_PATH:-}" ]]; then
    echo "[build-iso] ERROR: failed to locate kernel or initrd in chroot/boot." >&2
    exit 1
  fi
  cp "$KERNEL_PATH" "$IMAGE_DIR/boot/vmlinuz"
  cp "$INITRD_PATH" "$IMAGE_DIR/boot/initrd.img"

  log "Creating GRUB configuration for live boot..."
  mkdir -p "$IMAGE_DIR/boot/grub"
  cat > "$IMAGE_DIR/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5

menuentry "VibeCode OS (live)" {
    linux /boot/vmlinuz boot=casper quiet splash ---
    initrd /boot/initrd.img
}
EOF

  log "Building ISO with grub-mkrescue..."
  grub-mkrescue -o "$ISO_OUTPUT" "$IMAGE_DIR"

  umount_chroot_fs
  trap - EXIT

  log "Full build completed. ISO located at: $ISO_OUTPUT"
}

main() {
  case "$BUILD_MODE" in
    dry-run)
      dry_run
      ;;
    full)
      full_build
      ;;
    *)
      echo "[build-iso] Unknown BUILD_MODE: '$BUILD_MODE'. Expected 'dry-run' or 'full'." >&2
      exit 1
      ;;
  esac
}

main "$@"

