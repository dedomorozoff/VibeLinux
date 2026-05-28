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

# AI Stack scripts
# Fix npm permissions for vibe user
mkdir -p /home/vibe/.npm
chown -R vibe:vibe /home/vibe/.npm

# qwen-code (AI coding agent via npm) — ставим как root, потом фиксим права
npm install -g @qwen-code/qwen-code 2>&1 | tail -5 || echo "WARNING: qwen-code install failed"
chown -R vibe:vibe /home/vibe/.npm

# Python AI venv устанавливается post-install через:
#   sudo /opt/vibecode/scripts/ai/setup-python-ai-stack.sh

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

# Continue.dev installer
cat > /usr/local/bin/install-continue << 'CONTINUEEOF'
#!/usr/bin/env bash
echo "Installing Continue.dev for Zed..."
echo "Open Zed → Extensions → Search 'Continue' → Install"
echo "Or run: zed: extensions continue.continue"
echo "Manual install: https://docs.continue.dev/install"
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

# Unified AI installer script
cat > /usr/local/bin/ai-install << 'INSTALLEOF'
#!/usr/bin/env bash
echo "VibeLinux — AI Tool Installer"
echo "=============================="
echo ""
echo "Available tools:"
echo ""
echo "  [1] opencode      — Open source AI coding agent (pre-installed)"
echo "  [2] qwen-code     — Qwen AI coding agent (pre-installed, run 'qwen')"
echo "  [3] aider         — AI pair programming (install via setup-python-ai-stack)"
echo "  [4] Continue.dev  — AI assistant for editors (install-ext)"
echo "  [5] MCP servers   — Model Context Protocol (filesystem, github)"
echo "  [6] Cursor        — Proprietary AI IDE"
echo "  [7] Kiro          — Amazon's AI coding assistant"
echo "  [8] Claude Code   — Anthropic's terminal AI"
  echo "  [9] ai-chat       — Local Ollama chat (pre-installed)"
  echo ""
  read -rp "Install [1-9]: " choice
case "$choice" in
  1) echo "opencode is already installed. Run: opencode" ;;
  2) echo "qwen-code is already installed. Run: qwen" ;;
  3) echo "aider is pre-installed. Run: aider" ;;
  4) install-continue ;;
  5) install-mcp-servers ;;
  6) install-cursor ;;
  7) install-kiro ;;
  8) install-claude-code ;;
  9) echo "ai-chat is pre-installed. Run: ai-chat" ;;
  *) echo "Nothing to install." ;;
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
Parent=FALLBACK

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

# GRUB config for installed system
# Ensure base defaults exist
GRUB_DEFAULT_FILE="/etc/default/grub"
if [[ ! -f "$GRUB_DEFAULT_FILE" ]]; then
  cat > "$GRUB_DEFAULT_FILE" << 'GRUBBASE'
# GRUB boot loader configuration
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="VibeLinux"
GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 quiet splash"
GRUB_CMDLINE_LINUX="nvidia-drm.modeset=1"
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TERMINAL_INPUT="console"
GRUB_GFXMODE=1920x1080,auto
GRUB_GFXPAYLOAD_LINUX="keep"
GRUB_DISABLE_LINUX_UUID=true
GRUB_DISABLE_RECOVERY=true
GRUB_ENABLE_CRYPTODISK=y
GRUB_SAVEDEFAULT=true
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=y
GRUBBASE
fi

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

if [[ -f "$WALL_PNG" ]]; then
  echo 'GRUB_BACKGROUND='"$WALL_PNG" >> "$GRUB_DEFAULT_FILE"
fi

# GRUB theme — VibeLinux minimal
STARFIELD="/usr/share/grub/starfield.png"
if [[ ! -f "$STARFIELD" ]]; then
  # Создаём простой фон из PNG если есть
  if [[ -f "$WALL_PNG" ]]; then
    STARFIELD="$WALL_PNG"
  fi
fi
mkdir -p /boot/grub/themes/vibelinux
cat > /boot/grub/themes/vibelinux/theme.txt << GRUBTHEME
# VibeLinux GRUB theme
title-text: "VibeLinux"
title-color: "#4CC9F0"
title-font: "unicode"
desktop-image: "${STARFIELD}"
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
echo "  [2] Setup Rust (rustup default)"
echo "  [3] System info (fastfetch)"
echo "  [4] Skip"
echo ""
read -rp "  Choose [1-4]: " choice
case "$choice" in
  1) ai-setup ;;
  2) runuser -u vibe -- bash -c 'rustup default stable' || true ;;
  3) fastfetch ;;
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

<h2>AI Tools</h2>
<ul>
  <li><strong>opencode</strong> — <code>opencode</code> (AI coding agent)</li>
  <li><strong>qwen-code</strong> — <code>qwen</code> (Alibaba coding agent)</li>
  <li><strong>Ollama</strong> — auto-started on boot</li>
  <li><strong>nlsh</strong> — offline AI shell (model included)</li>
  <li><strong>ai-chat</strong> — terminal chat with local LLMs</li>
</ul>

<h2>Quick Commands</h2>
<pre><span class="cmd">fastfetch</span> <span class="sep">—</span> system info
<span class="cmd">btop</span>      <span class="sep">—</span> resource monitor
<span class="cmd">eza -la</span>  <span class="sep">—</span> list files
<span class="cmd">bat</span> file  <span class="sep">—</span> cat with syntax highlighting
<span class="cmd">lazygit</span>  <span class="sep">—</span> git TUI
<span class="cmd">opencode</span> <span class="sep">—</span> AI coding agent
<span class="cmd">ai-chat</span>  <span class="sep">—</span> local AI chat
<span class="cmd">ai-setup</span> <span class="sep">—</span> download AI models</pre>

<h2>First Steps</h2>
<ol>
  <li>Open <strong>Konsole</strong> (or Kitty)</li>
  <li>Run <code>ai-chat</code> to chat with local AI</li>
  <li>Run <code>opencode</code> for AI pair programming</li>
  <li>Run <code>ai-setup</code> to download more models</li>
  <li>Open <strong>Zed</strong> and start coding</li>
</ol>

</body>
</html>
EOF
chmod 644 /home/vibe/Desktop/GET-STARTED.html

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

# nlsh — Natural Language Shell (AI Shell Assistant)
echo "Installing nlsh..."
if [[ -f /root/nlsh/nlsh ]]; then
  cp /root/nlsh/nlsh /usr/local/bin/nlsh
  chmod +x /usr/local/bin/nlsh

  # Bundle small AI model for offline use (Q2_K ~200MB for weak machines)
  NLSH_MODELS_DIR="/home/vibe/.config/nlsh/models"
  mkdir -p "$NLSH_MODELS_DIR"
  
  MODEL_NAME="qwen2.5-0.5b-instruct-q2_k.gguf"
  MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q2_k.gguf"
  
  if [[ -f /root/nlsh/models/$MODEL_NAME ]]; then
    cp /root/nlsh/models/$MODEL_NAME "$NLSH_MODELS_DIR/"
    chown vibe:vibe "$NLSH_MODELS_DIR/$MODEL_NAME"
    echo "OK: bundled model Q2_K from local file"
  else
    echo "Downloading Q2_K model (~200MB)..."
    curl -L "$MODEL_URL" -o "$NLSH_MODELS_DIR/$MODEL_NAME" 2>&1 | tail -5 || \
      echo "WARNING: model download failed"
    chown vibe:vibe "$NLSH_MODELS_DIR/$MODEL_NAME" 2>/dev/null || true
  fi

  # Default config for vibe user
  NLSH_CONFIG_DIR="/home/vibe/.config/nlsh"
  mkdir -p "$NLSH_CONFIG_DIR"
  cat > "$NLSH_CONFIG_DIR/config.json" << NLSCONF
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
  chown -R vibe:vibe "$NLSH_CONFIG_DIR"

  if [[ -f /root/nlsh/nlsh.svg ]]; then
    cp /root/nlsh/nlsh.svg /usr/share/pixmaps/nlsh.svg
  fi

  cat > /home/vibe/Desktop/nlsh.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=nlsh — AI Shell Assistant
GenericName=Natural Language Shell
Comment=AI-ассистент для управления системой через естественный язык
Exec=konsole --hold -e nlsh repl
Icon=nlsh
Terminal=false
Categories=Development;Utility;AI;
Keywords=ai;llm;shell;assistant;local;
StartupNotify=false
EOF
  chmod 755 /home/vibe/Desktop/nlsh.desktop
  echo "nlsh installed with llama.cpp engine + offline model"
else
  echo "WARNING: nlsh binary not found in /root/nlsh/"
fi

# Copy desktop shortcuts to system applications so they appear in Kickoff menu
for f in /home/vibe/Desktop/*.desktop; do
  cp "$f" /usr/share/applications/
done

# KDE Kickoff Favorites
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/kickoffrc << 'EOF'
[General]
favorites=preferred://browser,org.kde.dolphin.desktop,org.kde.konsole.desktop,nlsh.desktop,AI-Chat.desktop,OpenCode.desktop,Qwen-Code.desktop,Install-AI-Tools.desktop,VibeLinux-Welcome.desktop
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
  echo "Building $pkg from AUR..."
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
    echo "$pkg installed"
  fi
}

aur_build yay-bin yay
aur_build bruno-bin bruno
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
    - initcpiocfg
    - initcpio
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
  - source: "/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
    sourcefs: "file"
    destination: "/boot/vmlinuz-linux"
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
  remove: [  ]
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
  - name: ollama
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
kernelSearchPath: "/usr/lib/modules"
kernelPattern: "^vmlinuz.*"
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

# Копируем nlsh config и model в /etc/skel
if [[ -d /home/vibe/.config/nlsh ]]; then
  mkdir -p /etc/skel/.config/nlsh
  cp -r /home/vibe/.config/nlsh/* /etc/skel/.config/nlsh/
  chown -R root:root /etc/skel/.config/nlsh
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

# Копируем nlsh model в /etc/skel для новых пользователей
if [[ -d /home/vibe/.config/nlsh/models ]]; then
  mkdir -p /etc/skel/.config/nlsh/models
  cp -r /home/vibe/.config/nlsh/models/* /etc/skel/.config/nlsh/models/
  chown -R root:root /etc/skel/.config/nlsh
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

echo "=== Done ==="
