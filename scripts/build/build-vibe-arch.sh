#!/usr/bin/env bash
# VibeLinux ISO builder — Arch Linux (rolling release)
# Полная сборка: все редакторы, AI-агенты, языки, инструменты
set -euo pipefail

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="${WORKDIR:-/srv/vibe-iso}"
OUTDIR="${OUTDIR:-$PWD/out}"
USERNAME="vibe"
HOSTNAME="vibelinux"
DISTRO="arch"

log() { printf "\033[1;34m[vibe]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[err]\033[0m %s\n" "$*" >&2; }

mkdir -p "$WORKDIR" "$OUTDIR"
cd "$WORKDIR"

# 1) Host deps
log "Installing build dependencies..."

if [[ ! -c /dev/null ]]; then
  err "/dev/null is not a character device!"
  err "Fix with: sudo mknod -m 666 /dev/null c 1 3"
  exit 1
fi

case "$DISTRO" in
  ubuntu-24.04|debian-13)
    apt update || { warn "apt update failed, trying to continue..."; }
    DEBIAN_FRONTEND=noninteractive apt install -y --fix-broken \
      debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools \
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
ROOTFS="$WORKDIR/rootfs"

if mountpoint -q "$ROOTFS/sys" 2>/dev/null; then
  umount -l "$ROOTFS/sys" "$ROOTFS/proc" "$ROOTFS/dev" 2>/dev/null || true
fi

if [[ -d "$ROOTFS/usr/bin" ]]; then
  log "Using cached rootfs (skip bootstrap)..."
else
  rm -rf "$ROOTFS"
  mkdir -p "$ROOTFS"
fi

bootstrap_debian() {
  if [[ "$DISTRO" == "ubuntu-24.04" ]]; then
    debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/ || true
  else
    debootstrap --arch=amd64 trixie "$ROOTFS" http://deb.debian.org/debian/ || true
  fi

  mount --bind /dev "$ROOTFS/dev"
  mount -t devpts devpts "$ROOTFS/dev/pts"
  mount -t tmpfs tmpfs "$ROOTFS/dev/shm"
  mount -t proc /proc "$ROOTFS/proc"
  mount -t sysfs /sys "$ROOTFS/sys"
  cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" || true

  chroot "$ROOTFS" apt update
  chroot "$ROOTFS" apt install -y --fix-broken linux-image-generic zsh curl wget git sudo locales python3-full python3-pip python3-venv

  umount -l "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true
}

bootstrap_arch() {
  mkdir -p "$ROOTFS"
  pacstrap -K "$ROOTFS" base linux linux-firmware zsh sudo curl wget git
}

bootstrap_fedora() {
  dnf --releasever=43 --setopt=install_weak_deps=False --installroot="$ROOTFS" -y install @core kernel zsh sudo curl wget git
}

if [[ ! -d "$ROOTFS/usr/bin" ]]; then
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
USERNAME="__USER__"
HOSTNAME="__HOST__"

id "$USERNAME" &>/dev/null || useradd -m -s /usr/bin/zsh "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost $HOSTNAME" > /etc/hosts

locale-gen en_US.UTF-8 ru_RU.UTF-8 || true
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

cat > /etc/vconsole.conf << KBD
KEYMAP=us
FONT=Lat2-Terminus16
KBD

if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm \
    pipewire wireplumber networkmanager iwd \
    flatpak xdg-desktop-portal xdg-desktop-portal-gtk \
    ttf-fira-code noto-fonts noto-fonts-emoji \
    base-devel git curl wget unzip jq fzf ripgrep tmux \
    python python-pip docker zstd

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

# === Языки программирования ===
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
  echo "Python is already installed from system repositories"
fi
if [[ "__HAS_RUST__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
fi
if [[ "__HAS_GO__" == "1" ]]; then
  curl -fsSL https://go.dev/dl/go1.26.0.linux-amd64.tar.gz -o /tmp/go.tgz
  tar -C /usr/local -xzf /tmp/go.tgz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /home/$USERNAME/.zshrc
fi

# === Редакторы ===
if [[ "__HAS_NEOVIM__" == "1" ]]; then
  pacman -Sy --noconfirm neovim
fi
if [[ "__HAS_HELIX__" == "1" ]]; then
  if command -v cargo >/dev/null 2>&1; then runuser -u "$USERNAME" -- bash -lc 'cargo install --locked helix'; fi
fi

# === AI-агенты ===
if [[ "__HAS_AIDER__" == "1" ]]; then
  pip3 install --break-system-packages --ignore-installed aider-chat
fi
if [[ "__HAS_OLLAMA__" == "1" ]]; then
  curl -fsSL https://ollama.com/install.sh | sh
  systemctl enable ollama || true
fi

# === NVIDIA драйверы ===
if [[ "__NVIDIA__" == "1" ]]; then
  pacman -Sy --noconfirm nvidia nvidia-utils
fi

# === Autologin ===
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << CONF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --noclear %I $TERM
CONF

# === Vibe Wizard ===
mkdir -p /usr/local/bin
cat > /usr/local/bin/vibe-wizard << 'WIZ'
#!/usr/bin/env bash
set -e
CONFIG=/etc/vibe/config.json

log() { printf "\e[1;34m[wizard]\e[0m %s\n" "$*"; }

echo "╔════════════════════════════════════════╗"
echo "║   Vibe Linux Post-Install Wizard      ║"
echo "╚════════════════════════════════════════╝"
echo ""

if command -v whiptail >/dev/null 2>&1; then
  SEL=$(whiptail --title "Vibe Wizard" --checklist "Выберите компоненты" 20 78 8 \
    "zed" "Zed editor" OFF \
    "cursor" "Cursor editor" OFF \
    "vscode" "VS Code" OFF \
    "neovim" "Neovim" ON \
    "aider" "Aider agent" OFF \
    "ollama" "Ollama local LLM" OFF \
    "docker" "Docker" OFF \
    "nvidia" "NVIDIA drivers" OFF \
    3>&1 1>&2 2>&3) || true
  echo "Selected: $SEL" > /tmp/vibe-wizard.log
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Готово! Перезагрузите систему      ║"
echo "╚════════════════════════════════════════╝"
WIZ
chmod +x /usr/local/bin/vibe-wizard

mkdir -p /etc/systemd/system
cat > /etc/systemd/system/vibe-wizard.service << SVCEOF
[Unit]
Description=Vibe Post-Install Wizard
After=graphical-session.target
ConditionPathExists=!/home/${USERNAME}/.vibe-wizard-done

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
sed -i "s|__USER__|$USERNAME|g; s|__HOST__|$HOSTNAME|g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__NVIDIA__/0/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__FLATPAKS__/dev.zed.Zed/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NODE__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_BUN__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_DENO__/0/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_PY__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_RUST__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_GO__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NEOVIM__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_HELIX__/0/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_AIDER__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_OLLAMA__/1/g" "$ROOTFS/tmp/customize.sh"

mkdir -p "$ROOTFS/etc/vibe"
cat > "$ROOTFS/etc/vibe/config.json" << JSON
{
  "distro": "arch",
  "build_type": "full",
  "editors": ["zed", "cursor", "vscode", "neovim"],
  "agents": ["continue", "aider", "cline", "opencode"],
  "runtimes": ["node-lts", "python-3.12", "rust-stable", "bun", "go-1.22"],
  "tools": ["git", "gh", "tmux", "fzf", "ripgrep", "jq", "docker"],
  "flatpak": true,
  "nvidia": false,
  "ollama": true,
  "user": "$USERNAME",
  "hostname": "$HOSTNAME"
}
JSON

log "Running chroot customization..."
mount --bind /dev "$ROOTFS/dev"
mount -t devpts devpts "$ROOTFS/dev/pts"
mount -t tmpfs tmpfs "$ROOTFS/dev/shm"
mount -t proc /proc "$ROOTFS/proc"
mount -t sysfs /sys "$ROOTFS/sys"
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
cp -f "$ROOTFS"/boot/vmlinuz* "$WORKDIR/iso/boot/vmlinuz" 2>/dev/null || true
cp -f "$ROOTFS"/boot/initramfs* "$WORKDIR/iso/boot/initrd.img" 2>/dev/null || true

cat > "$WORKDIR/iso/boot/grub/grub.cfg" << 'GRUB'
set default=0
set timeout=5
menuentry "VibeLinux Arch Live" {
  linux /boot/vmlinuz boot=live quiet splash
  initrd /boot/initrd.img
}
GRUB

mkdir -p "$WORKDIR/iso/live"
cp "$WORKDIR/iso-root/filesystem.squashfs" "$WORKDIR/iso/live/filesystem.squashfs"

log "Creating ISO..."
OUT="$OUTDIR/vibelinux-arch-$(date +%Y%m%d).iso"
xorriso -as mkisofs -r -V "VIBELINUX_ARCH" -o "$OUT" -J -joliet-long -l -udf "$WORKDIR/iso" || {
  warn "xorriso failed, check logs"
  exit 1
}

log "Done! ISO at: $OUT"
