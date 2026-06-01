#!/usr/bin/env bash
# VibeLinux ISO builder — Full версия (Ubuntu 24.04 LTS)
# Полная сборка: все редакторы, AI-агенты, языки, инструменты
set -euo pipefail

need_root() { if [[ $EUID -ne 0 ]]; then echo "Run as root"; exit 1; fi; }
need_root

WORKDIR="${WORKDIR:-/srv/vibe-iso}"
OUTDIR="${OUTDIR:-$PWD/out}"
USERNAME="vibe"
HOSTNAME="vibelinux"
DISTRO="ubuntu-24.04"
BUILD_TYPE="full"

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
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y --fix-broken \
      debootstrap squashfs-tools xorriso grub-common grub-pc-bin grub-efi-amd64-bin mtools \
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
    debootstrap --arch=amd64 noble "$ROOTFS" http://archive.ubuntu.com/ubuntu/
  else
    debootstrap --arch=amd64 trixie "$ROOTFS" http://deb.debian.org/debian/
  fi

  mount --bind /dev "$ROOTFS/dev"
  mount -t devpts devpts "$ROOTFS/dev/pts"
  mount -t tmpfs tmpfs "$ROOTFS/dev/shm"
  mount -t proc /proc "$ROOTFS/proc"
  mount -t sysfs /sys "$ROOTFS/sys"
  mount --bind /dev/random "$ROOTFS/dev/random"
  mount --bind /dev/urandom "$ROOTFS/dev/urandom"
  cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" || true

  chroot "$ROOTFS" bash -c "sed -i 's/main$/main universe multiverse restricted/' /etc/apt/sources.list || true"
  chroot "$ROOTFS" apt update
  chroot "$ROOTFS" apt install -y --fix-broken linux-image-generic zsh curl wget git sudo locales python3-full python3-pip python3-venv live-boot live-config

  umount -l "$ROOTFS/dev/random" "$ROOTFS/dev/urandom" "$ROOTFS/dev/pts" "$ROOTFS/dev/shm" "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true
}

bootstrap_arch() {
  mkdir -p "$ROOTFS"
  pacstrap -c "$ROOTFS" base linux linux-firmware zsh sudo curl wget git
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
export DEBIAN_FRONTEND=noninteractive
USERNAME="__USER__"
HOSTNAME="__HOST__"

id "$USERNAME" &>/dev/null || useradd -m -s /usr/bin/zsh "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost $HOSTNAME" > /etc/hosts

locale-gen en_US.UTF-8 ru_RU.UTF-8 || true
update-locale LANG=ru_RU.UTF-8 || true

cat > /etc/default/keyboard << KBD
XKBLAYOUT="us,ru"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
KBD

if command -v apt >/dev/null 2>&1; then
  sed -i 's/main$/main universe multiverse restricted/' /etc/apt/sources.list || true
  apt update

  apt install -y \
    pipewire wireplumber pipewire-audio \
    network-manager \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    fonts-firacode fonts-noto-core fonts-noto-color-emoji \
    udev systemd-timesyncd zsh git curl wget unzip jq fzf ripgrep tmux build-essential pkg-config \
    python3-full python3-pip python3-venv \
    docker.io zstd systemd

  systemctl enable NetworkManager || true
  systemctl enable docker || true
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm pipewire wireplumber networkmanager iwd xdg-desktop-portal \
    ttf-fira-code noto-fonts noto-fonts-emoji base-devel git curl wget unzip jq fzf ripgrep tmux python python-pip docker zstd
  systemctl enable NetworkManager
  systemctl enable docker
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install pipewire wireplumber NetworkManager iwd xdg-desktop-portal \
    fira-code-fonts google-noto* git curl wget unzip jq fzf ripgrep tmux python3 python3-pip docker zstd
  systemctl enable NetworkManager
  systemctl enable docker
fi

chsh -s /usr/bin/zsh "$USERNAME" || true
rm -rf /home/$USERNAME/.oh-my-zsh || true
runuser -u "$USERNAME" -- bash -lc 'CI=true curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended || true'
runuser -u "$USERNAME" -- bash -lc 'CI=true curl -fsSL https://starship.rs/install.sh | sh -s -- -y || true'
runuser -u "$USERNAME" -- bash -lc 'mkdir -p ~/.config && echo "eval $(starship init zsh)" >> ~/.zshrc'

# === Языки программирования ===
if [[ "__HAS_NODE__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'CI=true curl -fsSL https://fnm.vercel.app/install | bash'
  runuser -u "$USERNAME" -- bash -lc 'export PATH="$HOME/.local/share/fnm:$PATH"; eval "$(fnm env)"; fnm install --lts; fnm default lts-latest'
fi
if [[ "__HAS_BUN__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'CI=true curl -fsSL https://bun.sh/install | bash'
  echo 'export PATH="$HOME/.bun/bin:$PATH"' >> /home/$USERNAME/.zshrc
fi
if [[ "__HAS_DENO__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'CI=true curl -fsSL https://deno.land/install.sh | sh'
  echo 'export PATH="$HOME/.deno/bin:$PATH"' >> /home/$USERNAME/.zshrc
fi
if [[ "__HAS_PY__" == "1" ]]; then
  echo "Python 3 is already installed from system repositories"
fi
if [[ "__HAS_RUST__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
fi
if [[ "__HAS_GO__" == "1" ]]; then
  curl -fsSL https://go.dev/dl/latest.linux-amd64.tar.gz -o /tmp/go.tgz
  tar -C /usr/local -xzf /tmp/go.tgz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /home/$USERNAME/.zshrc
fi

# === PHP ===
if command -v apt >/dev/null 2>&1; then
  apt install -y php php-cli php-common php-curl php-mbstring php-xml php-zip php-sqlite3 php-mysql php-pgsql php-json php-intl php-bcmath || echo "WARNING: PHP install failed"
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm php || echo "WARNING: PHP install failed"
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install php php-cli php-common php-curl php-mbstring php-xml php-zip php-intl || echo "WARNING: PHP install failed"
fi

# Редактор Zed устанавливается ниже

# Zed — редактор
if [[ "__HAS_ZED__" == "1" ]]; then
  runuser -u "$USERNAME" -- bash -lc 'curl -f https://zed.dev/install.sh 2>/dev/null | sh' || echo "WARNING: Zed install failed"
fi

if [[ "__HAS_HELIX__" == "1" ]]; then
  if command -v cargo >/dev/null 2>&1; then runuser -u "$USERNAME" -- bash -lc 'cargo install --locked helix'; fi
fi

# === Графические приложения ===
if command -v apt >/dev/null 2>&1; then
  apt install -y pinta sqlite3 sqlitebrowser || echo "WARNING: Pinta/SQLite install failed"
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm pinta sqlite3 sqliteman || echo "WARNING: Pinta/SQLite install failed"
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install pinta sqlite sqlitebrowser || echo "WARNING: Pinta/SQLite install failed"
fi

# Bruno — API-клиент (альтернатива Postman)
if command -v apt >/dev/null 2>&1; then
  BRUNO_DEB=$(curl -sL "https://api.github.com/repos/usebruno/bruno/releases/latest" | grep -oP '"browser_download_url": "\K[^"]*amd64\.deb' | head -1)
  if [[ -n "$BRUNO_DEB" ]]; then
    curl -sL "$BRUNO_DEB" -o /tmp/bruno.deb
    apt install -y /tmp/bruno.deb || echo "WARNING: Bruno install failed"
    rm -f /tmp/bruno.deb
  fi
elif command -v pacman >/dev/null 2>&1; then
  # Bruno на Arch устанавливается через AUR (см. customize_airootfs.sh)
  echo "Bruno on Arch: install via yay -S bruno-bin after boot"
fi

# === NVIDIA драйверы ===
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

# Read config
if [ -f "$CONFIG" ]; then
  source <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' "$CONFIG" 2>/dev/null || true)
fi

# Install editors
log "Installing editors..."
if echo "$editors" | grep -q "vscode"; then
  if ! command -v code >/dev/null 2>&1; then
    log "Installing VS Code..."
    rm -f /etc/apt/trusted.gpg.d/microsoft.gpg
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    apt update && apt install -y code
  fi
fi

# Install languages
log "Installing languages..."
if echo "$runtimes" | grep -q "node"; then
  if ! command -v node >/dev/null 2>&1; then
    log "Installing Node.js via fnm..."
CI=true curl -fsSL https://fnm.vercel.app/install | bash
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"
    fnm install --lts
  fi
fi
if echo "$runtimes" | grep -q "bun"; then
  if [ ! -f "$HOME/.bun/bin/bun" ]; then
    log "Installing Bun..."
CI=true curl -fsSL https://bun.sh/install | bash
  fi
fi
if echo "$runtimes" | grep -q "go"; then
  if ! command -v go >/dev/null 2>&1; then
    log "Installing Go..."
    curl -fsSL https://go.dev/dl/latest.linux-amd64.tar.gz -o /tmp/go.tgz
    tar -C /usr/local -xzf /tmp/go.tgz
  fi
fi
if echo "$runtimes" | grep -q "rust"; then
  if ! command -v cargo >/dev/null 2>&1; then
    log "Installing Rust..."
    curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
fi

# Install AI agents
log "Installing AI agents..."
if echo "$agents" | grep -q "aider"; then
  if ! command -v aider >/dev/null 2>&1; then
    log "Installing aider-chat..."
    pip3 install --break-system-packages aider-chat || true
  fi
fi
if [[ "$ollama" == "true" ]]; then
  if ! command -v ollama >/dev/null 2>&1; then
    log "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    systemctl enable ollama --now
  fi
fi

# Install Docker
if echo "$tools" | grep -q "docker"; then
  if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker..."
    if command -v apt >/dev/null 2>&1; then
      apt install -y docker.io
    elif command -v pacman >/dev/null 2>&1; then
      pacman -Sy --noconfirm docker
    elif command -v dnf >/dev/null 2>&1; then
      dnf -y install docker
    fi
    systemctl enable docker --now
  fi
fi

log "Done! Restart to apply changes."
echo ""
echo "╔════════════════════════════════════════╗"
echo "║     Installation complete!             ║"
echo "╚════════════════════════════════════════╝"
WIZ
chmod +x /usr/local/bin/vibe-wizard

# Create systemd service for auto-start wizard
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
sed -i "s/__NVIDIA__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__BUILD_TYPE__/$BUILD_TYPE/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_ZED__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NODE__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_BUN__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_DENO__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_PY__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_RUST__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_GO__/1/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_NEOVIM__/0/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_HELIX__/0/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_AIDER__/0/g" "$ROOTFS/tmp/customize.sh"
sed -i "s/__HAS_OLLAMA__/0/g" "$ROOTFS/tmp/customize.sh"

mkdir -p "$ROOTFS/etc/vibe"
cat > "$ROOTFS/etc/vibe/config.json" << JSON
{
  "distro": "ubuntu-24.04",
  "build_type": "full",
  "editors": ["zed"],
  "agents": [],
  "runtimes": ["python", "node-lts", "rust-stable"],
  "tools": ["git", "gh", "tmux", "fzf", "ripgrep", "jq", "docker", "podman", "pinta", "bruno"],
  "nvidia": false,
  "ollama": false,
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
KERNEL_SRC="$(ls -1 "$ROOTFS"/boot/vmlinuz* "$ROOTFS"/boot/*vmlinuz* 2>/dev/null | head -n1 || true)"
INITRD_SRC="$(ls -1 "$ROOTFS"/boot/initrd* "$ROOTFS"/boot/initramfs* 2>/dev/null | head -n1 || true)"
if [[ -z "$KERNEL_SRC" || -z "$INITRD_SRC" ]]; then
  err "Kernel or initrd was not found in $ROOTFS/boot"
  err "Cannot build a bootable ISO."
  exit 1
fi
cp -f --sparse=never "$KERNEL_SRC" "$WORKDIR/iso/boot/vmlinuz"
cp -f --sparse=never "$INITRD_SRC" "$WORKDIR/iso/boot/initrd.img"

cat > "$WORKDIR/iso/boot/grub/grub.cfg" << 'GRUB'
set default=0
set timeout=5
menuentry "VibeLinux Full Live" {
  linux /boot/vmlinuz boot=live components username=vibe hostname=vibelinux quiet splash
  initrd /boot/initrd.img
}
GRUB

mkdir -p "$WORKDIR/iso/live"
cp "$WORKDIR/iso-root/filesystem.squashfs" "$WORKDIR/iso/live/filesystem.squashfs"

log "Creating ISO..."
OUT="$OUTDIR/vibelinux-full-ubuntu-24.04-$(date +%Y%m%d).iso"
if command -v grub-mkrescue >/dev/null 2>&1; then
  grub-mkrescue -o "$OUT" "$WORKDIR/iso"
elif command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -r -V "VIBELINUX_FULL" -o "$OUT" -J -joliet-long -l -udf "$WORKDIR/iso"
else
  err "grub-mkrescue or xorriso is required for a bootable hybrid ISO"
  exit 1
fi

log "Done! ISO at: $OUT"
