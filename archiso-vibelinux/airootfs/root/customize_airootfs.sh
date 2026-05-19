#!/usr/bin/env bash
set -e

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
 __     ___  ____     ___  _     ____
 \ \   / / ||  _ \   / _ \| |   / ___|
  \ \ / /| || |_) | | | | | |   \___ \
   \ V / | ||  _ <  | |_| | |___ ___) |
    \_/  |_||_| \_\  \__\_\_____|____/

 VibeLinux — Linux для вайбкодинга и AI
EOF
fi

# OS Release (for fastfetch / lsb_release)
cat > /etc/os-release << 'EOF'
NAME="VibeLinux"
PRETTY_NAME="VibeLinux (Arch Linux based)"
ID=vibelinux
ID_LIKE=arch
VERSION=2026.04
VERSION_CODENAME=genesis
HOME_URL="https://vibelinux.org"
DOCUMENTATION_URL="https://github.com/vibelinux/docs"
SUPPORT_URL="https://github.com/vibelinux"
BUG_REPORT_URL="https://github.com/vibelinux/issues"
LOGO=/usr/share/pixmaps/vibelinux.svg
EOF

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
    Option "XkbOptions" "grp:alt_shift_toggle"
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

# Services
systemctl enable NetworkManager || true
systemctl enable systemd-timesyncd || true
systemctl enable docker || true
systemctl enable sddm || true
systemctl enable ollama || true
systemctl enable vboxservice || true
systemctl enable nvidia-persistenced || true

# NVIDIA: modprobe config for DRM modeset (fallback if kernel cmdline missing)
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia_drm modeset=1
options nvidia NVreg_EnableBacklightHandler=1
EOF

# NVIDIA: rebuild initramfs with nvidia modules
# Force-write mkinitcpio.conf (pacman may overwrite it during install)
cat > /etc/mkinitcpio.conf << 'EOF'
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm vboxguest vboxsf vboxvideo)
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf kms block filesystems keyboard fsck archiso)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-19)
EOF

if command -v mkinitcpio &>/dev/null; then
  mkinitcpio -P
fi

# SDDM autologin (X11 — для совместимости с NVIDIA)
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=vibe
Session=plasma-x11.desktop
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

# Neovim — install AstroNvim
if [[ ! -d /home/vibe/.config/nvim ]]; then
  runuser -u vibe -- bash -c 'git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim' 2>/dev/null || true
fi

# Git config
cat > /home/vibe/.gitconfig << 'EOF'
[user]
    name = VibeLinux User
    email = user@vibelinux.local
[core]
    editor = nvim
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

# AI Stack scripts
# Fix npm permissions for vibe user
mkdir -p /home/vibe/.npm
chown -R vibe:vibe /home/vibe/.npm

# qwen-code (AI coding agent via npm) — ставим как root, потом фиксим права
npm install -g @qwen-code/qwen-code 2>&1 | tail -5 || echo "WARNING: qwen-code install failed"
chown -R vibe:vibe /home/vibe/.npm

# Python AI libs (transformers + accelerate из git для Python 3.14)
# langchain — meta-package, ставится отдельно: pip install langchain-core
pip install --break-system-packages --no-cache-dir \
  torch --index-url https://download.pytorch.org/whl/cpu \
  git+https://github.com/huggingface/transformers.git \
  git+https://github.com/huggingface/accelerate.git \
  llama-index 2>&1 | tail -5 || true

cat > /usr/local/bin/ai-chat << 'AICHATEOF'
#!/usr/bin/env bash
MODEL="${AI_MODEL:-qwen2.5-coder}"
if ! command -v ollama &>/dev/null; then
  echo "Ollama not installed. Run: sudo pacman -S ollama"
  exit 1
fi
echo "VibeLinux AI Chat (model: $MODEL)"
echo "Commands: /help, /model <name>, /quit"
echo
while true; do
  read -rp "> " line
  case "$line" in
    /quit|/exit|/q) break ;;
    /help)
      echo "Commands:"
      echo "  /model <name> - change model"
      echo "  /quit         - exit"
      ;;
    /model\ *)
      MODEL="${line#/model }"
      export AI_MODEL="$MODEL"
      echo "Model: $MODEL"
      ;;
    "") continue ;;
    *) ollama run "$MODEL" "$line" ;;
  esac
done
AICHATEOF
chmod +x /usr/local/bin/ai-chat

cat > /usr/local/bin/ai-setup << 'AISETUPEOF'
#!/usr/bin/env bash
echo "Downloading base Ollama models..."
echo
for model in qwen2.5-coder:7b llama3.2:3b codellama:7b; do
  echo "-> $model"
  ollama pull "$model" 2>&1 | tail -1
  echo
done
echo "Done! Run: ai-chat"
AISETUPEOF
chmod +x /usr/local/bin/ai-setup

cat > /usr/local/bin/ai-webui << 'WEBUIEOF'
#!/usr/bin/env bash
CONTAINER="open-webui"
PORT="${AI_WEBUI_PORT:-3000}"
if ! command -v docker &>/dev/null; then
  echo "Docker not installed."
  exit 1
fi
if docker ps --format '{{.Names}}' | grep -q "$CONTAINER"; then
  echo "Open WebUI running: http://localhost:$PORT"
  exit 0
fi
if docker ps -a --format '{{.Names}}' | grep -q "$CONTAINER"; then
  docker start "$CONTAINER"
else
  docker run -d -p "$PORT":8080 \
    --add-host=host.docker.internal:host-gateway \
    -v open-webui:/app/backend/data \
    --name "$CONTAINER" \
    --restart always \
    ghcr.io/open-webui/open-webui:main
fi
echo "Open WebUI: http://localhost:$PORT"
WEBUIEOF
chmod +x /usr/local/bin/ai-webui

# Proprietary AI tool installers

# Cursor IDE installer
cat > /usr/local/bin/install-cursor << 'CURSOREOF'
#!/usr/bin/env bash
echo "Installing Cursor IDE..."
curl -L "https://downloads.cursor.com/production/$(uname -m)/appimage/Cursor.AppImage" -o /tmp/Cursor.AppImage 2>/dev/null || {
  echo "Trying alternative download..."
  wget -q "https://cursor.sh/download/linux" -O /tmp/Cursor.AppImage 2>/dev/null || true
}
if [[ -f /tmp/Cursor.AppImage ]]; then
  mkdir -p /opt/cursor
  mv /tmp/Cursor.AppImage /opt/cursor/Cursor.AppImage
  chmod +x /opt/cursor/Cursor.AppImage
  cat > /usr/share/applications/cursor.desktop << EOF
[Desktop Entry]
Name=Cursor
Exec=/opt/cursor/Cursor.AppImage --no-sandbox
Icon=utilities-terminal
Type=Application
Categories=Development;IDE;
EOF
  echo "Cursor installed: /opt/cursor/Cursor.AppImage"
else
  echo "Failed to download Cursor. Get it at: https://cursor.sh"
fi
CURSOREOF
chmod +x /usr/local/bin/install-cursor

# Amazon Kiro installer (if available)
cat > /usr/local/bin/install-kiro << 'KIROEOF'
#!/usr/bin/env bash
echo "Installing Amazon Kiro..."
if command -v npm >/dev/null; then
  npm install -g @amazon/kiro 2>/dev/null && echo "Kiro installed via npm" || {
    echo "Kiro package not found on npm. Check: https://kiro.dev"
    echo "Alternative: install from official site"
  }
else
  echo "npm not found. Install Node.js first."
fi
KIROEOF
chmod +x /usr/local/bin/install-kiro

# Claude Code installer
cat > /usr/local/bin/install-claude-code << 'CLAUDEEOF'
#!/usr/bin/env bash
echo "Installing Claude Code..."
if command -v npm >/dev/null; then
  npm install -g @anthropic-ai/claude-code 2>/dev/null && echo "Claude Code installed" || {
    echo "Failed to install Claude Code. Check: https://claude.ai/code"
  }
else
  echo "npm not found. Install Node.js first."
fi
CLAUDEEOF
chmod +x /usr/local/bin/install-claude-code

# Unified AI installer script
cat > /usr/local/bin/ai-install << 'INSTALLEOF'
#!/usr/bin/env bash
echo "VibeLinux — AI Tool Installer"
echo "=============================="
echo ""
echo "Available tools:"
echo ""
echo "  [1] opencode   — Open source AI coding agent (pre-installed)"
echo "  [2] qwen-code  — Qwen AI coding agent (pre-installed, run 'qwen')"
echo "  [3] Cursor     — Proprietary AI IDE"
echo "  [4] Kiro       — Amazon's AI coding assistant"
echo "  [5] Claude Code — Anthropic's terminal AI"
echo "  [6] ai-chat    — Local Ollama chat (pre-installed)"
echo "  [7] ai-webui   — Open WebUI via Docker (pre-installed script)"
echo ""
read -rp "Install [1-7]: " choice
case "$choice" in
  1) echo "opencode is already installed. Run: opencode" ;;
  2) echo "qwen-code is already installed. Run: qwen" ;;
  3) install-cursor ;;
  4) install-kiro ;;
  5) install-claude-code ;;
  6) echo "ai-chat is pre-installed. Run: ai-chat" ;;
  7) ai-webui ;;
  *) echo "Nothing to install." ;;
esac
INSTALLEOF
chmod +x /usr/local/bin/ai-install

# === BRANDING ===

# ASCII logo для fastfetch
if [[ -f /root/branding/logos/ascii-logo.txt ]]; then
  mkdir -p /usr/share/vibelinux
  cp /root/branding/logos/ascii-logo.txt /usr/share/vibelinux/ascii-logo.txt
fi

# Wallpapers — copy to system location
mkdir -p /usr/share/wallpapers/VibeLinux/contents/images
if [[ -f /root/branding/wallpapers/vibecode-dark.svg ]]; then
  cp /root/branding/wallpapers/vibecode-dark.svg /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
fi

# System logo — SVG в hicolor icons
if [[ -f /root/branding/logos/vibecodeos-logo.svg ]]; then
  mkdir -p /usr/share/icons/hicolor/scalable/apps
  cp /root/branding/logos/vibecodeos-logo.svg /usr/share/icons/hicolor/scalable/apps/vibelinux.svg
  # Также кладём в pixmaps для совместимости
  cp /root/branding/logos/vibecodeos-logo.svg /usr/share/pixmaps/vibelinux.svg
fi

# Генерируем PNG-лого для Calamares
if [[ -f /root/branding/logos/vibecodeos-logo.svg ]]; then
  if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 256 -h 256 /root/branding/logos/vibecodeos-logo.svg -o /tmp/vibelinux-logo.png 2>/dev/null || true
  elif command -v convert &>/dev/null; then
    convert -background none -size 256x256 /root/branding/logos/vibecodeos-logo.svg /tmp/vibelinux-logo.png 2>/dev/null || true
  fi
  if [[ -f /tmp/vibelinux-logo.png ]]; then
    cp /tmp/vibelinux-logo.png /usr/share/pixmaps/vibelinux.png
  fi
fi

# Set default wallpaper via KDE system config
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc << EOF
[Containments][1]
ItemGeometries-1920x1080=
wallpaperplugin=org.kde.image
wallpaperpluginmode=SingleImage

[Containments][1][Wallpaper][org.kde.image][General]
Image=/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
EOF

# KDE globals — dark theme
cat > /home/vibe/.config/kdeglobals << EOF
[General]
ColorScheme=BreezeDark
Name=VibeLinux

[KDE]
widgetStyle=Breeze

[Colors:Window]
BackgroundNormal=11,16,32
ForegroundNormal=255,255,255
EOF

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
Font=JetBrainsMono Nerd Font,12,-1,5,500,0,0,0,0,0,Regular

[General]
Name=VibeLinux
Parent=FALLBACK/

[TerminalFeatures]
HorizontalScrollbar=false
EOF

# Set Konsole as default terminal
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/konsolerc << EOF
[Desktop Entry]
DefaultProfile=VibeLinux.profile
EOF

# SDDM wallpaper + theme + logo
mkdir -p /usr/share/sddm/themes/breeze
cat > /usr/share/sddm/themes/breeze/theme.conf.user << EOF
[General]
background=/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
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

# GRUB — VibeLinux branding (PNG, because GRUB doesn't support SVG)
if [[ -f /root/branding/wallpapers/vibecode-dark.png ]]; then
  cp /root/branding/wallpapers/vibecode-dark.png /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png
  cat >> /etc/default/grub << 'EOF'

# VibeLinux branding
GRUB_BACKGROUND=/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.png
GRUB_GFXMODE=1920x1080,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_THEME=
EOF
  # Remove default GRUB_THEME line if arch added one
  sed -i 's/^GRUB_THEME=.*/#GRUB_THEME=/' /etc/default/grub 2>/dev/null || true
fi

# Welcome App
cat > /usr/local/bin/vibe-welcome << 'WELCOMEEOF'
#!/usr/bin/env bash
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
echo "  [1] Download AI models (ollama pull)"
echo "  [2] Start Open WebUI (Docker)"
echo "  [3] Setup Rust (rustup default)"
echo "  [4] System info (fastfetch)"
echo "  [5] Skip"
echo ""
read -rp "  Choose [1-5]: " choice
case "$choice" in
  1) ai-setup ;;
  2) ai-webui ;;
  3) runuser -u vibe -- bash -c 'rustup default stable' || true ;;
  4) fastfetch ;;
  *) echo "  Happy coding!"; exit 0 ;;
esac
WELCOMEEOF
chmod +x /usr/local/bin/vibe-welcome

# Autostart Welcome App (first run only)
mkdir -p /home/vibe/.config/autostart
cat > /home/vibe/.config/autostart/vibe-welcome.desktop << EOF
[Desktop Entry]
Type=Application
Name=VibeLinux Welcome
Exec=/usr/local/bin/vibe-welcome
Terminal=true
X-GNOME-Autostart-enabled=true
EOF

# Welcome App shortcut on desktop
mkdir -p /home/vibe/Desktop
cat > /home/vibe/Desktop/VibeLinux-Welcome.desktop << EOF
[Desktop Entry]
Type=Application
Name=VibeLinux Welcome
Icon=utilities-terminal
Exec=konsole --hold -e vibe-welcome
Terminal=false
Categories=System;
EOF
chmod 755 /home/vibe/Desktop/VibeLinux-Welcome.desktop

# Rust setup hint
cat >> /home/vibe/.zshrc << 'EOF'
if command -v rustup &>/dev/null && [[ ! -f "$HOME/.cargo/env" ]]; then
  rustup default stable 2>/dev/null || true
fi
EOF

# Fix permissions
chown -R vibe:vibe /home/vibe

# Quick Start Guide
cat > /home/vibe/Desktop/GET-STARTED.md << 'EOF'
# Welcome to VibeLinux

A Linux distro for **vibe coding** and **AI development** — everything works out of the box.

## What is here

### Terminal & Shell
- **Konsole** — default terminal (Zsh + Starship prompt)
- **Kitty** — GPU-accelerated terminal (run `kitty`)
- **CLI tools:** `eza`, `bat`, `fd`, `rg`, `fzf`, `zoxide`, `btop`

### Languages & Version Managers
- **Python** — `pyenv` for version management (`pyenv install 3.12`)
- **Node.js** — `nvm` (`nvm install --lts`)
- **Rust** — `rustup default stable`
- **Go** — pre-installed (`go version`)

### Editors
- **VS Code** — pre-installed (`code`)
- **Zed** — ultra-fast editor (`zed`)
- **Neovim** — with AstroNvim config (`nvim`)
- **Kate** — KDE text editor (`kate`)

### Git
- `git` + `lazygit` (TUI, run `lazygit`)

### Languages
- **Python** — `pyenv` for version management (`pyenv install 3.12`)
- **Node.js** — `nvm` (`nvm install --lts`)
- **Rust** — `rustup default stable`
- **Go** — pre-installed (`go version`)
- **PHP** — pre-installed (`php --version`)

### GUI Apps
- **Pinta** — lightweight image editor (`pinta`)
- **Bruno** — API client for REST/GraphQL (`bruno`)

### Containers
- **Docker** — already running (`docker ps`)

### AI Tools (open source)
- **opencode** — open source AI coding agent (`opencode`)
- **qwen-code** — Qwen's AI coding agent (`qwen`)
- **Ollama** — local LLMs (auto-started)
- **ai-chat** — terminal chat with local models (`ai-chat`)
- **ai-webui** — Open WebUI via Docker (`ai-webui` → http://localhost:3000)
- **torch, transformers, accelerate** — pre-installed via pip
- **langchain** — install: `pip install langchain-core`

### AI Tools (proprietary, install on demand)
- **Cursor** — `install-cursor` (AI IDE)
- **Kiro** — `install-kiro` (Amazon's AI assistant)
- **Claude Code** — `install-claude-code` (Anthropic terminal AI)

Run `ai-install` for a menu to install proprietary tools.

## Quick Commands
```
fastfetch     — system info
btop          — resource monitor
eza -la       — list files (replaces ls)
bat file      — cat with syntax highlighting
fd pattern    — fast file search
rg pattern    — fast text search
lazygit       — git TUI
opencode      — AI coding agent (TUI)
qwen          — Qwen AI coding agent
ai-chat       — local AI chat (Ollama)
ai-install    — install AI tools menu
ai-setup      — download AI models
```

## First Steps
1. Run `ai-setup` to download AI models
2. Run `opencode` for AI coding in terminal
3. Run `rustup default stable` for Rust
4. Run `pyenv install 3.12` for Python
5. Run `nvm install --lts` for Node.js
EOF
chmod 644 /home/vibe/Desktop/GET-STARTED.md

# Desktop shortcuts for key apps
cat > /home/vibe/Desktop/AI-Chat.desktop << EOF
[Desktop Entry]
Type=Application
Name=AI Chat
Icon=utilities-terminal
Exec=konsole --hold -e ai-chat
Terminal=false
Categories=Development;
EOF
chmod 755 /home/vibe/Desktop/AI-Chat.desktop

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

cat > /home/vibe/Desktop/Qwen-Code.desktop << EOF
[Desktop Entry]
Type=Application
Name=Qwen Code
Icon=utilities-terminal
Exec=konsole --hold -e qwen
Terminal=false
Categories=Development;
EOF
chmod 755 /home/vibe/Desktop/Qwen-Code.desktop

cat > /home/vibe/Desktop/Open-WebUI.desktop << EOF
[Desktop Entry]
Type=Application
Name=Open WebUI
Icon=firefox
Exec=ai-webui
Terminal=false
Categories=Development;
EOF
chmod 755 /home/vibe/Desktop/Open-WebUI.desktop

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

# VS Code — desktop shortcut (copy from package .desktop)
if [[ -f /usr/share/applications/code-oss.desktop ]]; then
  cp /usr/share/applications/code-oss.desktop /home/vibe/Desktop/VS-Code.desktop
  chmod 755 /home/vibe/Desktop/VS-Code.desktop
fi

# Zed — desktop shortcut (copy from package .desktop)
if [[ -f /usr/share/applications/dev.zed.Zed.desktop ]]; then
  cp /usr/share/applications/dev.zed.Zed.desktop /home/vibe/Desktop/Zed.desktop
  chmod 755 /home/vibe/Desktop/Zed.desktop
fi

# === AUR packages ===
echo "Installing AUR packages..."
if ! id builder &>/dev/null; then
  useradd -m builder
fi
# builder needs sudo for makepkg to install dependencies
echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-builder
mkdir -p /tmp/aur-build
chown builder:builder /tmp/aur-build

aur_build() {
  local pkg=$1 dir=$2
  echo "Building $pkg from AUR..."
  runuser -u builder -- bash -c "
    cd /tmp/aur-build
    rm -rf $dir
    git clone --depth 1 https://aur.archlinux.org/$pkg.git $dir 2>/dev/null
    cd $dir
    makepkg --noconfirm --skippgpcheck
  " 2>&1 | tail -5 || echo "WARNING: $pkg build failed"
  local pkg_file
  pkg_file=$(ls /tmp/aur-build/$dir/*.pkg.tar.zst 2>/dev/null | head -1)
  if [[ -n "$pkg_file" && -f "$pkg_file" ]]; then
    pacman -U --noconfirm "$pkg_file" 2>/dev/null || bsdtar -xpf "$pkg_file" -C /
    echo "$pkg installed"
  fi
}

aur_build yay-bin yay
aur_build bruno-bin bruno
aur_build pinta-appimage pinta
aur_build calamares calamares

rm -f /etc/sudoers.d/90-builder
userdel builder 2>/dev/null || true
rm -rf /tmp/aur-build

# Calamares — конфигурация для VibeLinux
mkdir -p /etc/calamares
cat > /etc/calamares/settings.conf << 'CALCONF'
---
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
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    - displaymanager
    - networkcfg
    - hwclock
    - services-systemd
    - bootloader
    - umount
  - show:
    - finished
prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: true
CALCONF

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

# Копируем обои в /etc/skel
mkdir -p /etc/skel/.config
if [[ -f /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc ]]; then
  cp /home/vibe/.config/plasma-org.kde.plasma.desktop-appletsrc /etc/skel/.config/
fi
if [[ -f /home/vibe/.config/kdeglobals ]]; then
  cp /home/vibe/.config/kdeglobals /etc/skel/.config/
fi
if [[ -f /home/vibe/.config/konsolerc ]]; then
  cp /home/vibe/.config/konsolerc /etc/skel/.config/
fi

# Копируем Konsole theme
if [[ -d /home/vibe/.local/share/konsole ]]; then
  mkdir -p /etc/skel/.local/share/konsole
  cp -r /home/vibe/.local/share/konsole/* /etc/skel/.local/share/konsole/
fi

chown -R root:root /etc/skel

# Убеждаемся что calamares можно запускать через sudo без пароля для пользователя vibe
if ! grep -q 'calamares' /etc/sudoers.d/90_vibe 2>/dev/null; then
  echo "vibe ALL=(ALL) NOPASSWD: /usr/bin/calamares" >> /etc/sudoers.d/90_vibe
fi

chown -R vibe:vibe /home/vibe

echo "=== Done ==="
