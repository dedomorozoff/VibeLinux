#!/usr/bin/env bash
# ============================================================================
# VibeLinux Config-to-Script Generator
# ============================================================================
# Читает JSON-конфигурацию и генерирует скрипт сборки ISO
# Использование: ./generate-build-script.sh config.json output.sh
# ============================================================================

set -euo pipefail

CONFIG_FILE="${1:-scripts/base/vibe-config-template.json}"
OUTPUT_FILE="${2:-scripts/build/build-vibe-generated.sh}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE"
  exit 1
fi

# Читаем конфигурацию
DISTRO=$(jq -r '.distro // "ubuntu-24.04"' "$CONFIG_FILE")
BUILD_TYPE=$(jq -r '.build_type // "full"' "$CONFIG_FILE")
USERNAME=$(jq -r '.user // "vibe"' "$CONFIG_FILE")
HOSTNAME=$(jq -r '.hostname // "vibelinux"' "$CONFIG_FILE")
NVIDIA=$(jq -r '.nvidia // false' "$CONFIG_FILE")
OLLAMA=$(jq -r '.ollama // false' "$CONFIG_FILE")

# Преобразуем массивы в строки
EDITORS=$(jq -r '.editors // [] | join(",")' "$CONFIG_FILE")
AGENTS=$(jq -r '.agents // [] | join(",")' "$CONFIG_FILE")
RUNTIMES=$(jq -r '.runtimes // [] | join(",")' "$CONFIG_FILE")
TOOLS=$(jq -r '.tools // [] | join(",")' "$CONFIG_FILE")

# Определяем флаги
HAS_NODE=0; echo "$RUNTIMES" | grep -q "node" && HAS_NODE=1
HAS_BUN=0; echo "$RUNTIMES" | grep -q "bun" && HAS_BUN=1
HAS_DENO=0; echo "$RUNTIMES" | grep -q "deno" && HAS_DENO=1
HAS_PY=0; echo "$RUNTIMES" | grep -q "python" && HAS_PY=1
HAS_RUST=0; echo "$RUNTIMES" | grep -q "rust" && HAS_RUST=1
HAS_GO=0; echo "$RUNTIMES" | grep -q "go" && HAS_GO=1

HAS_NEOVIM=0; echo "$EDITORS" | grep -q "neovim" && HAS_NEOVIM=1
HAS_HELIX=0; echo "$EDITORS" | grep -q "helix" && HAS_HELIX=1
HAS_ZED=0; echo "$EDITORS" | grep -q "zed" && HAS_ZED=1
HAS_VSCODE=0; echo "$EDITORS" | grep -q "vscode\|code" && HAS_VSCODE=1

HAS_AIDER=0; echo "$AGENTS" | grep -q "aider" && HAS_AIDER=1

echo "Generating build script from: $CONFIG_FILE"
echo "  Distro: $DISTRO"
echo "  Build type: $BUILD_TYPE"
echo "  User: $USERNAME"
echo "  Editors: $EDITORS"
echo "  Agents: $AGENTS"
echo "  Runtimes: $RUNTIMES"
echo "  Tools: $TOOLS"

cat > "$OUTPUT_FILE" << HEADER
#!/usr/bin/env bash
# VibeLinux ISO builder — Generated from config
# Distro: $DISTRO | Build: $BUILD_TYPE | Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
set -euo pipefail

need_root() { if [[ \$EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="\${WORKDIR:-/srv/vibe-iso}"
OUTDIR="\${OUTDIR:-\$PWD/out}"
USERNAME="$USERNAME"
HOSTNAME="$HOSTNAME"
DISTRO="$DISTRO"
BUILD_TYPE="$BUILD_TYPE"

log() { printf "\033[1;34m[vibe]\033[0m %s\n" "\$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "\$*"; }
err() { printf "\033[1;31m[err]\033[0m %s\n" "\$*" >&2; }

mkdir -p "\$WORKDIR" "\$OUTDIR"
cd "\$WORKDIR"

# 1) Host deps
log "Installing build dependencies..."

if [[ ! -c /dev/null ]]; then
  err "/dev/null is not a character device!"
  err "Fix with: sudo mknod -m 666 /dev/null c 1 3"
  exit 1
fi

case "\$DISTRO" in
  ubuntu-24.04|debian-13)
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y --fix-broken \\
      debootstrap squashfs-tools xorriso grub-common grub-pc-bin grub-efi-amd64-bin mtools \\
      dosfstools unzip curl wget git rsync python3 python3-pip
    ;;
  arch)
    pacman -Sy --noconfirm archiso squashfs-tools xorriso grub dosfstools mtools wget curl git rsync python
    ;;
  fedora-43)
    dnf -y install livecd-tools spin-kickstarts squashfs-tools xorriso grub2-efi-x64 grub2-pc dosfstools mtools wget curl git rsync python3
    ;;
  *) err "Unsupported distro"; exit 1;;
esac

# 2) Bootstrap rootfs
log "Preparing base system..."
ROOTFS="\$WORKDIR/rootfs"

if mountpoint -q "\$ROOTFS/sys" 2>/dev/null; then
  umount -l "\$ROOTFS/sys" "\$ROOTFS/proc" "\$ROOTFS/dev" 2>/dev/null || true
fi

if [[ -d "\$ROOTFS/usr/bin" ]]; then
  log "Using cached rootfs (skip bootstrap)..."
else
  rm -rf "\$ROOTFS"
  mkdir -p "\$ROOTFS"
fi

bootstrap_debian() {
  if [[ "\$DISTRO" == "ubuntu-24.04" ]]; then
    debootstrap --arch=amd64 noble "\$ROOTFS" http://archive.ubuntu.com/ubuntu/
  else
    debootstrap --arch=amd64 trixie "\$ROOTFS" http://deb.debian.org/debian/
  fi

  mount --bind /dev "\$ROOTFS/dev"
  mount -t devpts devpts "\$ROOTFS/dev/pts"
  mount -t tmpfs tmpfs "\$ROOTFS/dev/shm"
  mount -t proc /proc "\$ROOTFS/proc"
  mount -t sysfs /sys "\$ROOTFS/sys"
  mount --bind /dev/random "\$ROOTFS/dev/random"
  mount --bind /dev/urandom "\$ROOTFS/dev/urandom"
  cp /etc/resolv.conf "\$ROOTFS/etc/resolv.conf" || true

  chroot "\$ROOTFS" bash -c "sed -i 's/main\$/main universe multiverse restricted/' /etc/apt/sources.list || true"
  chroot "\$ROOTFS" apt update
  chroot "\$ROOTFS" apt install -y --fix-broken linux-image-generic zsh curl wget git sudo locales python3-full python3-pip python3-venv live-boot live-config

  umount -l "\$ROOTFS/dev/random" "\$ROOTFS/dev/urandom" "\$ROOTFS/dev/pts" "\$ROOTFS/dev/shm" "\$ROOTFS/dev" "\$ROOTFS/proc" "\$ROOTFS/sys" 2>/dev/null || true
}

bootstrap_arch() {
  mkdir -p "\$ROOTFS"
  pacstrap -K "\$ROOTFS" base linux linux-firmware zsh sudo curl wget git
}

bootstrap_fedora() {
  dnf --releasever=43 --setopt=install_weak_deps=False --installroot="\$ROOTFS" -y install @core kernel zsh sudo curl wget git
}

if [[ ! -d "\$ROOTFS/usr/bin" ]]; then
  case "\$DISTRO" in
    ubuntu-24.04|debian-13) bootstrap_debian ;;
    arch) bootstrap_arch ;;
    fedora-43) bootstrap_fedora ;;
  esac
fi

# 3) Chroot customization
log "Customizing system in chroot..."
cat > "\$ROOTFS/tmp/customize.sh" << 'EOS'
set -e
export DEBIAN_FRONTEND=noninteractive
USERNAME="__USER__"
HOSTNAME="__HOST__"

id "\$USERNAME" &>/dev/null || useradd -m -s /usr/bin/zsh "\$USERNAME"
echo "\$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe

echo "\$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost \$HOSTNAME" > /etc/hosts

locale-gen en_US.UTF-8 ru_RU.UTF-8 || true
update-locale LANG=ru_RU.UTF-8 || true

cat > /etc/default/keyboard << KBD
XKBLAYOUT="us,ru"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
KBD

if command -v apt >/dev/null 2>&1; then
  sed -i 's/main\$/main universe multiverse restricted/' /etc/apt/sources.list || true
  apt update

  apt install -y \\
    pipewire wireplumber pipewire-audio \\
    network-manager \\
    xdg-desktop-portal xdg-desktop-portal-gtk \\
    fonts-firacode fonts-noto-core fonts-noto-color-emoji \\
    udev systemd-timesyncd zsh git curl wget unzip jq fzf ripgrep tmux \\
    python3-full python3-pip python3-venv \\
    systemd zstd

  if [[ "__BUILD_TYPE__" == "full" ]]; then
    apt install -y build-essential pkg-config docker.io
  fi

  systemctl enable NetworkManager || true
  systemctl enable docker || true
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm pipewire wireplumber networkmanager iwd xdg-desktop-portal \\
    ttf-fira-code noto-fonts noto-fonts-emoji base-devel git curl wget unzip jq fzf ripgrep tmux python python-pip docker zstd
  systemctl enable NetworkManager
  systemctl enable docker
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install pipewire wireplumber NetworkManager iwd xdg-desktop-portal \\
    fira-code-fonts google-noto* git curl wget unzip jq fzf ripgrep tmux python3 python3-pip docker zstd
  systemctl enable NetworkManager
  systemctl enable docker
fi

chsh -s /usr/bin/zsh "\$USERNAME" || true
rm -rf /home/\$USERNAME/.oh-my-zsh || true
runuser -u "\$USERNAME" -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended || true'
runuser -u "\$USERNAME" -- bash -lc 'curl -sS https://starship.rs/install.sh | sh -s -- -y || true'
runuser -u "\$USERNAME" -- bash -lc 'mkdir -p ~/.config && echo "eval \$(starship init zsh)" >> ~/.zshrc'

# === Языки ===
if [[ "__HAS_NODE__" == "1" ]]; then
  runuser -u "\$USERNAME" -- bash -lc 'curl -fsSL https://fnm.vercel.app/install | bash'
  runuser -u "\$USERNAME" -- bash -lc 'export PATH="\$HOME/.local/share/fnm:\$PATH"; eval "\$(fnm env)"; fnm install --lts; fnm default lts-latest'
fi
if [[ "__HAS_BUN__" == "1" ]]; then
  runuser -u "\$USERNAME" -- bash -c 'if [ ! -f "\$HOME/.bun/bin/bun" ]; then curl -fsSL https://bun.sh/install | bash; fi'
  echo 'export PATH="\$HOME/.bun/bin:\$PATH"' >> /home/\$USERNAME/.zshrc
fi
if [[ "__HAS_DENO__" == "1" ]]; then
  runuser -u "\$USERNAME" -- bash -c 'if [ ! -d "\$HOME/.deno" ]; then curl -fsSL https://deno.land/install.sh | sh; fi'
  echo 'export PATH="\$HOME/.deno/bin:\$PATH"' >> /home/\$USERNAME/.zshrc
fi
if [[ "__HAS_RUST__" == "1" ]]; then
  runuser -u "\$USERNAME" -- bash -lc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
fi
if [[ "__HAS_GO__" == "1" ]]; then
  curl -fsSL https://go.dev/dl/go1.22.0.linux-amd64.tar.gz -o /tmp/go.tgz
  tar -C /usr/local -xzf /tmp/go.tgz
  echo 'export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin' >> /home/\$USERNAME/.zshrc
fi

# === Редактор ===
if [[ "__HAS_ZED__" == "1" ]]; then
  runuser -u "\$USERNAME" -- bash -lc 'curl -f https://zed.dev/install.sh 2>/dev/null | sh' || echo "WARNING: Zed install failed"
fi

# === AI-агенты ===
if [[ "__HAS_AIDER__" == "1" ]]; then
  pip3 install --break-system-packages --ignore-installed aider-chat
fi
if [[ "__HAS_OLLAMA__" == "1" ]]; then
  curl -fsSL https://ollama.com/install.sh | sh
  systemctl enable ollama || true
fi

# === NVIDIA ===
if [[ "__NVIDIA__" == "1" ]]; then
  if command -v apt >/dev/null 2>&1; then
    apt install -y ubuntu-drivers-common
    ubuntu-drivers autoinstall || true
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm nvidia nvidia-utils
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install akmod-nvidia
  fi
fi

# === Autologin ===
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin \$USERNAME --noclear %I \$TERM
CONF

# === Vibe Wizard ===
mkdir -p /usr/local/bin
cat > /usr/local/bin/vibe-wizard << 'WIZ'
#!/usr/bin/env bash
set -e
CONFIG=/etc/vibe/config.json
echo "Vibe post-install wizard"
echo "Config: \$CONFIG"
if command -v whiptail >/dev/null 2>&1; then
  SEL=\$(whiptail --title "Vibe Wizard" --checklist "Выберите компоненты" 20 78 8 \\
    "zed" "Zed editor" OFF \\
    "vscode" "VS Code" OFF \\
    "neovim" "Neovim" ON \\
    "aider" "Aider agent" OFF \\
    "ollama" "Ollama local LLM" OFF \\
    "docker" "Docker" OFF 3>&1 1>&2 2>&3) || true
  echo "Selected: \$SEL" > /tmp/vibe-wizard.log
fi
echo "Готово. При желании установите выбранные компоненты вручную."
WIZ
chmod +x /usr/local/bin/vibe-wizard

# === Systemd service for wizard ===
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/vibe-wizard.service << SVCEOF
[Unit]
Description=Vibe Post-Install Wizard
After=graphical-session.target
ConditionPathExists=!/home/\${USERNAME}/.vibe-wizard-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vibe-wizard
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
SVCEOF
systemctl enable vibe-wizard.service 2>/dev/null || true

echo "Custom chroot done."
EOS

# apply replacements
sed -i "s|__USER__|$USERNAME|g; s|__HOST__|$HOSTNAME|g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__NVIDIA__/$([ "$NVIDIA" = "true" ] && echo "1" || echo "0")/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__BUILD_TYPE__/$BUILD_TYPE/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NODE__/$HAS_NODE/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_BUN__/$HAS_BUN/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_DENO__/$HAS_DENO/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_PY__/$HAS_PY/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_RUST__/$HAS_RUST/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_GO__/$HAS_GO/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NEOVIM__/$HAS_NEOVIM/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_HELIX__/$HAS_HELIX/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_AIDER__/$HAS_AIDER/g" "\$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_OLLAMA__/$([ "$OLLAMA" = "true" ] && echo "1" || echo "0")/g" "\$ROOTFS/tmp/customize.sh"

mkdir -p "\$ROOTFS/etc/vibe"
cp "$(dirname "$0")/../base/vibe-config-template.json" "\$ROOTFS/etc/vibe/config.json"

log "Running chroot customization..."
mount --bind /dev "\$ROOTFS/dev"
mount -t devpts devpts "\$ROOTFS/dev/pts"
mount -t tmpfs tmpfs "\$ROOTFS/dev/shm"
mount -t proc /proc "\$ROOTFS/proc"
mount -t sysfs /sys "\$ROOTFS/sys"
cp /etc/resolv.conf "\$ROOTFS/etc/resolv.conf" || true

chroot "\$ROOTFS" bash /tmp/customize.sh

umount -l "\$ROOTFS/dev/pts" "\$ROOTFS/dev/shm" "\$ROOTFS/dev" "\$ROOTFS/proc" "\$ROOTFS/sys" 2>/dev/null || true

# 4) Build squashfs and ISO
log "Building squashfs..."
mkdir -p "\$WORKDIR/iso-root"
mksquashfs "\$ROOTFS" "\$WORKDIR/iso-root/filesystem.squashfs" -comp zstd -Xcompression-level 19 -noappend

mkdir -p "\$WORKDIR/iso/boot/grub"
KERNEL_SRC="\$(ls -1 "\$ROOTFS"/boot/vmlinuz* "\$ROOTFS"/boot/*vmlinuz* 2>/dev/null | head -n1 || true)"
INITRD_SRC="\$(ls -1 "\$ROOTFS"/boot/initrd* "\$ROOTFS"/boot/initramfs* 2>/dev/null | head -n1 || true)"
if [[ -z "\$KERNEL_SRC" || -z "\$INITRD_SRC" ]]; then
  err "Kernel or initrd was not found in \$ROOTFS/boot"
  err "Cannot build a bootable ISO."
  exit 1
fi
cp -f "\$KERNEL_SRC" "\$WORKDIR/iso/boot/vmlinuz"
cp -f "\$INITRD_SRC" "\$WORKDIR/iso/boot/initrd.img"

cat > "\$WORKDIR/iso/boot/grub/grub.cfg" << 'GRUB'
set default=0
set timeout=5
menuentry "VibeLinux Live" {
  linux /boot/vmlinuz boot=live components username=$USERNAME hostname=$HOSTNAME quiet splash
  initrd /boot/initrd.img
}
GRUB

mkdir -p "\$WORKDIR/iso/live"
cp "\$WORKDIR/iso-root/filesystem.squashfs" "\$WORKDIR/iso/live/filesystem.squashfs"

log "Creating ISO..."
OUT="\$OUTDIR/vibelinux-$DISTRO-\$(date +%Y%m%d).iso"
if command -v grub-mkrescue >/dev/null 2>&1; then
  grub-mkrescue -o "\$OUT" "\$WORKDIR/iso"
elif command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -r -V "VIBELINUX" -o "\$OUT" -J -joliet-long -l -udf "\$WORKDIR/iso"
else
  err "grub-mkrescue or xorriso is required for a bootable hybrid ISO"
  exit 1
fi

log "Done! ISO at: \$OUT"
HEADER

chmod +x "$OUTPUT_FILE"
echo ""
echo "✓ Build script generated: $OUTPUT_FILE"
echo "  Run with: sudo bash $OUTPUT_FILE"
