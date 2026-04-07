#!/usr/bin/env bash
# Vibe Linux ISO builder
# Distro: Ubuntu 24.04 LTS
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
set -euo pipefail

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="${WORKDIR:-/srv/vibe-iso}"
OUTDIR="${OUTDIR:-$PWD/out}"
USERNAME="dedo"
HOSTNAME="vibecode"
DISTRO="ubuntu-24.04"

log() { printf "\033[1;34m[vibe]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }

mkdir -p "$WORKDIR" "$OUTDIR"
cd "$WORKDIR"

# 1) Host deps
log "Installing build dependencies..."

# Check /dev/null first
if [[ ! -c /dev/null ]]; then
  err "/dev/null is not a character device!"
  err "Fix with: sudo mknod -m 666 /dev/null c 1 3"
  exit 1
fi

case "$DISTRO" in
  ubuntu-24.04|debian-12)
    apt update || {
      warn "apt update failed, trying to continue..."
    }
    DEBIAN_FRONTEND=noninteractive apt install -y --fix-broken \
      debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools \
      dosfstools unzip curl wget git rsync python3 python3-pip
    ;;
  arch)
    pacman -Sy --noconfirm archiso squashfs-tools xorriso grub dosfstools mtools wget curl git rsync python
    ;;
  fedora-41)
    dnf -y install livecd-tools spin-kickstarts squashfs-tools xorriso grub2-efi-x64 grub2-pc dosfstools mtools wget curl git rsync python3
    ;;
  *) err "Unsupported distro"; exit 1;;
esac

# 2) Bootstrap rootfs
log "Preparing base system..."
ROOTFS="$WORKDIR/rootfs"

# Cleanup previous run - unmount first if needed
if mountpoint -q "$ROOTFS/sys" 2>/dev/null; then
  umount -l "$ROOTFS/sys" "$ROOTFS/proc" "$ROOTFS/dev" 2>/dev/null || true
fi

# Skip bootstrap if rootfs already exists (cached)
if [[ -d "$ROOTFS/usr/bin" ]]; then
  log "Using cached rootfs (skip bootstrap)..."
else
  rm -rf "$ROOTFS"
  mkdir -p "$ROOTFS"

bootstrap_debian() {
  if [[ "$DISTRO" == "ubuntu-24.04" ]]; then
    debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/ || true
  else
    debootstrap --arch=amd64 trixie "$ROOTFS" http://deb.debian.org/debian/ || true
  fi
  
  # Mount filesystems for chroot
  mount --bind /dev "$ROOTFS/dev"
  mount -t devpts devpts "$ROOTFS/dev/pts"
  mount -t tmpfs tmpfs "$ROOTFS/dev/shm"
  mount -t proc /proc "$ROOTFS/proc"
  mount -t sysfs /sys "$ROOTFS/sys"
  cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" || true
  
  # Update and install packages using apt
  chroot "$ROOTFS" apt update
  chroot "$ROOTFS" apt install -y --fix-broken linux-image-generic zsh curl wget git sudo locales python3-full python3-pip python3-venv
  
  # Unmount
  umount -l "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true
}
bootstrap_arch() {
  mkdir -p "$ROOTFS"
  pacstrap -c "$ROOTFS" base linux linux-firmware zsh sudo curl wget git
}
bootstrap_fedora() {
  dnf --releasever=43 --setopt=install_weak_deps=False --installroot="$ROOTFS" -y install @core kernel zsh sudo curl wget git
}
case "$DISTRO" in
  ubuntu-24.04|debian-13) bootstrap_debian ;;
  arch) bootstrap_arch ;;
  fedora-43) bootstrap_fedora ;;
esac
fi

# 3) Chroot customization
log "Customizing system in chroot..."
cat > "$ROOTFS/tmp/customize.sh" << 'EOS'
set -e
export DEBIAN_FRONTEND=noninteractive
USERNAME="__USER__"
HOSTNAME="__HOST__"

id "$USERNAME" &>/dev/null || useradd -m -s /usr/bin/zsh "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost $HOSTNAME" > /etc/hosts

locale-gen en_US.UTF-8 ru_RU.UTF-8 || true
update-locale LANG=ru_RU.UTF-8 || true

# Set Russian keyboard layout
cat > /etc/default/keyboard << KBD
XKBLAYOUT="us,ru"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
KBD

if command -v apt >/dev/null 2>&1; then
  # Enable universe/multiverse repositories for Ubuntu
  sed -i 's/main$/main universe multiverse restricted/' /etc/apt/sources.list || true
  apt update
  apt install -y \
    pipewire wireplumber pipewire-audio \
    network-manager \
    flatpak xdg-desktop-portal xdg-desktop-portal-gtk \
    fonts-firacode fonts-noto-core fonts-noto-color-emoji \
    udev systemd-timesyncd zsh git curl wget unzip jq fzf ripgrep tmux build-essential pkg-config \
    python3 python3-venv python3-pip \
    docker.io
  
  # Install VS Code via official Microsoft repository
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
  apt update
  apt install -y code
  
  systemctl enable NetworkManager || true
  systemctl enable docker || true
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm pipewire wireplumber networkmanager iwd flatpak xdg-desktop-portal     ttf-fira-code noto-fonts noto-fonts-emoji base-devel git curl wget unzip jq fzf ripgrep tmux python python-pip docker
  systemctl enable NetworkManager
  systemctl enable docker
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install pipewire wireplumber NetworkManager iwd flatpak xdg-desktop-portal     fira-code-fonts google-noto* git curl wget unzip jq fzf ripgrep tmux python3 python3-pip docker
  systemctl enable NetworkManager
  systemctl enable docker
fi

if command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  FLATPAKS=(__FLATPAKS__)
  if [ ${#FLATPAKS[@]} -gt 0 ]; then
    flatpak install -y flathub "${FLATPAKS[@]}" || true
  fi
fi

chsh -s /usr/bin/zsh "$USERNAME" || true
rm -rf /home/$USERNAME/.oh-my-zsh || true
runuser -u "$USERNAME" -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended || true'
runuser -u "$USERNAME" -- bash -lc 'curl -sS https://starship.rs/install.sh | sh -s -- -y || true'
runuser -u "$USERNAME" -- bash -lc 'mkdir -p ~/.config && echo "eval $(starship init zsh)" >> ~/.zshrc'

if [[ "__HAS_NODE__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'curl -fsSL https://fnm.vercel.app/install | bash'
  runuser -u "$USERNAME" -- bash -lc 'export PATH="$HOME/.local/share/fnm:$PATH"; eval "$(fnm env)"; fnm install --lts; fnm default lts-latest'
fi
if [[ "__HAS_BUN__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -c 'if [ ! -f "$HOME/.bun/bin/bun" ]; then curl -fsSL https://bun.sh/install | bash; fi'
  echo 'export PATH="$HOME/.bun/bin:$PATH"' >> /home/$USERNAME/.zshrc
fi
if [[ "__HAS_DENO__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -c 'if [ ! -d "$HOME/.deno" ]; then curl -fsSL https://deno.land/install.sh | sh; fi'
  echo 'export PATH="$HOME/.deno/bin:$PATH"' >> /home/$USERNAME/.zshrc
fi
if [[ "__HAS_PY__" == "1" ]]; then
  # Python 3 already installed via apt (python3-full)
  echo "Python 3 is already installed from system repositories"
fi
if [[ "__HAS_RUST__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
fi
if [[ "__HAS_GO__" == "1" ]]; then
  curl -fsSL https://go.dev/dl/go1.26.0.linux-amd64.tar.gz -o /tmp/go.tgz
  tar -C /usr/local -xzf /tmp/go.tgz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /home/$USERNAME/.zshrc
fi

if [[ "__HAS_NEOVIM__" == "1" ]]; then
  if command -v apt >/dev/null 2>&1; then apt install -y neovim; fi
  if command -v pacman >/dev/null 2>&1; then pacman -Sy --noconfirm neovim; fi
  if command -v dnf >/dev/null 2>&1; then dnf -y install neovim; fi
fi
if [[ "__HAS_HELIX__" == "1" ]]; then
  if command -v cargo >/dev/null 2>&1; then runuser -u "$USERNAME" -- bash -lc 'cargo install --locked helix'; fi
fi

if [[ "__HAS_AIDER__" == "1" ]]; then
  pip3 install --break-system-packages --ignore-installed aider-chat
fi
if [[ "__HAS_OLLAMA__" == "1" ]]; then
  curl -fsSL https://ollama.com/install.sh | sh
  systemctl enable ollama || true
fi

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

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --noclear %I $TERM
CONF

mkdir -p /usr/local/bin
cat > /usr/local/bin/vibe-wizard << 'WIZ'
#!/usr/bin/env bash
set -e
CONFIG=/etc/vibe/config.json
echo "Vibe post-install wizard"
echo "Config: $CONFIG"
if command -v whiptail >/dev/null 2>&1; then
  SEL=$(whiptail --title "Vibe Wizard" --checklist "Выберите компоненты" 20 78 8     "zed" "Zed editor" ON     "cursor" "Cursor editor" ON     "vscode" "VS Code" ON     "neovim" "Neovim" ON     "continue" "Continue AI" ON     "aider" "Aider agent" ON     "ollama" "Ollama local LLM" ON     "docker" "Docker" ON 3>&1 1>&2 2>&3) || true
  echo "Selected: $SEL" > /tmp/vibe-wizard.log
fi
echo "Готово. При желании установите выбранные компоненты вручную или через скрипт."
WIZ
chmod +x /usr/local/bin/vibe-wizard

echo "Custom chroot done."
EOS

# apply replacements
sed -i "s/__USER__/dedo/g; s/__HOST__/vibecode/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__NVIDIA__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__FLATPAKS__/dev.zed.Zed/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NODE__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_BUN__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_DENO__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_PY__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_RUST__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_GO__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NEOVIM__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_HELIX__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_AIDER__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_GPT_ENG__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_OLLAMA__/1/g" "$ROOTFS/tmp/customize.sh"

mkdir -p "$ROOTFS/etc/vibe"
cat > "$ROOTFS/etc/vibe/config.json" << JSON
{
  "distro": "ubuntu-24.04",
  "editors": ["zed", "cursor", "vscode", "neovim", "helix"],
  "agents": ["continue", "aider", "cline", "opencode", "gpt-engineer"],
  "runtimes": ["node-lts", "python-3.12", "rust-stable", "bun", "go-1.22", "deno"],
  "tools": ["git", "gh", "tmux", "fzf", "ripgrep", "jq", "docker", "podman"],
  "flatpak": true,
  "nvidia": true,
  "ollama": true,
  "user": "dedo",
  "hostname": "vibecode"
}
JSON

log "Running chroot customization..."
# Mount filesystems for chroot
mount --bind /dev "$ROOTFS/dev"
mount -t devpts devpts "$ROOTFS/dev/pts"
mount -t tmpfs tmpfs "$ROOTFS/dev/shm"
mount -t proc /proc "$ROOTFS/proc"
mount -t sysfs /sys "$ROOTFS/sys"
# Mount /dev/random and /dev/urandom for entropy
mount --bind /dev/random "$ROOTFS/dev/random"
mount --bind /dev/urandom "$ROOTFS/dev/urandom"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" || true

chroot "$ROOTFS" bash /tmp/customize.sh

umount -l "$ROOTFS/dev/random" "$ROOTFS/dev/urandom" "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true

# 4) Build squashfs and ISO
log "Building squashfs..."
mkdir -p "$WORKDIR/iso-root"
mksquashfs "$ROOTFS" "$WORKDIR/iso-root/filesystem.squashfs" -comp zstd -Xcompression-level 19 -noappend

mkdir -p "$WORKDIR/iso/boot/grub"
cp -f "$ROOTFS/boot/vmlinuz"* "$WORKDIR/iso/boot/vmlinuz" 2>/dev/null || true
cp -f "$ROOTFS/boot/initrd"* "$WORKDIR/iso/boot/initrd.img" 2>/dev/null || true

cat > "$WORKDIR/iso/boot/grub/grub.cfg" << 'GRUB'
set default=0
set timeout=5
menuentry "Vibe Linux Live" {
  linux /boot/vmlinuz boot=live quiet splash
  initrd /boot/initrd.img
}
GRUB

mkdir -p "$WORKDIR/iso/live"
cp "$WORKDIR/iso-root/filesystem.squashfs" "$WORKDIR/iso/live/filesystem.squashfs"

log "Creating ISO..."
OUT="$OUTDIR/vibe-linux-ubuntu-24.04-$(date +%Y%m%d).iso"
xorriso -as mkisofs   -r -V "VIBE_LINUX"   -o "$OUT"   -J -joliet-long -l   "$WORKDIR/iso" || {
  warn "xorriso failed, check logs"
  exit 1
}

log "Done! ISO at: $OUT"