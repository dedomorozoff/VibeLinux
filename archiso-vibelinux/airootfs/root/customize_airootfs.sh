#!/usr/bin/env bash
set -e

# Minimal /dev — arch-chroot не монтирует devtmpfs
if [[ ! -e /dev/null ]]; then
  mknod /dev/null c 1 3
  mknod /dev/zero c 1 5
  mknod /dev/random c 1 8
  mknod /dev/urandom c 1 9
  chmod 666 /dev/{null,zero,random,urandom}
fi

echo "=== VibeLinux customization ==="

# Hostname
echo "vibelinux" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1 localhost
127.0.1.1 vibelinux
::1       localhost
EOF

# MOTD — из файла брендинга
if [[ -f /root/branding/logos/ascii-logo.txt ]]; then
  cp /root/branding/logos/ascii-logo.txt /etc/motd
else
  cat > /etc/motd << 'EOF'

█   █ ███ ████  █████ █     ███ █   █ █   █ █   █
█   █  █  █   █ █     █      █  ██  █ █   █  █ █
█   █  █  ████  ████  █      █  █ █ █ █   █   █
 █ █   █  █   █ █     █      █  █  ██ █   █  █ █
  █   ███ ████  █████ █████ ███ █   █  ███  █   █

 VibeLinux — Linux для вайбкодинга и AI
EOF
fi

# OS Release (for fastfetch / lsb_release)
cat > /etc/os-release << 'EOF'
NAME="VibeLinux"
PRETTY_NAME="VibeLinux"
ID=vibelinux
ID_LIKE=arch
VERSION=2026.08
VERSION_CODENAME=genesis
HOME_URL="https://dmintegroff.ru"
DOCUMENTATION_URL="https://github.com/vibelinux/docs"
SUPPORT_URL="https://github.com/vibelinux"
BUG_REPORT_URL="https://github.com/vibelinux/issues"
LOGO=/usr/share/pixmaps/vibelinux.svg
EOF

# PackageKit: принудительно используем alpm бэкенд (обходит проверку ID=vibelinux)
mkdir -p /etc/PackageKit
cat > /etc/PackageKit/PackageKit.conf << 'PKCONF'
[Daemon]
DefaultBackend=alpm
PKCONF

# Fastfetch config
mkdir -p /home/vibe/.config/fastfetch
cat > /home/vibe/.config/fastfetch/config.jsonc << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/config.schema.jsonc",
  "logo": {
    "source": "/usr/share/vibelinux/ascii-logo.txt",
    "padding": {
      "top": 0,
      "bottom": 0,
      "left": 2,
      "right": 2
    },
    "color": {
      "1": "cyan"
    }
  },
  "modules": [
    { "type": "title" },
    { "type": "separator" },
    {
      "type": "os",
      "key": "OS"
    },
    { "type": "host" },
    { "type": "kernel" },
    { "type": "uptime" },
    {
      "type": "packages",
      "display": {
        "mode": "custom",
        "custom": "packages: pacman-p, npm, pip, cargo"
      }
    },
    { "type": "shell" },
    { "type": "de" },
    { "type": "wm" },
    { "type": "wmtheme" },
    { "type": "theme" },
    { "type": "icons" },
    { "type": "font" },
    {
      "type": "terminal",
      "key": "Terminal"
    },
    { "type": "terminalfont" },
    { "type": "cpu" },
    { "type": "gpu" },
    { "type": "memory" },
    { "type": "disk" },
    { "type": "localip" },
    {
      "type": "colors",
      "key": "Colors",
      "symbol": "circle"
    }
  ],
  "colors": {
    "initials": [
      "4cc9f0", "7209b7", "2ec4b6", "ffe066"
    ]
  }
}
EOF

# Timezone (по умолчанию UTC — systemd не будет запрашивать при загрузке)
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Keyboard layout
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,ru"
    Option "XkbModel" "pc105"
    Option "XkbOptions" "grp:caps_toggle"
EndSection
EOF

# Default shell
chsh -s /usr/bin/zsh root 2>/dev/null || true

# User
if ! id vibe &>/dev/null; then
  useradd -m -G wheel,vboxsf -s /usr/bin/zsh vibe
  echo "vibe:vibe" | chpasswd
fi
echo "vibe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe
chmod 440 /etc/sudoers.d/90_vibe

# Enable wheel group sudo (пользователь Calamares добавляется в wheel)
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Services
systemctl enable NetworkManager || true
systemctl enable systemd-timesyncd || true
systemctl enable docker || true
systemctl enable sddm || true
systemctl enable vboxservice || true
systemctl enable nvidia-persistenced || true
# Ollama НЕ в образе: ставится post-install (ai-install → Ollama),
# там же включается её systemd-сервис (см. /usr/local/bin/install-ollama).

# NVIDIA: modprobe config for DRM modeset (fallback if kernel cmdline missing)
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia_drm modeset=1
options nvidia NVreg_EnableBacklightHandler=1
EOF

# Ensure /boot/vmlinuz-linux exists and is non-empty before mkinitcpio runs.
# The linux package installs the kernel only at /usr/lib/modules/<ver>/vmlinuz;
# /boot/vmlinuz-linux is created by the 90-mkinitcpio-install.hook, which may
# fail or create a 0-byte file depending on trigger order (relative path issue).
# We copy (not symlink) because GRUB on Btrfs cannot read symlinks — it reads
# the symlink file itself (0 bytes) and fails with "преждевременный конец файла".
# The Calamares copy-kernel.sh will also re-copy on the installed system.
if [[ ! -s /boot/vmlinuz-linux ]]; then
  KVER=$(ls /usr/lib/modules/ 2>/dev/null | grep -v 'extramodules' | sort -V | tail -1)
  if [[ -n "$KVER" && -f "/usr/lib/modules/$KVER/vmlinuz" ]]; then
    cp --sparse=never -f "/usr/lib/modules/$KVER/vmlinuz" /boot/vmlinuz-linux
    chmod 644 /boot/vmlinuz-linux
    echo "OK: copied kernel to /boot/vmlinuz-linux ($(stat -c%s /boot/vmlinuz-linux) bytes)"
  fi
fi

# NVIDIA: rebuild initramfs with nvidia modules
# Force-write mkinitcpio.conf (pacman may overwrite it during install)
# NOTE: no `autodetect` — it prunes modules to the build host's hardware
# (e.g. sr_mod for CD-ROM drops out on hosts without an optical drive),
# which breaks booting the ISO as an optical disc in VMs (VirtualBox).
# Keep this heredoc in sync with airootfs/etc/mkinitcpio.conf.
cat > /etc/mkinitcpio.conf << 'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm vboxguest vboxsf vboxvideo)
BINARIES=()
FILES=()
HOOKS=(base udev modconf kms block filesystems keyboard fsck archiso)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-15)
EOF

if command -v mkinitcpio &>/dev/null; then
  # nvidia-open бывает собран под предыдущую версию ядра (репозитории
  # рассинхронизированы) — тогда «module not found: 'nvidia'» и падение.
  # Не роняем сборку: пересобираем initramfs без nvidia-модулей, они
  # подхватятся udev уже из rootfs после загрузки.
  if ! mkinitcpio -P; then
    echo "WARNING: mkinitcpio failed (nvidia/kernel version mismatch?)"
    echo "Retrying without nvidia modules in initramfs..."
    sed -i 's/^MODULES=.*/MODULES=(vboxguest vboxsf vboxvideo)/' /etc/mkinitcpio.conf
    mkinitcpio -P || echo "WARNING: mkinitcpio failed again — initramfs may be incomplete"
  fi
fi

# Pacman hook: finalize boot files (copy kernel as regular file, fix symlinks)
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/90-vmlinuz-copy.hook << 'HOOK'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-lts
Target = linux-zen
Target = linux-hardened
Target = linux-cachyos
Target = linux-cachyos-lts
Target = linux-rt
Target = linux-rt-lts

[Action]
Description = Finalizing VibeLinux boot files (copying kernels, fixing symlinks)...
When = PostTransaction
Exec = /usr/local/bin/vibe-finalize-boot
HOOK

# SDDM autologin (Wayland — KDE 6 дефолт)
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=vibe
Session=plasma.desktop
EOF

# Getty autologin на tty1 для vibe (на случай если SDDM не стартует в live-сессии)
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin vibe --noclear %I \$TERM
EOF

# Oh My Zsh (install via script)
if [[ ! -d /home/vibe/.oh-my-zsh ]]; then
  runuser -u vibe -- bash -c 'CI=true sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' 2>/dev/null || true
fi

# Starship prompt with VibeLinux config
cat > /home/vibe/.config/starship.toml << 'EOF'
format = """
$custom$directory$git_branch$git_status$character
"""

[character]
success_symbol = "[❯](bold #4CC9F0)"
error_symbol = "[❯](bold #f7768e)"

[directory]
style = "bold #7209B7"
read_only = " 󰌾"

[git_branch]
format = "[$symbol$branch]($style) "
style = "bold #FFE066"
symbol = ""

[git_status]
format = '([\[$all_status$ahead_behind\]]($style) )'
style = "bold #f7768e"

[custom.distro]
command = "echo VibeLinux"
format = "[$output]($style) "
style = "bold #4CC9F0"
when = "true"
shell = ["bash", "--norc"]
EOF

if command -v starship >/dev/null 2>&1; then
  echo 'eval "$(starship init zsh)"' >> /home/vibe/.zshrc
fi

# === DEV STACK SETUP ===

# Kitty terminal config
mkdir -p /home/vibe/.config/kitty
cat > /home/vibe/.config/kitty/kitty.conf << 'EOF'
font_family      JetBrainsMono Nerd Font
font_size        13.0
background       #0B1020
foreground       #FFFFFF
cursor           #4CC9F0
selection_foreground #FFFFFF
selection_background #7209B7
color0  #0B1020
color1  #F7768E
color2  #2EC4B6
color3  #FFE066
color4  #4CC9F0
color5  #7209B7
color6  #2EC4B6
color7  #FFFFFF
color8  #646464
color9  #FF9696
color10 #64FFC8
color11 #FFF096
color12 #78DCFF
color13 #A03CDC
color14 #64FFC8
color15 #FFFFFF
enable_audio_bell no
confirm_os_window_close 0
window_padding_width 10
EOF

# nvm setup
export NVM_DIR="/home/vibe/.nvm"
mkdir -p "$NVM_DIR"
cat >> /home/vibe/.zshrc << 'EOF'

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/usr/share/nvm/init-nvm.sh" ] && . "/usr/share/nvm/init-nvm.sh"
EOF

# pyenv setup
cat >> /home/vibe/.zshrc << 'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)" 2>/dev/null || true
EOF

# SDKMAN setup
mkdir -p /home/vibe/.sdkman
cat >> /home/vibe/.zshrc << 'EOF'

# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
EOF

# Git config
cat > /home/vibe/.gitconfig << 'EOF'
[user]
    name = VibeLinux User
    email = user@vibelinux.local
[core]
    editor = zed
[init]
    defaultBranch = main
[push]
    autoSetupRemote = true
[alias]
    st = status
    co = checkout
    br = branch
    lg = log --oneline --graph --decorate
EOF

# Lazygit config
mkdir -p /home/vibe/.config/lazygit
cat > /home/vibe/.config/lazygit/config.yml << 'EOF'
gui:
  theme:
    activeBorderColor:
      - '#4CC9F0'
      - 'bold'
    inactiveBorderColor:
      - '#7209B7'
    selectedLineBgColor:
      - '#1A2540'
EOF

# Set default terminal to Kitty
if command -v kitty >/dev/null; then
  mkdir -p /home/vibe/.config
  cat > /home/vibe/.config/mimeapps.list << EOF
[Default Applications]
x-scheme-handler/terminal=kitty.desktop
EOF
fi

# === AI AGENTS: ПРЕДУСТАНОВКА В ОБРАЗ ===
# Ключевая идея: все CLI-агенты запекаются в squashfs на этапе сборки.
# В live-сессии не нужно ничего доустанавливать (нет root-запроса и нет
# проблемы с местом — оверлей в RAM). Установленные агенты доступны и
# в live-сессии, и на установленной системе.
mkdir -p /home/vibe/.npm
chown -R vibe:vibe /home/vibe/.npm

NPM_AGENTS=(
  "@qwen-code/qwen-code:qwen"
  "@anthropic-ai/claude-code:claude"
  "@openai/codex:codex"
  "@kilocode/cli:kilo"
  "@mimo-ai/cli:mimo"
  "@continuedev/cli:cn"
  "@moonshot-ai/kimi-code:kimi"
)
for entry in "${NPM_AGENTS[@]}"; do
  pkg="${entry%%:*}"; bin="${entry##*:}"
  if command -v "$bin" >/dev/null 2>&1; then
    echo "OK: $bin уже установлен"
  else
    echo "Installing $pkg (→ $bin)..."
    npm install -g "$pkg" 2>&1 | tail -3 || echo "WARNING: $pkg install failed"
  fi
done

# Claude Code: запускаем postinstall вручную (нативный бинарник)
CLAUDE_GLOBAL="$(npm root -g)/@anthropic-ai/claude-code"
if [[ -f "$CLAUDE_GLOBAL/install.cjs" ]]; then
  echo "Running claude-code postinstall..."
  node "$CLAUDE_GLOBAL/install.cjs" || echo "WARNING: claude-code postinstall failed"
fi
chown -R vibe:vibe /home/vibe/.npm

# Crush — нативный бинарник из GitHub-релизов. npm-пакет @charmland/crush
# при первом запуске качает бинарник в /usr/lib/node_modules и у обычного
# пользователя падает с EACCES, поэтому ставим напрямую и сносим npm-версию
# (в переиспользуемом work-каталоге мог остаться старый враппер).
CRUSH_AA=""
case "$(uname -m)" in
  x86_64) CRUSH_AA="x86_64" ;;
  aarch64|arm64) CRUSH_AA="arm64" ;;
esac
if [[ -n "$CRUSH_AA" ]]; then
  CRUSH_VER="$(curl -fsSL --retry 3 https://api.github.com/repos/charmbracelet/crush/releases/latest 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)"
  if [[ -n "$CRUSH_VER" ]]; then
    CRUSH_TMP="$(mktemp -d)"
    if curl -fsSL --retry 3 "https://github.com/charmbracelet/crush/releases/download/${CRUSH_VER}/crush_${CRUSH_VER#v}_Linux_${CRUSH_AA}.tar.gz" -o "$CRUSH_TMP/crush.tar.gz"; then
      tar -xzf "$CRUSH_TMP/crush.tar.gz" -C "$CRUSH_TMP"
      install -Dm 755 "$CRUSH_TMP/crush_${CRUSH_VER#v}_Linux_${CRUSH_AA}/crush" /usr/local/bin/crush \
        && echo "OK: crush ${CRUSH_VER} установлен из GitHub-релиза"
    else
      echo "WARNING: crush download failed"
    fi
    rm -rf "$CRUSH_TMP"
  else
    echo "WARNING: не удалось получить версию crush"
  fi
fi
npm uninstall -g "@charmland/crush" >/dev/null 2>&1 || true

# Обёртки для агентов: кэш и tmp в /tmp (tmpfs), чтобы не забивать overlay
for agent_bin in claude kilo mimo qwen codex opencode dmsh crush kimi; do
  REAL_BIN="$(type -p "$agent_bin" 2>/dev/null || true)"
  if [[ -z "$REAL_BIN" || -f "${REAL_BIN}.real" ]]; then
    continue
  fi
  mv "$REAL_BIN" "${REAL_BIN}.real"
  cat > "$REAL_BIN" << WRAPPEREOF
#!/usr/bin/env bash
export TMPDIR=/tmp
export XDG_CACHE_HOME=/tmp/\${USER:-root}/.cache
export XDG_CONFIG_HOME=/tmp/\${USER:-root}/.config
mkdir -p "\$XDG_CACHE_HOME" "\$XDG_CONFIG_HOME"
exec "${REAL_BIN}.real" "\$@"
WRAPPEREOF
  chmod +x "$REAL_BIN"
done

# Скрипты пост-установочного AI-стека (скопированы в /opt/vibecode на этапе сборки)
if [[ -d /opt/vibecode/scripts/ai ]]; then
  chmod -R +x /opt/vibecode/scripts/ai 2>/dev/null || true
  echo "OK: /opt/vibecode/scripts/ai готов (setup-ai-stack.sh для post-install)"
fi

# Тяжёлый AI-стек (Python venv / WebUI / ComfyUI) устанавливается ПОСЛЕ установки на диск:
#   sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh

cat > /usr/local/bin/ai-setup << 'AISETUPEOF'
#!/usr/bin/env bash
set -euo pipefail

# Проверка live-сессии: archiso держит корень в RAM (overlay), модели туда не влезут.
if [[ -d /run/archiso/bootmnt ]]; then
  echo "Live-сессия: корень — overlay в RAM, ollama и модели сюда не помещаются."
  echo "Установите VibeLinux на диск (Install VibeLinux), затем:"
  echo "  sudo install-ollama   # рантайм локальных LLM"
  echo "  ai-setup              # базовые модели"
  exit 0
fi

echo "Downloading base Ollama models..."
echo
for model in qwen2.5-coder:7b llama3.2:3b codellama:7b; do
  echo "-> $model"
  ollama pull "$model" 2>&1 | tail -1 || true
  echo
done
echo "Done! Модели лежат в /var/lib/ollama/models"
AISETUPEOF
chmod +x /usr/local/bin/ai-setup



# Proprietary AI tool installers

# Cursor Agent CLI installer (official)
cat > /usr/local/bin/install-cursor << 'CURSOREOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -d /run/archiso/bootmnt ]]; then
  echo "Live-сессия: корень — RAM-оверлей, установка в /usr невозможна."
  echo "Установите VibeLinux на диск и запустите install-cursor там."
  exit 1
fi

echo "Installing Cursor Agent CLI..."
if curl -fsSL https://cursor.com/install | bash; then
  echo "Cursor Agent installed! Run: agent"
else
  echo "Failed to install Cursor Agent."
  echo "Manual install: https://cursor.com/docs/cli/overview"
  exit 1
fi
CURSOREOF
chmod +x /usr/local/bin/install-cursor

# Amazon Kiro installer (official CLI)
cat > /usr/local/bin/install-kiro << 'KIROEOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -d /run/archiso/bootmnt ]]; then
  echo "Live-сессия: корень — RAM-оверлей, установка в /usr невозможна."
  echo "Установите VibeLinux на диск и запустите install-kiro там."
  exit 1
fi

echo "Installing Amazon Kiro CLI..."
if curl -fsSL https://cli.kiro.dev/install | bash; then
  echo "Kiro installed! Run: kiro"
else
  echo "Failed to install Kiro. See: https://kiro.dev/downloads"
  exit 1
fi
KIROEOF
chmod +x /usr/local/bin/install-kiro

# Kilo Code CLI installer
cat > /usr/local/bin/install-kilo << 'KILOEOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing Kilo Code CLI..."
if command -v npm >/dev/null 2>&1; then
  npm install -g @kilocode/cli
  echo "Kilo Code installed! Run: kilo"
else
  echo "npm not found. Install Node.js first."
  exit 1
fi
KILOEOF
chmod +x /usr/local/bin/install-kilo

# MiMo Code CLI installer
cat > /usr/local/bin/install-mimo << 'MIMOEOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing MiMo Code CLI..."
if command -v npm >/dev/null 2>&1; then
  npm install -g @mimo-ai/cli
  echo "MiMo Code installed! Run: mimo"
else
  echo "npm not found. Install Node.js first."
  exit 1
fi
MIMOEOF
chmod +x /usr/local/bin/install-mimo

# Crush CLI installer — нативный бинарник из GitHub-релизов
cat > /usr/local/bin/install-crush << 'CRUSHEOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing Crush..."
CRUSH_AA=""
case "$(uname -m)" in
  x86_64) CRUSH_AA="x86_64" ;;
  aarch64|arm64) CRUSH_AA="arm64" ;;
  *) echo "Unsupported arch: $(uname -m)"; exit 1 ;;
esac
CRUSH_VER="$(curl -fsSL --retry 3 https://api.github.com/repos/charmbracelet/crush/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
[[ -n "$CRUSH_VER" ]] || { echo "Failed to resolve latest release"; exit 1; }
CRUSH_TMP="$(mktemp -d)"
trap 'rm -rf "$CRUSH_TMP"' EXIT
curl -fsSL --retry 3 "https://github.com/charmbracelet/crush/releases/download/${CRUSH_VER}/crush_${CRUSH_VER#v}_Linux_${CRUSH_AA}.tar.gz" -o "$CRUSH_TMP/crush.tar.gz"
tar -xzf "$CRUSH_TMP/crush.tar.gz" -C "$CRUSH_TMP"
install -Dm 755 "$CRUSH_TMP/crush_${CRUSH_VER#v}_Linux_${CRUSH_AA}/crush" /usr/local/bin/crush
echo "Crush ${CRUSH_VER} installed! Run: crush"
CRUSHEOF
chmod +x /usr/local/bin/install-crush

# Kimi Code CLI installer
cat > /usr/local/bin/install-kimi << 'KIMIEOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing Kimi Code CLI..."
if command -v npm >/dev/null 2>&1; then
  npm install -g @moonshot-ai/kimi-code
  echo "Kimi Code installed! Run: kimi"
else
  echo "npm not found. Install Node.js first."
  exit 1
fi
KIMIEOF
chmod +x /usr/local/bin/install-kimi

# Ollama installer (post-install, Arch)
cat > /usr/local/bin/install-ollama << 'OLLAMAEOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -d /run/archiso/bootmnt ]]; then
  echo "Live-сессия: корень — RAM-оверлей, ollama (~500 МБ) сюда не поместится."
  echo "Установите VibeLinux на диск и запустите install-ollama там."
  exit 1
fi

echo "Installing Ollama..."
if command -v ollama >/dev/null 2>&1; then
  echo "Ollama is already installed: $(ollama --version 2>/dev/null || echo unknown version)"
  exit 0
fi
if command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --noconfirm ollama
  sudo systemctl enable --now ollama
elif command -v apt-get >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
  sudo systemctl enable --now ollama 2>/dev/null || true
else
  echo "Unsupported package manager. Install Ollama manually: https://ollama.com/download"
  exit 1
fi
echo "Ollama installed and running!"
echo "Download models: ollama pull qwen2.5-coder:7b  (or run: ai-setup)"
OLLAMAEOF
chmod +x /usr/local/bin/install-ollama

# Claude Code installer
cat > /usr/local/bin/install-claude-code << 'CLAUDEEOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing Claude Code..."
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Install Node.js first."
  exit 1
fi
if npm install -g @anthropic-ai/claude-code; then
  # Run postinstall for native binary
  CLAUDE_GLOBAL="$(npm root -g)/@anthropic-ai/claude-code"
  if [[ -f "$CLAUDE_GLOBAL/install.cjs" ]]; then
    echo "Running postinstall..."
    node "$CLAUDE_GLOBAL/install.cjs" || echo "WARNING: postinstall failed"
  fi
  echo "Claude Code installed! Run: claude"
else
  echo "Failed to install Claude Code. Check: https://claude.ai/code"
  exit 1
fi
CLAUDEEOF
chmod +x /usr/local/bin/install-claude-code

# OpenAI Codex CLI installer
cat > /usr/local/bin/install-codex << 'CODEXEOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Installing OpenAI Codex CLI..."
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Install Node.js first."
  exit 1
fi
if npm install -g @openai/codex; then
  echo "Codex installed! Run: codex"
else
  echo "Failed to install Codex. Check: https://developers.openai.com/codex/cli"
  exit 1
fi
CODEXEOF
chmod +x /usr/local/bin/install-codex

# Continue.dev CLI installer
cat > /usr/local/bin/install-continue << 'CONTINUEEOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Installing Continue.dev CLI..."
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Install Node.js first."
  exit 1
fi
if npm install -g @continuedev/cli; then
  echo "Continue CLI installed! Run: cn"
else
  echo "Failed to install Continue CLI. Check: https://docs.continue.dev/cli"
  exit 1
fi

CONFIG_DIR="$HOME/.continue"
if [[ ! -d "$CONFIG_DIR" ]]; then
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/config.json" << 'CFGEOF'
{
  "models": [
    { "title": "Qwen 2.5 Coder", "provider": "ollama", "model": "qwen2.5-coder:7b" },
    { "title": "Llama 3.2", "provider": "ollama", "model": "llama3.2:3b" }
  ],
  "tabAutocompleteModel": { "title": "Qwen 2.5 Coder", "provider": "ollama", "model": "qwen2.5-coder:7b" }
}
CFGEOF
  echo "Created $CONFIG_DIR/config.json (Ollama models)"
fi
echo "Continue.dev installed! Config: $CONFIG_DIR/config.json"
CONTINUEEOF
chmod +x /usr/local/bin/install-continue

# MCP servers installer
cat > /usr/local/bin/install-mcp-servers << 'MCPEOF'
#!/usr/bin/env bash
echo "Installing MCP servers..."
if ! command -v npx &>/dev/null; then
  echo "npx not found — install Node.js first"
  exit 1
fi
for pkg in filesystem github brave-search; do
  echo "  @modelcontextprotocol/server-$pkg"
  npx -y "@modelcontextprotocol/server-$pkg" --help &>/dev/null || true
done
echo ""
echo "MCP servers available via npx!"
echo 'Add to opencode config: "mcpServers": { "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path"] } }'
MCPEOF
chmod +x /usr/local/bin/install-mcp-servers

# Unified AI installer — live-сессия осведомлён о месте (overlay в RAM).
# CLI-агенты предустановлены в образ, поэтому менеджер в основном
# показывает статус и направляет к post-install установкам на диск.
cat > /usr/local/bin/ai-install << 'INSTALLEOF'
#!/usr/bin/env bash
set -euo pipefail

is_live() {
  [[ -d /run/archiso/bootmnt ]]
}

is_installed() {
  command -v "$1" >/dev/null 2>&1
}

status() {
  if is_installed "$1"; then
    printf "установлен"
  else
    printf "не установлен"
  fi
}

live_blocked() {
  if is_live; then
    echo "В live-сессии корень — overlay в RAM, ставить в /usr некуда."
    echo "Установите VibeLinux на диск и запустите эту команду там."
    return 0
  fi
  return 1
}

echo "VibeLinux — AI Tool Installer"
echo "=============================="
echo ""
if is_live; then
  FREE=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
  echo "Live-сессия: / — RAM-оверлей, свободно: ${FREE:-?}. Доустановка тяжёлых компонентов невозможна."
  echo "Все CLI-агенты уже предустановлены и работают."
  echo ""
fi

echo "── Предустановленные AI-агенты (работают сразу) ──"
echo "  opencode      — Open source AI coding agent ($(status opencode))"
echo "  qwen-code     — Qwen AI coding agent ($(status qwen))"
echo "  Claude Code   — Anthropic terminal AI ($(status claude))"
echo "  Codex         — OpenAI terminal AI ($(status codex))"
echo "  Kilo Code     — Open source AI coding agent ($(status kilo))"
echo "  MiMo Code     — Xiaomi terminal AI ($(status mimo))"
echo "  Continue.dev  — AI coding CLI ($(status cn))"
echo ""
echo "── Дополнительные действия ──"
echo "  [1] Cursor Agent — Cursor terminal agent ($(status agent))"
echo "  [2] Kiro          — Amazon's AI coding assistant ($(status kiro))"
echo "  [3] MCP servers   — Model Context Protocol (filesystem, github)"
echo "  [4] Ollama        — Local LLM runtime ($(status ollama))"
echo "  [5] AI модели     — базовые Ollama-модели (ai-setup)"
echo "  [6] AI stack      — WebUI + Python-стек + ComfyUI (setup-ai-stack)"
echo ""
if is_live; then
  echo "Дальше: установите VibeLinux на диск (Install VibeLinux), затем:"
else
  echo "Post-install:"
fi
echo "  sudo install-ollama                                 # рантайм локальных LLM"
echo "  sudo ai-setup                                       # базовые Ollama-модели"
echo "  sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh     # WebUI + Python-стек + ComfyUI"
echo ""
read -rp "Выберите [1-6] или Enter для выхода: " choice
case "$choice" in
  1) live_blocked || install-cursor ;;
  2) live_blocked || install-kiro ;;
  3) install-mcp-servers ;;
  4) live_blocked || install-ollama ;;
  5) ai-setup ;;
  6)
    if is_live; then
      echo "setup-ai-stack ставит тяжёлые компоненты (WebUI/ComfyUI/Python-стек)."
      echo "В live-сессии нет места — запустите после установки на диск."
    elif [[ -x /opt/vibecode/scripts/ai/setup-ai-stack.sh ]]; then
      sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh
    else
      echo "setup-ai-stack.sh не найден в образе."
    fi
    ;;
  *) echo "Happy coding!" ;;
esac
INSTALLEOF
chmod +x /usr/local/bin/ai-install

# === BRANDING ===

# === BRANDING: Check files exist ===
echo "=== Checking branding files ==="
ls -la /root/branding/ 2>/dev/null || echo "WARNING: /root/branding/ not found!"

# ASCII logo для fastfetch / MOTD
if [[ -f /root/branding/logos/ascii-logo.txt ]]; then
  mkdir -p /usr/share/vibelinux
  cp /root/branding/logos/ascii-logo.txt /usr/share/vibelinux/ascii-logo.txt
  cp /root/branding/logos/ascii-logo.txt /etc/motd
  echo "OK: ascii-logo.txt copied to /etc/motd"
else
  echo "WARNING: ascii-logo.txt not found!"
fi

# Wallpapers — copy to system location (Plasma 6: PNG preferred over SVG)
mkdir -p /usr/share/wallpapers/VibeLinux/contents/images

# Конвертируем SVG→PNG (Plasma 6 лучше работает с PNG)
if [[ -f /root/branding/wallpapers/vibecode-dark.svg ]]; then
  cp /root/branding/wallpapers/vibecode-dark.svg /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
  echo "OK: wallpaper SVG copied"
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 1920 -h 1080 /root/branding/wallpapers/vibecode-dark.svg \
      -o /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png 2>/dev/null || true
    echo "OK: wallpaper PNG converted from SVG"
  elif command -v convert &>/dev/null; then
    convert -background none /root/branding/wallpapers/vibecode-dark.svg \
      /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png 2>/dev/null || true
    echo "OK: wallpaper PNG converted from SVG (ImageMagick)"
  fi
fi
if [[ ! -f /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png ]]; then
  if [[ -f /root/branding/wallpapers/vibecode-dark.png ]]; then
    cp /root/branding/wallpapers/vibecode-dark.png /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png
    echo "OK: wallpaper PNG copied (from build artifact)"
  fi
fi

# Wallpaper metadata — чтобы KDE 6 видел VibeLinux как тему обоев
cat > /usr/share/wallpapers/VibeLinux/metadata.json << 'WPMETA'
{
    "KPlugin": {
        "Authors": [
            {
                "Email": "admin@vibecodeos",
                "Name": "VibeCode OS"
            }
        ],
        "Id": "VibeLinux",
        "License": "GPLv3",
        "Name": "VibeLinux",
        "Description": "VibeCode OS branding wallpaper"
    }
}
WPMETA
echo "OK: wallpaper metadata.json created"

# System logo — SVG в hicolor icons
if [[ -f /root/branding/logos/vibecodeos-logo.svg ]]; then
  mkdir -p /usr/share/icons/hicolor/scalable/apps
  cp /root/branding/logos/vibecodeos-logo.svg /usr/share/icons/hicolor/scalable/apps/vibelinux.svg
  cp /root/branding/logos/vibecodeos-logo.svg /usr/share/pixmaps/vibelinux.svg
  echo "OK: logo SVG copied"
fi

# Convert logo to PNG for Calamares
if [[ -f /root/branding/logos/vibecodeos-logo.svg ]]; then
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 256 -h 256 /root/branding/logos/vibecodeos-logo.svg -o /usr/share/pixmaps/vibelinux.png 2>/dev/null || true
  elif command -v convert &>/dev/null; then
    convert -background none -size 256x256 /root/branding/logos/vibecodeos-logo.svg /usr/share/pixmaps/vibelinux.png 2>/dev/null || true
  fi
fi

# === KDE Plasma 6 Configuration ===
mkdir -p /home/vibe/.config
WALL="/usr/share/wallpapers/VibeLinux/contents/images/2560x1440"

# Wallpaper: PNG приоритет (Plasma 6 лучше работает с PNG, чем с SVG)
WALLPAPER_PATH=""
for ext in png jpg svg; do
  fp="${WALL}.${ext}"
  [[ -f "$fp" ]] && { WALLPAPER_PATH="$fp"; break; }
done
WALL_URI="file://${WALLPAPER_PATH}"

# 1. Desktop Layout — базовый конфиг с обоями
cat > /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc << PLASMACONF
[Containments][1]
ItemGeometries-1920x1080=
wallpaperplugin=org.kde.image
wallpaperpluginmode=SingleImage
[Containments][1][Wallpaper][org.kde.image][General]
FillMode=2
Image=${WALLPAPER_PATH}
PLASMACONF
chown vibe:vibe /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc

# 2. Автозапуск: применяем обои при первом входе (plasma-apply-wallpaperimage не работает в chroot)
mkdir -p /home/vibe/.config/autostart
cat > /home/vibe/.config/autostart/set-wallpaper.desktop << AUTOSTART
[Desktop Entry]
Type=Application
Name=Set VibeLinux Wallpaper
Exec=plasma-apply-wallpaperimage ${WALLPAPER_PATH}
OnlyShowIn=KDE
X-KDE-autostart-phase=2
X-KDE-autostart-after=plasma-desktop
AUTOSTART

# 2b. Автозапуск: закрепляем Konsole в панели (Plasma 6)
cat > /home/vibe/.config/autostart/pin-konsole.desktop << AUTOSTART2
[Desktop Entry]
Type=Application
Name=Pin Konsole to Panel
Exec=bash -c 'sleep 10 && kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group 3 --group Applets --group 6 --group Configuration --group General --key launchers "file:///usr/share/applications/org.kde.konsole.desktop,preferred://browser,file:///usr/share/applications/org.kde.dolphin.desktop" && systemctl --user restart plasma-plasmashell.service'
OnlyShowIn=KDE
X-KDE-autostart-phase=2
X-KDE-autostart-after=plasma-desktop
AUTOSTART2
chown -R vibe:vibe /home/vibe/.config/autostart

# 3. Plasma 6 Look-and-Feel: заменяем стандартные обои Breeze Dark на VibeLinux
BREEZE_DEFAULTS="/usr/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/defaults"
if [[ -f "$BREEZE_DEFAULTS" ]]; then
  WALL_THEME="VibeLinux"
  if grep -q '^Image=' "$BREEZE_DEFAULTS"; then
    sed -i "s|^Image=.*|Image=${WALL_THEME}|" "$BREEZE_DEFAULTS"
  else
    printf '\n[Wallpaper]\nImage=%s\n' "$WALL_THEME" >> "$BREEZE_DEFAULTS"
  fi
  echo "OK: Breeze Dark defaults updated to use $WALL_THEME wallpaper theme"
fi

# 4. Dark Theme + VibeLinux акцентный цвет (Plasma 6)
cat > /home/vibe/.config/kdeglobals << 'KDEGLOBALS'
[KDE Initial Setup]
First Run = false

[KDE]
widgetStyle=Breeze
AnimationDurationFactor=0.75

[General]
ColorScheme=BreezeDark
Name=VibeLinux
AccentColor=76,201,240
AccentColorFromWallpaper=false
TerminalApplication=konsole
TerminalService=org.kde.konsole

[Icons]
Theme=breeze-dark

[UiSettings]
ColorScheme=BreezeDark

[Colors:Window]
BackgroundNormal=11,16,32
ForegroundNormal=255,255,255
BackgroundAlternate=16,22,42
ForegroundInactive=180,180,200
ForegroundLink=76,201,240
ForegroundVisited=114,9,183

[Colors:Selection]
BackgroundNormal=76,201,240
ForegroundNormal=11,16,32
BackgroundAlternate=60,180,220
ForegroundAccent=76,201,240

[Colors:Button]
BackgroundNormal=20,28,48
ForegroundNormal=255,255,255
BackgroundAlternate=16,22,42

[Colors:View]
BackgroundNormal=11,16,32
ForegroundNormal=220,220,240
BackgroundAlternate=16,22,42

[Colors:Complementary]
BackgroundNormal=11,16,32
ForegroundNormal=255,255,255
KDEGLOBALS
chown vibe:vibe /home/vibe/.config/kdeglobals

# 5. ColorScheme и акцентный цвет — конфиг уже в kdeglobals, применится при входе

# Konsole theme — VibeLinux dark
mkdir -p /home/vibe/.local/share/konsole
cat > /home/vibe/.local/share/konsole/VibeLinux.colorscheme << EOF
[Background]
Color=11,16,32

[BackgroundIntense]
Color=11,16,32

[BackgroundFaint]
Color=11,16,32

[Foreground]
Color=255,255,255

[ForegroundIntense]
Color=76,201,240

[ForegroundFaint]
Color=200,200,200

[Color0]
Color=11,16,32

[Color1]
Color=247,118,142

[Color2]
Color=46,196,182

[Color3]
Color=255,224,102

[Color4]
Color=76,201,240

[Color5]
Color=114,9,183

[Color6]
Color=46,196,182

[Color7]
Color=255,255,255

[Color8]
Color=100,100,100

[Color9]
Color=255,150,150

[Color10]
Color=100,255,200

[Color11]
Color=255,240,150

[Color12]
Color=120,220,255

[Color13]
Color=160,60,220

[Color14]
Color=100,255,200

[Color15]
Color=255,255,255

[General]
Name=VibeLinux
Opacity=0.95
EOF

# Konsole profile
cat > /home/vibe/.local/share/konsole/VibeLinux.profile << EOF
[Appearance]
ColorScheme=VibeLinux
Font=JetBrainsMono Nerd Font,12,-1,5,50,0,0,0,0,0,Regular

[General]
Name=VibeLinux

[Scrolling]
ScrollBarPosition=2

[TerminalFeatures]
HorizontalScrollbar=false

[Main]
TerminalCenter=false
EOF

# Set Konsole as default terminal
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/konsolerc << EOF
[General]
DefaultProfile=VibeLinux.profile
EOF

# SDDM wallpaper + theme + logo
mkdir -p /usr/share/sddm/themes/breeze

# Определяем формат обоев (PNG предпочтительнее)
SDDM_WALL=""
for ext in png jpg svg; do
  fp="/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.${ext}"
  [[ -f "$fp" ]] && { SDDM_WALL="$fp"; break; }
done

cat > /usr/share/sddm/themes/breeze/theme.conf.user << EOF
[General]
background=${SDDM_WALL:-/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg}
type=image
EOF

cat > /etc/sddm.conf.d/theme.conf << EOF
[Theme]
Current=breeze
CursorTheme=breeze_cursors
EOF

# Plymouth — VibeLinux boot splash
if [[ -d /root/branding/plymouth ]]; then
  mkdir -p /usr/share/plymouth/themes/vibelinux
  cp /root/branding/plymouth/* /usr/share/plymouth/themes/vibelinux/
  plymouth-set-default-theme vibelinux 2>/dev/null || true
fi

# GRUB config for installed system — always apply VibeLinux defaults
GRUB_DEFAULT_FILE="/etc/default/grub"
# Force known keys; sed handles both new and existing files
cat > "$GRUB_DEFAULT_FILE" << 'GRUBBASE'
# GRUB boot loader configuration
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="VibeLinux"
GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 quiet splash"
GRUB_CMDLINE_LINUX="nvidia-drm.modeset=1"
GRUB_PRELOAD_MODULES="part_gpt part_msdos btrfs"
GRUB_DISABLE_LINUX_PARTUUID=false
GRUB_DISABLE_LINUX_UUID=false
GRUB_TERMINAL_INPUT="console"
GRUB_DISABLE_RECOVERY=true
GRUB_ENABLE_CRYPTODISK=n
GRUB_SAVEDEFAULT=true
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=y
GRUBBASE

# VibeLinux branding (PNG, потому что GRUB не поддерживает SVG)
# Конвертируем SVG→PNG если PNG ещё нет
if [[ -f /root/branding/wallpapers/vibecode-dark.svg ]] && [[ ! -f /root/branding/wallpapers/vibecode-dark.png ]]; then
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 1920 -h 1080 /root/branding/wallpapers/vibecode-dark.svg -o /root/branding/wallpapers/vibecode-dark.png 2>/dev/null || true
  elif command -v convert &>/dev/null; then
    convert /root/branding/wallpapers/vibecode-dark.svg /root/branding/wallpapers/vibecode-dark.png 2>/dev/null || true
  fi
fi
WALL_PNG="/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png"
if [[ -f /root/branding/wallpapers/vibecode-dark.png ]]; then
  cp /root/branding/wallpapers/vibecode-dark.png "$WALL_PNG"
fi

cat >> "$GRUB_DEFAULT_FILE" << 'GRUBRAND'

# VibeLinux branding
GRUB_COLOR_NORMAL=white/black
GRUB_COLOR_HIGHLIGHT=white/dark-gray
GRUB_GFXMODE=1920x1080,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_FONT_PATH=/usr/share/grub/unicode.pf2
GRUBRAND

# Copy background image to GRUB theme dir (GRUB needs relative paths)
mkdir -p /boot/grub/themes/vibelinux
if [[ -f "$WALL_PNG" ]]; then
  cp "$WALL_PNG" /boot/grub/themes/vibelinux/background.png
  echo 'GRUB_BACKGROUND=/boot/grub/themes/vibelinux/background.png' >> "$GRUB_DEFAULT_FILE"
  chattr +m /boot/grub/themes/vibelinux/background.png 2>/dev/null || true
fi

# GRUB theme — VibeLinux minimal
cat > /boot/grub/themes/vibelinux/theme.txt << GRUBTHEME
# VibeLinux GRUB theme
title-text: "VibeLinux"
title-color: "#4CC9F0"
title-font: "unicode"
desktop-image: "background.png"
desktop-color: "#0B1020"
terminal-font: "unicode"
+ boot_menu {
    left = 18%
    top = 20%
    width = 64%
    height = 60%
    item_color = "#C0C0C0"
    selected_item_color = "#4CC9F0"
    item_height = 36
    item_padding = 8
    item_spacing = 6
    item_font = "unicode"
    selected_item_font = "unicode"
    scrollbar = false
}
+ progress_bar {
    id = "progress_module"
    left = 18%
    top = 85%
    width = 64%
    height = 8%
    fg_color = "#4CC9F0"
    bg_color = "#0B1020"
}
GRUBTHEME
echo 'GRUB_THEME=/boot/grub/themes/vibelinux/theme.txt' >> "$GRUB_DEFAULT_FILE"

# Fix menu entry name: 10_linux appends " Linux" to GRUB_DISTRIBUTOR,
# producing "VibeLinux Linux, with Linux linux". Remove the duplicate.
fix_10_linux() {
  local f="/etc/grub.d/10_linux"
  if [[ -f "$f" ]]; then
    # Работает и с OS="${GRUB_DISTRIBUTOR} Linux" и с OS="${GRUB_DISTRIBUTOR} Linux "
    sed -i 's/OS="${GRUB_DISTRIBUTOR}\s*Linux"/OS="${GRUB_DISTRIBUTOR}"/' "$f"
  fi
}
fix_10_linux

# Ensure nvidia-drm.modeset=1 is in GRUB_CMDLINE_LINUX_DEFAULT
if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_DEFAULT_FILE" 2>/dev/null; then
  if ! grep -q "nvidia-drm.modeset=1" "$GRUB_DEFAULT_FILE"; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' "$GRUB_DEFAULT_FILE"
  fi
fi
if grep -q "^GRUB_CMDLINE_LINUX=" "$GRUB_DEFAULT_FILE" 2>/dev/null; then
  if ! grep -q "nvidia-drm.modeset=1" "$GRUB_DEFAULT_FILE"; then
    sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 nvidia-drm.modeset=1"/' "$GRUB_DEFAULT_FILE"
  fi
fi

# Fallback: ensure /boot/vmlinuz-linux exists before mkinitcpio -P runs in the
# chroot. The kernel is always at /usr/lib/modules/<ver>/vmlinuz; the linux
# package may not ship /boot/vmlinuz-linux directly (the 90-mkinitcpio-install
# hook creates it, and may fail on relative paths).
# Copy (not symlink) — GRUB on Btrfs cannot read symlinks.
if [[ ! -s /boot/vmlinuz-linux ]]; then
  KVER=$(ls /usr/lib/modules/ 2>/dev/null | grep -v 'extramodules' | sort -V | tail -1)
  if [[ -n "$KVER" && -f "/usr/lib/modules/$KVER/vmlinuz" ]]; then
    cp --sparse=never -f "/usr/lib/modules/$KVER/vmlinuz" /boot/vmlinuz-linux
    chmod 644 /boot/vmlinuz-linux
    echo "OK: copied kernel to /boot/vmlinuz-linux ($(stat -c%s /boot/vmlinuz-linux) bytes)"
  fi
fi

# Welcome App
cat > /usr/local/bin/vibe-welcome << 'WELCOMEEOF'
#!/usr/bin/env bash
# VibeLinux first-run welcome. Запускается один раз:
# после выбора создаёт маркер ~/.vibe-welcome-done.
DONE_FILE="$HOME/.vibe-welcome-done"
if [[ -f "$DONE_FILE" ]]; then
  exit 0
fi

clear
if [[ -f /usr/share/vibelinux/ascii-logo.txt ]]; then
  cat /usr/share/vibelinux/ascii-logo.txt
else
  echo "  VibeLinux"
fi
echo ""
echo "  Welcome to VibeLinux!"
echo "  Linux for vibe coding and AI development"
echo "  ========================================="
echo ""
echo "  AI-агенты уже предустановлены: opencode, qwen, claude, codex, crush, kimi"
echo "  Ollama (локальные LLM) ставится после установки на диск: sudo install-ollama"
echo ""
if [[ -d /run/archiso/bootmnt ]]; then
  echo "  (Live-сессия: корень в RAM, тяжёлый AI-стек ставится после установки на диск)"
fi
echo "  [1] AI-инструменты (статус, MCP, доп. установки — ai-install)"
echo "  [2] AI-модели (ai-setup — после установки на диск)"
echo "  [3] System info (fastfetch)"
echo "  [4] Skip"
echo ""
read -rp "  Choose [1-4]: " choice
case "$choice" in
  1) ai-install ;;
  2) ai-setup ;;
  3) fastfetch ;;
  *) echo "  Happy coding!" ;;
esac
touch "$DONE_FILE"
exit 0
WELCOMEEOF
chmod +x /usr/local/bin/vibe-welcome

# # Autostart Welcome App — открывается только пока нет маркера (первый вход в GUI)
# mkdir -p /home/vibe/.config/autostart
# cat > /home/vibe/.config/autostart/vibe-welcome.desktop << EOF
# [Desktop Entry]
# Type=Application
# Name=VibeLinux Welcome
# Exec=bash -c '[[ -f /home/vibe/.vibe-welcome-done ]] || /usr/local/bin/vibe-welcome'
# Terminal=true
# X-GNOME-Autostart-enabled=true
# EOF

# # Welcome App shortcut on desktop
# mkdir -p /home/vibe/Desktop
# cat > /home/vibe/Desktop/VibeLinux-Welcome.desktop << EOF
# [Desktop Entry]
# Type=Application
# Name=VibeLinux Welcome
# Icon=utilities-terminal
# Exec=konsole --hold -e vibe-welcome
# Terminal=false
# Categories=System;
# EOF
# chmod 755 /home/vibe/Desktop/VibeLinux-Welcome.desktop

# Fix permissions
chown -R vibe:vibe /home/vibe

# Rust: ставим toolchain один раз при сборке, а не при каждом запуске терминала.
# Профиль minimal — без rust-docs (908 МБ) и rust-src; при желании:
#   rustup component add rust-docs
if command -v rustup &>/dev/null; then
  runuser -u vibe -- bash -c 'rustup set profile minimal && rustup default stable' && \
    touch /home/vibe/.vibe-rustup-ready || \
    echo "WARN: rustup toolchain не установлен (нет сети?) — можно: runuser -u vibe -- bash -c \"rustup default stable\""
  # Обрезаем доки у ранее установленных тулчейнов (полный профиль тянет ~900 МБ)
  rm -rf /home/vibe/.rustup/toolchains/*/share/doc
fi

# Quick Start Guide
mkdir -p /home/vibe/Desktop
cat > /home/vibe/Desktop/GET-STARTED.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>VibeLinux — Get Started</title>
<style>
  body {
    background: #0B1020;
    color: #C0C8E0;
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    max-width: 780px; margin: 2em auto; padding: 0 1.5em 3em;
    line-height: 1.7;
  }
  h1 { color: #4CC9F0; font-size: 1.6em; border-bottom: 1px solid #1E2A4A; padding-bottom: .3em; }
  h2 { color: #7C9FFF; font-size: 1.15em; margin-top: 1.6em; }
  a { color: #4CC9F0; }
  code { background: #151D35; padding: .1em .5em; border-radius: 4px; font-size: .9em; }
  pre { background: #0D1525; padding: 1em; border-radius: 6px; border: 1px solid #1E2A4A; }
  .cmd { color: #A8E6CF; }
  .sep { color: #3A4A6A; }
  ul { padding-left: 1.2em; }
  li { margin: .3em 0; }
</style>
</head>
<body>

<h1>Welcome to VibeLinux</h1>
<p>A Linux distro for <strong>vibe coding</strong> and <strong>AI development</strong> — everything works out of the box.</p>

<h2>Terminal &amp; Shell</h2>
<ul>
  <li><strong>Konsole</strong> — default terminal (Zsh + Starship)</li>
  <li><strong>Kitty</strong> — GPU-accelerated terminal</li>
  <li>CLI: <code>eza</code>, <code>bat</code>, <code>fd</code>, <code>rg</code>, <code>fzf</code>, <code>zoxide</code>, <code>btop</code></li>
</ul>

<h2>Languages &amp; Version Managers</h2>
<ul>
  <li><strong>Python</strong> — <code>pyenv install 3.12</code></li>
  <li><strong>Node.js</strong> — <code>nvm install --lts</code></li>
  <li><strong>Rust</strong> — <code>rustup default stable</code></li>
  <li><strong>Go</strong> — pre-installed</li>
  <li><strong>PHP</strong> — pre-installed</li>
</ul>

<h2>Editors</h2>
<ul>
  <li><strong>Zed</strong> — ultra-fast editor</li>
  <li><strong>Kate</strong> — KDE text editor</li>
</ul>

<h2>AI Tools (предустановлены)</h2>
<ul>
  <li><strong>opencode</strong> — <code>opencode</code> (AI coding agent)</li>
  <li><strong>qwen-code</strong> — <code>qwen</code> (Alibaba coding agent)</li>
  <li><strong>Claude Code</strong> — <code>claude</code> (Anthropic)</li>
  <li><strong>Codex</strong> — <code>codex</code> (OpenAI)</li>
  <li><strong>Kilo / MiMo / Continue / Crush / Kimi</strong> — <code>kilo</code>, <code>mimo</code>, <code>cn</code>, <code>crush</code>, <code>kimi</code></li>
  <li><strong>dmsh</strong> — offline AI shell (model included)</li>
</ul>
<p><em>Ollama и тяжёлый AI-стек (WebUI/ComfyUI/Python-venv) ставятся после установки на диск:</em></p>
<pre><span class="cmd">sudo install-ollama</span>
<span class="cmd">sudo ai-setup</span>
<span class="cmd">sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh</span></pre>

<h2>Quick Commands</h2>
<pre><span class="cmd">fastfetch</span> <span class="sep">—</span> system info
<span class="cmd">btop</span>      <span class="sep">—</span> resource monitor
<span class="cmd">eza -la</span>  <span class="sep">—</span> list files
<span class="cmd">bat</span> file  <span class="sep">—</span> cat with syntax highlighting
<span class="cmd">lazygit</span>  <span class="sep">—</span> git TUI
<span class="cmd">opencode</span> <span class="sep">—</span> AI coding agent
<span class="cmd">claude</span>   <span class="sep">—</span> Claude Code (Anthropic)
<span class="cmd">codex</span>    <span class="sep">—</span> OpenAI Codex CLI
<span class="cmd">ai-setup</span> <span class="sep">—</span> download AI models (post-install)</pre>

<h2>First Steps</h2>
<ol>
  <li>Open <strong>Konsole</strong> (or Kitty)</li>
  <li>Run <code>opencode</code> / <code>claude</code> / <code>codex</code> — all pre-installed</li>
  <li>Install VibeLinux to disk, then run <code>install-ollama</code> + <code>ai-setup</code> for local LLM models</li>
  <li>Run <code>sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh</code> for WebUI/ComfyUI/Python-стек</li>
  <li>Open <strong>Zed</strong> and start coding</li>
</ol>

</body>
</html>
EOF
chmod 644 /home/vibe/Desktop/GET-STARTED.html

# Desktop shortcuts for key apps
cat > /home/vibe/Desktop/OpenCode.desktop << EOF
[Desktop Entry]
Type=Application
Name=OpenCode
Icon=utilities-terminal
Exec=konsole --hold -e opencode
Terminal=false
Categories=Development;
EOF
chmod 755 /home/vibe/Desktop/OpenCode.desktop

# AI Agents Launcher — выбор из установленных CLI-агентов (GUI / TTY)
cat > /usr/local/bin/ai-launcher << 'LAUNCHEOF'
#!/usr/bin/env bash
# Меню установленных AI-агентов: выбор → запуск. После выхода агента
# возвращается в меню; завершение — пункт «Выход» или Ctrl+D.
AGENTS=(
  "opencode:OpenCode"
  "claude:Claude Code"
  "codex:Codex CLI"
  "qwen:Qwen Code"
  "kilo:Kilo Code"
  "mimo:Mimo"
  "crush:Crush"
  "kimi:Kimi CLI"
  "dmsh:dmsh"
)

FOUND=()
for entry in "${AGENTS[@]}"; do
  bin="${entry%%:*}"; label="${entry#*:}"
  if type -p "$bin" >/dev/null 2>&1; then
    FOUND+=("$bin" "$label")
  fi
done

if [[ ${#FOUND[@]} -eq 0 ]]; then
  MSG="AI-агенты не найдены. Запустите ai-install для установки."
  if command -v kdialog &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    kdialog --error "$MSG"
  elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" && ! -t 0 ]] && command -v konsole &>/dev/null; then
    exec konsole --hold -e "$0"
  else
    echo "$MSG" >&2
  fi
  exit 1
fi

run_agent() {
  echo "── $1 ── (выход из агента вернёт в меню)"
  "$1"
  local rc=$?
  echo "── $1 завершён (код $rc) ──"
}

if [[ ! -t 0 ]]; then
  # Запуск с ярлыка (stdin не TTY)
  if command -v kdialog &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    CHOICE="$(kdialog --title "AI Agents" --menu "Выберите AI-агента:" "${FOUND[@]}")" || exit 0
    # Агент открывается сразу; после его выхода в этом же окне появится меню
    exec konsole -e env AI_LAUNCHER_PRESELECT="$CHOICE" "$0"
  elif command -v konsole &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    # Без kdialog — просто интерактивное меню в новом окне konsole
    exec konsole -e "$0"
  else
    echo "Нет графической сессии — запустите ai-launcher в терминале." >&2
    exit 1
  fi
fi

# Предвыбранный агент (из kdialog-ярлыка): запускаем, дальше — обычное меню
PRE="${AI_LAUNCHER_PRESELECT:-}"
if [[ -n "$PRE" ]] && type -p "$PRE" >/dev/null 2>&1; then
  run_agent "$PRE"
fi

OPTIONS=()
i=0
while [[ $i -lt ${#FOUND[@]} ]]; do
  OPTIONS+=("${FOUND[$i]} — ${FOUND[$((i+1))]}")
  i=$((i+2))
done

while true; do
  BODY_RUN=0
  PS3=$'\nВыберите агента (номер): '
  select opt in "${OPTIONS[@]}" "Выход"; do
    BODY_RUN=1
    [[ -z "$opt" || "$opt" == "Выход" ]] && exit 0
    run_agent "${opt%% — *}"
    break            # перерисовать меню
  done
  [[ $BODY_RUN -eq 0 ]] && exit 0   # EOF/Ctrl+D вместо номера — выходим
done
LAUNCHEOF
chmod +x /usr/local/bin/ai-launcher

cat > /home/vibe/Desktop/AI-Launcher.desktop << EOF
[Desktop Entry]
Type=Application
Name=AI Agents
Icon=utilities-terminal
Exec=/usr/local/bin/ai-launcher
Terminal=false
Categories=Development;
EOF
chmod 755 /home/vibe/Desktop/AI-Launcher.desktop

cat > /home/vibe/Desktop/Install-AI-Tools.desktop << EOF
[Desktop Entry]
Type=Application
Name=Install AI Tools
Icon=utilities-terminal
Exec=konsole --hold -e ai-install
Terminal=false
Categories=System;
EOF
chmod 755 /home/vibe/Desktop/Install-AI-Tools.desktop

# Zed — desktop shortcut (copy from package .desktop)
if [[ -f /usr/share/applications/dev.zed.Zed.desktop ]]; then
  cp /usr/share/applications/dev.zed.Zed.desktop /home/vibe/Desktop/Zed.desktop
  chmod 755 /home/vibe/Desktop/Zed.desktop
fi

# dmsh — Natural Language Shell (AI Shell Assistant)
echo "Installing dmsh..."
DMSH_INSTALLED=0
# Берём самый свежий пакет по mtime (в /root/dmsh может лежать несколько)
DMSH_PKG="$(ls -t /root/dmsh/dmsh-*.pkg.tar.zst 2>/dev/null | head -1 || true)"
if [[ -n "$DMSH_PKG" ]]; then
  # Pre-built Arch package — installs /usr/bin/dmsh
  # Post-transaction hooks (PackageKit/DBus) can fail inside the chroot;
  # tolerate that and verify the binary instead of the pacman exit code.
  DMSH_TGT=/usr/bin/dmsh
  # Сносим предыдущую инсталляцию (иначе даунгрейд/битая база мешают -U)
  pacman -Rdd --noconfirm dmsh >/dev/null 2>&1 || true
  rm -f "$DMSH_TGT" "$DMSH_TGT.real"
  pacman -U --noconfirm "$DMSH_PKG" >/dev/null 2>&1 || true
  if [[ ! -x "$DMSH_TGT" ]]; then
    # pacman -U может упасть в chroot из-за нехватки места (как far2l);
    # извлекаем файлы пакета напрямую — /usr/bin/dmsh попадает на место.
    tar -I zstd -xf "$DMSH_PKG" -C / 2>/dev/null || true
  fi
  if [[ -x "$DMSH_TGT" ]]; then
    DMSH_INSTALLED=1
    echo "OK: dmsh installed from pre-built package ($(basename "$DMSH_PKG"))"
  else
    echo "ERROR: dmsh package installation failed"
  fi
elif [[ -f /root/dmsh/dmsh ]]; then
  cp /root/dmsh/dmsh /usr/local/bin/dmsh
  chmod +x /usr/local/bin/dmsh
  DMSH_INSTALLED=1
fi

if [[ $DMSH_INSTALLED -eq 1 ]]; then
  # Bundle small AI model for offline use (Q2_K ~200MB for weak machines)
  DMSH_MODELS_DIR="/home/vibe/.config/dmsh/models"
  mkdir -p "$DMSH_MODELS_DIR"

  MODEL_NAME="qwen2.5-0.5b-instruct-q2_k.gguf"
  MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf"

  if [[ -f /root/dmsh/models/$MODEL_NAME ]]; then
    cp /root/dmsh/models/$MODEL_NAME "$DMSH_MODELS_DIR/"
    chown vibe:vibe "$DMSH_MODELS_DIR/$MODEL_NAME"
    echo "OK: bundled model Q2_K from local file"
  else
    echo "Downloading Q2_K model (~200MB)..."
    curl -L "$MODEL_URL" -o "$DMSH_MODELS_DIR/$MODEL_NAME" 2>&1 | tail -5 || \
      echo "WARNING: model download failed"
    chown vibe:vibe "$DMSH_MODELS_DIR/$MODEL_NAME" 2>/dev/null || true
  fi

  # Default config for vibe user
  DMSH_CONFIG_DIR="/home/vibe/.config/dmsh"
  mkdir -p "$DMSH_CONFIG_DIR"
  cat > "$DMSH_CONFIG_DIR/config.json" << NLSCONF
{
  "default_model": "$MODEL_NAME",
  "ctx_size": 2048,
  "max_tokens": 256,
  "temperature": 0.2,
  "top_p": 0.9,
  "mode": "ai",
  "shell": "/bin/zsh"
}
NLSCONF
  chown -R vibe:vibe "$DMSH_CONFIG_DIR"

  if [[ -f /root/dmsh/dmsh.svg ]]; then
    cp /root/dmsh/dmsh.svg /usr/share/pixmaps/dmsh.svg
  fi

  cat > /home/vibe/Desktop/dmsh.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=dmsh — AI Shell Assistant
GenericName=Natural Language Shell
Comment=AI-ассистент для управления системой через естественный язык
Exec=konsole --hold -e dmsh
Icon=dmsh
Terminal=false
Categories=Development;Utility;AI;
Keywords=ai;llm;shell;assistant;local;
StartupNotify=false
EOF
  chmod 755 /home/vibe/Desktop/dmsh.desktop
  echo "dmsh installed with llama.cpp engine + offline model"
else
  echo "WARNING: dmsh not found in /root/dmsh/ (no binary, no pre-built package)"
fi

# Copy desktop shortcuts to system applications so they appear in Kickoff menu
# Skip files that already exist or came from packages (avoid duplicates in menu)
for f in /home/vibe/Desktop/*.desktop; do
  base=$(basename "$f")
  # Skip Zed — already installed by package as dev.zed.Zed.desktop
  [[ "$base" == "Zed.desktop" ]] && continue
  if [[ ! -f "/usr/share/applications/$base" ]]; then
    cp "$f" /usr/share/applications/
  fi
done

# KDE Kickoff Favorites
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/kickoffrc << 'EOF'
[General]
favorites=preferred://browser,org.kde.dolphin.desktop,org.kde.konsole.desktop,OpenCode.desktop,AI-Launcher.desktop,Install-AI-Tools.desktop,VibeLinux-Welcome.desktop
EOF
chown vibe:vibe /home/vibe/.config/kickoffrc

# === AUR packages ===
echo "Installing AUR packages..."
# Активируем первый mirror в /etc/pacman.d/mirrorlist (все закомментированы по умолчанию)
if grep -q '^#Server' /etc/pacman.d/mirrorlist 2>/dev/null; then
  sed -i '0,/^#Server/{s/^#Server/Server/}' /etc/pacman.d/mirrorlist
  echo "OK: first mirror activated in /etc/pacman.d/mirrorlist"
fi

if ! id builder &>/dev/null; then
  useradd -m builder
fi
# builder needs sudo for makepkg to install dependencies
echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-builder
mkdir -p /tmp/aur-build
chown builder:builder /tmp/aur-build

aur_build() {
  local pkg=$1 dir=$2
  # 1) Кэш pre-built пакетов (заполняется build-vibe-arch.sh из /srv/vibe-aur-cache)
  local cached
  cached=$(ls /root/aur-cache/${pkg}-*.pkg.tar.zst 2>/dev/null | head -1)
  if [[ -n "$cached" && -f "$cached" ]]; then
    echo "Installing $pkg from cache..."
    pacman -U --noconfirm "$cached" 2>/dev/null || bsdtar -xpf "$cached" -C /
    echo "$pkg installed from cache"
    return 0
  fi
  # 2) Иначе собираем из AUR
  echo "Building $pkg from AUR (в первый раз — потом возьмётся из кэша)..."
  runuser -u builder -- bash -c "
    cd /tmp/aur-build
    rm -rf $dir
    git clone --depth 1 https://aur.archlinux.org/$pkg.git $dir 2>/dev/null
    cd $dir
    makepkg --noconfirm --skippgpcheck -s
  " 2>&1 | tail -10 || echo "WARNING: $pkg build failed"
  local pkg_file
  pkg_file=$(ls /tmp/aur-build/$dir/*.pkg.tar.zst 2>/dev/null | head -1)
  if [[ -n "$pkg_file" && -f "$pkg_file" ]]; then
    pacman -U --noconfirm "$pkg_file" 2>/dev/null || bsdtar -xpf "$pkg_file" -C /
    mkdir -p /root/aur-cache
    cp "$pkg_file" /root/aur-cache/
    echo "$pkg installed"
  fi
}

aur_build yay-bin yay
aur_build calamares calamares
# far2l — pre-built packages (pacman -U sometimes fails in chroot due to space checks)
if ls /root/far2l/far2l-*.pkg.tar.zst 2>/dev/null | head -1; then
  echo "Installing far2l from pre-built packages..."
  # Try pacman -U first; fall back to tar extraction
  if pacman -U --noconfirm /root/far2l/far2l-2.8.0-1-x86_64.pkg.tar.zst \
                            /root/far2l/far2l-gui-2.8.0-1-x86_64.pkg.tar.zst; then
    echo "far2l + far2l-gui installed via pacman"
  else
    echo "pacman -U failed, falling back to tar extraction..."
    tar -I zstd -xf /root/far2l/far2l-2.8.0-1-x86_64.pkg.tar.zst -C /
    tar -I zstd -xf /root/far2l/far2l-gui-2.8.0-1-x86_64.pkg.tar.zst -C /
    echo "far2l + far2l-gui extracted (not in pacman DB)"
  fi
  rm -rf /root/far2l
else
  echo "WARNING: far2l pre-built packages not found"
fi
# Pinta — lightweight image editor (AppImage, прямой download вместо AUR)
PINTA_URL="https://github.com/pkgforge-dev/Pinta-AppImage/releases/latest/download/Pinta-3.1.2-1-anylinux-x86_64.AppImage"
if [[ ! -f /opt/pinta/pinta.AppImage ]]; then
  mkdir -p /opt/pinta
  echo "Downloading Pinta AppImage..."
  curl -sL "$PINTA_URL" -o /opt/pinta/pinta.AppImage 2>/dev/null || true
  if [[ -s /opt/pinta/pinta.AppImage ]]; then
    chmod +x /opt/pinta/pinta.AppImage
    ln -sf /opt/pinta/pinta.AppImage /usr/local/bin/pinta
    cat > /usr/share/applications/pinta.desktop << 'PINTADESK'
[Desktop Entry]
Name=Pinta
Comment=Simple GTK Paint Program
Exec=/opt/pinta/pinta.AppImage
Icon=pinta
Type=Application
Categories=Graphics;2DGraphics;RasterGraphics;GTK;
StartupNotify=false
MimeType=image/bmp;image/gif;image/jpeg;image/jpg;image/png;image/tiff;image/x-xcf;
X-AppImage-Version=3.1.2
PINTADESK
    echo "OK: Pinta installed from AppImage"
  else
    echo "WARNING: Pinta download failed, skipping"
    rm -f /opt/pinta/pinta.AppImage
  fi
fi
# Calamares built from AUR source — no Python/Boost dependencies
if [[ -x /usr/bin/calamares ]]; then
  MISSING=$(for f in $(find /usr/lib/calamares -name '*.so' -type f 2>/dev/null); do ldd "$f" 2>/dev/null; done | grep "not found" | awk '{print $1}' | sort -u)
  if [[ -z "$MISSING" ]]; then
    echo "OK: calamares — all libraries resolved"
  else
    echo "WARNING: calamares — missing: $MISSING"
  fi
fi

rm -f /etc/sudoers.d/90-builder
userdel builder 2>/dev/null || true
rm -rf /tmp/aur-build



# Calamares — конфигурация для VibeLinux
mkdir -p /etc/calamares /etc/calamares/modules /usr/share/calamares/modules
cat > /etc/calamares/settings.conf << 'CALCONF'
---
modules-search: [ local ]

instances:
  - id:       shellprocess-kernel-copy
    module:   shellprocess
    config:   shellprocess-kernel-copy.conf
  - id:       shellprocess-finalize-boot
    module:   shellprocess
    config:   shellprocess-finalize-boot.conf

branding: vibelinux

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - partition
    - mount
    - unpackfs
    - shellprocess@shellprocess-kernel-copy
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - initcpiocfg
    - initcpio
    - users
    - displaymanager
    - networkcfg
    - hwclock
    - services-systemd
    - bootloader
    - shellprocess@shellprocess-finalize-boot
    - umount
  - show:
    - finished

prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: true
CALCONF

# Конфигурации модулей Calamares
mkdir -p /etc/calamares/modules

# welcome — приветствие и проверка требований
cat > /etc/calamares/modules/welcome.conf << 'EOF'
---
showSupportUrl: true
showKnownIssuesUrl: true
showReleaseNotesUrl: false
requirements:
  requiredStorage: 8.0
  requiredRam: 2.0
  check:
    - storage
    - ram
    - root
    - screen
  required:
    - ram
    - root
EOF

# locale — выбор языка и часового пояса
cat > /etc/calamares/modules/locale.conf << 'EOF'
---
geoipUrl: "https://ipapi.co/json/"
geoipStyle: "json"
geoipSelector: "timezone"
EOF

# keyboard — раскладка клавиатуры
cat > /etc/calamares/modules/keyboard.conf << 'EOF'
---
EOF

# partition — разметка диска
cat > /etc/calamares/modules/partition.conf << 'EOF'
---
efiSystemPartition: "/boot"
efiSystemPartitionSize: 512M
userSwapChoices:
  - none
  - file
drawNestedPartitions: false
alwaysShowPartitionLabels: true
initialPartitioningChoice: none
initialSwapChoice: none
defaultFileSystemType: "btrfs"
availableFileSystemTypes: ["btrfs", "ext4", "xfs", "f2fs"]
EOF

# users — создание пользователя
# users — дополняем CachyOS-дефолт (добавляем docker, autologin)
USERS_CONF="/etc/calamares/modules/users.conf"
if [[ -f "$USERS_CONF" ]]; then
  sed -i 's/doAutologin: *false/doAutologin: true/' "$USERS_CONF"
  if ! grep -q 'autologinGroup' "$USERS_CONF"; then
    sed -i '/^doAutologin:/a\autologinGroup: wheel' "$USERS_CONF"
  fi
  if ! grep -q '\- docker' "$USERS_CONF"; then
    awk '
/^[a-zA-Z0-9]/ && !seen_default && default_section {
    print "    - docker"
    default_section = 0
}
/^defaultGroups:/ { default_section = 1; seen_default = 1 }
{ print }
' "$USERS_CONF" > "${USERS_CONF}.tmp" && mv "${USERS_CONF}.tmp" "$USERS_CONF"
  fi
else
  # fallback — создаём минимальный, если CachyOS конфига нет
  cat > "$USERS_CONF" << 'EOF'
---
defaultGroups:
  - wheel
  - audio
  - video
  - storage
  - power
  - network
  - docker
autologinGroup: wheel
doAutologin: true
EOF
fi

# mount — монтирование разделов (используем дефолтный от CachyOS, он уже в пакете)

# unpackfs — копирование системы в целевой раздел
cat > /etc/calamares/modules/unpackfs.conf << 'EOF'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
EOF

# vibe-finalize-boot — универсальный скрипт финализации файлов загрузки
mkdir -p /usr/local/bin
cat > /usr/local/bin/vibe-finalize-boot << 'SCRIPT'
#!/bin/bash
# vibe-finalize-boot — финализация файлов загрузки VibeLinux.
# 1. Заменяет симлинки в /boot на реальные копии (фикс GRUB на Btrfs).
# 2. Синхронизирует ядра из /usr/lib/modules/ в /boot.
# 3. Делает установленное ядро дефолтным (vmlinuz-linux / initramfs-linux.img).
# 4. Исправляет sparse grubenv.
set -e

KERNEL_DST="/boot/vmlinuz-linux"
INITRD_DST="/boot/initramfs-linux.img"
INITRD_FALLBACK_DST="/boot/initramfs-linux-fallback.img"
GRUBENV="/boot/grub/grubenv"

# Detect filesystem type of /boot
BOOT_FSTYPE=$(findmnt -n -o FSTYPE /boot 2>/dev/null || echo "unknown")

echo "=== VibeLinux Boot Finalizer ==="
echo "Boot filesystem type: $BOOT_FSTYPE"

# 1. Заменяем все симлинки в /boot на реальные файлы
echo "Checking symlinks in /boot..."
for f in /boot/vmlinuz-* /boot/initramfs-*; do
  [ -e "$f" ] || continue
  if [ -h "$f" ]; then
    target=$(readlink -f "$f")
    if [ -f "$target" ]; then
      rm -f "$f"
      cp --sparse=never -f "$target" "$f"
      chmod 644 "$f"
      echo "  -> Replaced symlink $f with copy of $target"
    fi
  fi
done

# 2. Копируем ядра из /usr/lib/modules/ в /boot
echo "Syncing kernels from /usr/lib/modules/..."
PRIMARY_KERNEL=""
for d in /usr/lib/modules/*/; do
  kver="${d%/}"
  kver="${kver##*/}"
  [ "$kver" = "extramodules" ] || [ "$kver" = "extramessages" ] && continue

  if [ -f "${d}vmlinuz" ]; then
    # Определяем имя ядра из pkgbase
    if [ -f "${d}pkgbase" ]; then
      kernel_name=$(cat "${d}pkgbase" | tr -d ' \n\r')
    else
      # Fallback угадывание по имени директории
      if [[ "$kver" == *"-cachyos"* ]]; then
        kernel_name="linux-cachyos"
      elif [[ "$kver" == *"-zen"* ]]; then
        kernel_name="linux-zen"
      elif [[ "$kver" == *"-lts"* ]]; then
        kernel_name="linux-lts"
      else
        kernel_name="linux"
      fi
    fi

    echo "Found kernel: $kernel_name (version: $kver)"
    if [ -z "$PRIMARY_KERNEL" ]; then
      PRIMARY_KERNEL="$kernel_name"
    fi

    dest="/boot/vmlinuz-$kernel_name"
    rm -f "$dest"
    cp --sparse=never -f "${d}vmlinuz" "$dest"
    chmod 644 "$dest"
    echo "  -> Copied kernel to $dest"
  fi
done

# 3. Делаем основное ядро дефолтным (vmlinuz-linux)
if [ -n "$PRIMARY_KERNEL" ]; then
  if [ "$PRIMARY_KERNEL" != "linux" ]; then
    echo "Making $PRIMARY_KERNEL the default kernel..."
    rm -f "$KERNEL_DST"
    cp --sparse=never -f "/boot/vmlinuz-$PRIMARY_KERNEL" "$KERNEL_DST"
    chmod 644 "$KERNEL_DST"

    if [ -f "/boot/initramfs-$PRIMARY_KERNEL.img" ]; then
      rm -f "$INITRD_DST"
      cp --sparse=never -f "/boot/initramfs-$PRIMARY_KERNEL.img" "$INITRD_DST"
      chmod 644 "$INITRD_DST"
      echo "  -> Copied initramfs to $INITRD_DST"
    fi

    if [ -f "/boot/initramfs-$PRIMARY_KERNEL-fallback.img" ]; then
      rm -f "$INITRD_FALLBACK_DST"
      cp --sparse=never -f "/boot/initramfs-$PRIMARY_KERNEL-fallback.img" "$INITRD_FALLBACK_DST"
      chmod 644 "$INITRD_FALLBACK_DST"
      echo "  -> Copied fallback initramfs to $INITRD_FALLBACK_DST"
    fi
  else
    echo "Primary kernel is standard 'linux'. Default mapping skipped (already set up)."
  fi
fi

# 4. Fix sparse grubenv
create_grubenv() {
  rm -f "$GRUBENV" 2>/dev/null || true
  if command -v grub-editenv &>/dev/null; then
    grub-editenv "$GRUBENV" create
  else
    # legacy fallback — создаёт не-sparse 1024‑байтовый файл
    dd if=/dev/zero bs=1024 count=1 of="$GRUBENV" conv=notrunc status=none 2>/dev/null
  fi
  chmod 644 "$GRUBENV"
  chattr -c "$GRUBENV" 2>/dev/null || true
}

if [ "$BOOT_FSTYPE" != "vfat" ] && [ "$BOOT_FSTYPE" != "fat32" ]; then
  if [ -f "$GRUBENV" ]; then
    SIZE=$(stat -c%s "$GRUBENV" 2>/dev/null || echo 0)
    BLOCKS=$(stat -c%b "$GRUBENV" 2>/dev/null || echo 0)
    if [ "$SIZE" -ne 1024 ] || [ "$BLOCKS" -eq 0 ]; then
      echo "WARN: grubenv is sparse or wrong size ($SIZE bytes, $BLOCKS blocks), recreating..."
      create_grubenv
    else
      echo "OK: grubenv is valid"
    fi
  elif command -v grub-install &>/dev/null; then
    echo "Creating grubenv..."
    mkdir -p "$(dirname "$GRUBENV")"
    create_grubenv
  fi
fi

# 5. Recreate GRUB theme (grub-install может перезаписать /boot/grub/)
echo "Ensuring GRUB theme..."
WALL_PNG="/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png"
mkdir -p /boot/grub/themes/vibelinux
if [[ -f "$WALL_PNG" ]]; then
  cp "$WALL_PNG" /boot/grub/themes/vibelinux/background.png
  chattr +m /boot/grub/themes/vibelinux/background.png 2>/dev/null || true
fi

cat > /boot/grub/themes/vibelinux/theme.txt << GRUBTHEME
# VibeLinux GRUB theme
title-text: "VibeLinux"
title-color: "#4CC9F0"
title-font: "unicode"
desktop-image: "background.png"
desktop-color: "#0B1020"
terminal-font: "unicode"
+ boot_menu {
    left = 18%
    top = 20%
    width = 64%
    height = 60%
    item_color = "#C0C0C0"
    selected_item_color = "#4CC9F0"
    item_height = 36
    item_padding = 8
    item_spacing = 6
    item_font = "unicode"
    selected_item_font = "unicode"
    scrollbar = false
}
+ progress_bar {
    id = "progress_module"
    left = 18%
    top = 85%
    width = 64%
    height = 8%
    fg_color = "#4CC9F0"
    bg_color = "#0B1020"
}
GRUBTHEME
chmod 644 /boot/grub/themes/vibelinux/theme.txt
echo "  -> GRUB theme ensured at /boot/grub/themes/vibelinux/theme.txt"

# 6. Fix 10_linux menu entry (убираем дубликат "Linux" в названии)
if [[ -f /etc/grub.d/10_linux ]]; then
  sed -i 's/OS="${GRUB_DISTRIBUTOR}\s*Linux"/OS="${GRUB_DISTRIBUTOR}"/' /etc/grub.d/10_linux
fi
SCRIPT
chmod +x /usr/local/bin/vibe-finalize-boot

# shellprocess-kernel-copy — копирование ядра в /boot/vmlinuz-linux
cat > /etc/calamares/modules/shellprocess-kernel-copy.conf << 'EOF'
---
dontChroot: false
timeout: 10
script:
    - "/usr/local/bin/vibe-finalize-boot"
EOF

# shellprocess-finalize-boot — финализация загрузчика после установки
cat > /etc/calamares/modules/shellprocess-finalize-boot.conf << 'EOF'
---
dontChroot: false
timeout: 60
script:
    - "/usr/local/bin/vibe-finalize-boot"
    - "grub-mkconfig -o /boot/grub/grub.cfg"
    - "if [ ! -d /sys/firmware/efi ]; then grub-install --target=i386-pc --boot-directory=/boot \"$(lsblk -ndo pkname \"$(findmnt -n -o SOURCE /)\" 2>/dev/null | head -1)\" 2>/dev/null || grub-install --target=i386-pc --boot-directory=/boot /dev/sda; fi"
    - "if command -v limine-entry-tool &>/dev/null; then limine-entry-tool; fi"
EOF

# machineid — генерация machine-id
cat > /etc/calamares/modules/machineid.conf << 'EOF'
---
EOF

# fstab — генерация fstab
cat > /etc/calamares/modules/fstab.conf << 'EOF'
---
EOF

# localecfg — настройка локали в целевой системе
cat > /etc/calamares/modules/localecfg.conf << 'EOF'
---
EOF

# initcpiocfg — конфигурация mkinitcpio (initramfs)
cat > /etc/calamares/modules/initcpiocfg.conf << 'EOF'
---
useSystemdHook: false
hooks:
  prepend: [  ]
  append: [  ]
  remove: [ "archiso" ]
source: "/etc/mkinitcpio.conf"
EOF

# initcpio — генерация initramfs
cat > /etc/calamares/modules/initcpio.conf << 'EOF'
---
EOF

# displaymanager — настройка DM (SDDM для KDE Plasma)
cat > /etc/calamares/modules/displaymanager.conf << 'EOF'
---
displaymanagers:
  - sddm
  - lightdm
  - gdm
  - lxdm
sysconfigSetup: false
sddm:
  configuration_file: "/etc/sddm.conf"
lightdm:
  preferred_greeters: ["lightdm-greeter.desktop", "slick-greeter.desktop"]
EOF

# networkcfg — копирование настроек сети
cat > /etc/calamares/modules/networkcfg.conf << 'EOF'
---
EOF

# hwclock — настройка аппаратных часов
cat > /etc/calamares/modules/hwclock.conf << 'EOF'
---
EOF

# services-systemd — включение служб
cat > /etc/calamares/modules/services-systemd.conf << 'EOF'
---
services:
  - name: NetworkManager
    action: enable
  - name: bluetooth
    action: enable
  - name: sddm
    action: enable
  - name: docker
    action: enable
  # ollama не включён — она не входит в ISO и ставится post-install
  # (install-ollama сам включает systemd-сервис)
  - name: vibe-welcome
    action: enable
EOF

# bootloader — установка загрузчика (GRUB)
cat > /etc/calamares/modules/bootloader.conf << 'EOF'
---
efiBootLoader: "grub"
efiBootloaderId: "vibelinux"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
kernelSearchPath: "/boot"
kernelPattern: "^vmlinuz-linux$"
kernelParams: [ "quiet", "nowatchdog" ]
installEFIFallback: true
EOF

# umount — размонтирование
cat > /etc/calamares/modules/umount.conf << 'EOF'
---
EOF

# VibeLinux брендинг для Calamares
mkdir -p /usr/share/calamares/branding/vibelinux
# Копируем логотип для Calamares
if [[ -f /usr/share/pixmaps/vibelinux.png ]]; then
  cp /usr/share/pixmaps/vibelinux.png /usr/share/calamares/branding/vibelinux/logo.png
elif [[ -f /root/branding/logos/vibecodeos-logo.svg ]]; then
  # Fallback: копируем SVG если PNG не сгенерировался
  cp /root/branding/logos/vibecodeos-logo.svg /usr/share/calamares/branding/vibelinux/logo.svg
fi
cat > /usr/share/calamares/branding/vibelinux/branding.desc << 'BRANDCONF'
---
componentName: vibelinux
strings:
  productName: VibeLinux
  shortProductName: VibeLinux
  version: 2026.04
  shortVersion: "2026.04"
  versionedName: VibeLinux 2026.04
  shortVersionedName: VibeLinux 2026.04
  bootloaderEntryName: VibeLinux
  productUrl: https://vibelinux.org
  supportUrl: https://github.com/vibelinux
  knownIssuesUrl: https://github.com/vibelinux/issues
  releaseNotesUrl: https://github.com/vibelinux/releases
images:
  productLogo: "logo.png"
  productIcon: "logo.png"
  productWelcome: "logo.png"
slideshow: "show.qml"
style:
  sidebarBackground: "#0B1020"
  sidebarText: "#FFFFFF"
  sidebarTextSelect: "#4CC9F0"
BRANDCONF

# Простой слайдшоу для Calamares
cat > /usr/share/calamares/branding/vibelinux/show.qml << 'SHOWQML'
import QtQuick 2.0
Rectangle {
    width: 800; height: 480; color: "#0B1020"
    Text {
        anchors.centerIn: parent
        text: "VibeLinux — Linux for vibe coding & AI development"
        color: "#4CC9F0"
        font.pixelSize: 24
    }
}
SHOWQML

# Ярлык Calamares на рабочем столе
INSTALLER_ICON="calamares"
if [[ ! -f /usr/share/icons/hicolor/scalable/apps/calamares.svg ]] && \
   [[ ! -f /usr/share/icons/hicolor/128x128/apps/calamares.png ]]; then
  INSTALLER_ICON="system-software-install"
fi
cat > /home/vibe/Desktop/Install-VibeLinux.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install VibeLinux
Name[ru]=Установить VibeLinux
GenericName=System Installer
Comment=Install VibeLinux to your hard drive
Comment[ru]=Установить VibeLinux на жёсткий диск
Icon=INSTALLER_ICON_PLACEHOLDER
TryExec=/usr/bin/calamares
Exec=sudo /usr/bin/calamares
Terminal=false
Categories=System;
StartupNotify=true
DESKTOP
sed -i "s/INSTALLER_ICON_PLACEHOLDER/$INSTALLER_ICON/" /home/vibe/Desktop/Install-VibeLinux.desktop
chmod 755 /home/vibe/Desktop/Install-VibeLinux.desktop

# Копируем ярлыки в /etc/skel/Desktop (кроме Install-VibeLinux — он только для live-сессии)
mkdir -p /etc/skel/Desktop
for f in /home/vibe/Desktop/*.desktop; do
  if [[ "$(basename "$f")" != "Install-VibeLinux.desktop" ]]; then
    cp "$f" /etc/skel/Desktop/
  fi
done
# Quick Start Guide — руководство для новых пользователей
if [[ -f /home/vibe/Desktop/GET-STARTED.html ]]; then
  cp /home/vibe/Desktop/GET-STARTED.html /etc/skel/Desktop/
fi

# Копируем обои и autostart в /etc/skel
mkdir -p /etc/skel/.config /etc/skel/.config/autostart
if [[ -f /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc ]]; then
  cp /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc /etc/skel/.config/
fi
if [[ -f /home/vibe/.config/autostart/set-wallpaper.desktop ]]; then
  cp /home/vibe/.config/autostart/set-wallpaper.desktop /etc/skel/.config/autostart/
fi
if [[ -f /home/vibe/.config/kdeglobals ]]; then
  cp /home/vibe/.config/kdeglobals /etc/skel/.config/
fi
if [[ -f /home/vibe/.config/konsolerc ]]; then
  cp /home/vibe/.config/konsolerc /etc/skel/.config/
fi
if [[ -f /home/vibe/.config/kickoffrc ]]; then
  cp /home/vibe/.config/kickoffrc /etc/skel/.config/
fi

# Копируем dmsh config и model в /etc/skel
if [[ -d /home/vibe/.config/dmsh ]]; then
  mkdir -p /etc/skel/.config/dmsh
  cp -r /home/vibe/.config/dmsh/* /etc/skel/.config/dmsh/
  chown -R root:root /etc/skel/.config/dmsh
fi

# Копируем Konsole theme
if [[ -d /home/vibe/.local/share/konsole ]]; then
  mkdir -p /etc/skel/.local/share/konsole
  cp -r /home/vibe/.local/share/konsole/* /etc/skel/.local/share/konsole/
fi

# Копируем конфиги терминала и оболочки для новых пользователей
# starship
if [[ -f /home/vibe/.config/starship.toml ]]; then
  mkdir -p /etc/skel/.config
  cp /home/vibe/.config/starship.toml /etc/skel/.config/
fi
# .zshrc
if [[ -f /home/vibe/.zshrc ]]; then
  cp /home/vibe/.zshrc /etc/skel/
fi
# kitty
if [[ -d /home/vibe/.config/kitty ]]; then
  mkdir -p /etc/skel/.config/kitty
  cp /home/vibe/.config/kitty/kitty.conf /etc/skel/.config/kitty/
fi
# gitconfig
if [[ -f /home/vibe/.gitconfig ]]; then
  cp /home/vibe/.gitconfig /etc/skel/
fi
# lazygit
if [[ -f /home/vibe/.config/lazygit/config.yml ]]; then
  mkdir -p /etc/skel/.config/lazygit
  cp /home/vibe/.config/lazygit/config.yml /etc/skel/.config/lazygit/
fi

# Копируем dmsh model в /etc/skel для новых пользователей
if [[ -d /home/vibe/.config/dmsh/models ]]; then
  mkdir -p /etc/skel/.config/dmsh/models
  cp -r /home/vibe/.config/dmsh/models/* /etc/skel/.config/dmsh/models/
  chown -R root:root /etc/skel/.config/dmsh
fi

chown -R root:root /etc/skel

# Убеждаемся что calamares можно запускать через sudo без пароля для пользователя vibe
if ! grep -q 'calamares' /etc/sudoers.d/90_vibe 2>/dev/null; then
  echo "vibe ALL=(ALL) NOPASSWD: /usr/bin/calamares" >> /etc/sudoers.d/90_vibe
fi

# Скрипт настройки live-среды (обновление зеркал, проверка места)
cat > /usr/local/bin/vibe-live-setup << 'LIVESETUP'
#!/usr/bin/env bash
echo "=== VibeLive — настройка live-среды ==="
echo ""

# 1. RAM / Space info
echo "── Система ──"
free -h | head -2
echo ""
echo "── Диски / overlay ──"
df -h / /tmp /var/cache/pacman/pkg 2>/dev/null | column -t
echo ""

# 2. Обновление зеркал pacman
echo "── Зеркала pacman ──"
if command -v reflector &>/dev/null; then
  echo "Обновление списка зеркал (reflector)..."
  reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null && \
    echo "OK: зеркала обновлены" || \
    echo "Ошибка: reflector не смог обновить зеркала (проверьте соединение)"
else
  echo "reflector не установлен"
fi
echo ""

# 3. Проверка pacman
echo "── Pacman ──"
if pacman -Sy &>/dev/null; then
  echo "OK: pacman работает"
else
  echo "Проблема с pacman. Попробуйте вручную:"
  echo "  sudo pacman -Syu"
fi
echo ""

# 4. Советы
echo "── Полезные команды ──"
echo "  AI-агенты (уже стоят):     opencode, qwen, claude, codex, crush, kimi"
echo "  Ollama (после установки):  sudo install-ollama"
echo "  AI-модели (после установки): sudo ai-setup"
echo "  AI stack (после установки): sudo /opt/vibecode/scripts/ai/setup-ai-stack.sh"
echo "  Установить пакет:          sudo pacman -S <package>"
echo "  Обновить все пакеты:       sudo pacman -Syu"
echo "  Discover (GUI магазин):    discover"
echo "  Установить ISO:            На рабочем столе → Install VibeLinux"
echo "  Очистить кэш pacman:       sudo pacman -Scc"
echo ""
echo "Live-сессия работает в оперативной памяти."
echo "Для постоянного использования установите VibeLinux на диск."
LIVESETUP
chmod +x /usr/local/bin/vibe-live-setup

# Ярлык для vibe-live-setup на рабочем столе
cat > /home/vibe/Desktop/VibeLive-Setup.desktop << 'DESKTOPLIVE'
[Desktop Entry]
Type=Application
Name=VibeLive Setup
Name[ru]=Настройка VibeLive
Comment=Setup live environment — mirrors, space check
Comment[ru]=Настройка live-среды — зеркала, проверка места
Exec=konsole --hold -e sudo /usr/local/bin/vibe-live-setup
Icon=system-software-update
Terminal=false
Categories=System;
DESKTOPLIVE
chmod 755 /home/vibe/Desktop/VibeLive-Setup.desktop

# Пакетный менеджер Discover для GUI
if [[ -f /usr/bin/discover ]]; then
  # Убеждаемся что PackageKit запущен
  systemctl enable packagekit 2>/dev/null || true
fi

chown -R vibe:vibe /home/vibe

# ── Slim ISO: чистим мусор перед сжатием squashfs ─────────────────────
# Кэш npm после глобальных установок агентов (~650 МБ)
rm -rf /root/.npm /home/vibe/.npm /home/builder/.npm
# Локали: оставляем только ru/en (+ сам файл locale.alias)
find /usr/share/locale -mindepth 1 -maxdepth 1 \
  ! -name 'ru*' ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} +
# Офлайн-доки (актуальны онлайн: man.archlinux.org, docs.rs)
rm -rf /usr/share/doc/* /usr/share/gtk-doc 2>/dev/null || true

echo "=== Done ==="
