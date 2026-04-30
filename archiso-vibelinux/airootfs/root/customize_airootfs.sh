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

# MOTD
cat > /etc/motd << 'EOF'
 __     ___  ____     ___  _     ____
 \ \   / / ||  _ \   / _ \| |   / ___|
  \ \ / /| || |_) | | | | | |   \___ \
   \ V / | ||  _ <  | |_| | |___ ___) |
    \_/  |_||_| \_\  \__\_\_____|____/

 VibeLinux — Linux for vibe coding & AI development
EOF

# OS Release (for fastfetch / lsb_release)
cat > /etc/os-release << 'EOF'
NAME="VibeLinux"
PRETTY_NAME="VibeLinux (Arch Linux based)"
ID=vibelinux
ID_LIKE=arch
VERSION=2026.04
VERSION_CODENAME=genesis
ANSI_COLOR="0;36"
HOME_URL="https://vibelinux.org"
DOCUMENTATION_URL="https://github.com/vibelinux/docs"
SUPPORT_URL="https://github.com/vibelinux"
BUG_REPORT_URL="https://github.com/vibelinux/issues"
LOGO=vibelinux
EOF

# Fastfetch config
mkdir -p /home/vibe/.config/fastfetch
cat > /home/vibe/.config/fastfetch/config.jsonc << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/config.schema.jsonc",
  "logo": {
    "type": "small",
    "padding": {
      "top": 0,
      "bottom": 0,
      "left": 2,
      "right": 2
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
echo "LANG=en_US.UTF-8" > /etc/locale.conf

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

# SDDM autologin
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=vibe
Session=plasma.desktop
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
pip install --break-system-packages --no-cache-dir \
  aider-chat \
  torch --index-url https://download.pytorch.org/whl/cpu \
  transformers \
  accelerate \
  langchain \
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

# === BRANDING ===

# Wallpapers — copy to system location
mkdir -p /usr/share/wallpapers/VibeLinux/contents/images
if [[ -f /root/branding/wallpapers/vibecode-dark.svg ]]; then
  cp /root/branding/wallpapers/vibecode-dark.svg /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
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

# SDDM wallpaper
mkdir -p /usr/share/sddm/themes/breeze
cat > /usr/share/sddm/themes/breeze/theme.conf.user << EOF
[General]
background=/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
EOF

# Welcome App
cat > /usr/local/bin/vibe-welcome << 'WELCOMEEOF'
#!/usr/bin/env bash
clear
cat << 'ASCII'
 __     ___  ____     ___  _     ____
 \ \   / / ||  _ \   / _ \| |   / ___|
  \ \ / /| || |_) | | | | | |   \___ \
   \ V / | ||  _ <  | |_| | |___ ___) |
    \_/  |_||_| \_\  \__\_\_____|____/

ASCII
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
- **VSCodium** — open-source VS Code (Applications → Programming)
- **Neovim** — with AstroNvim config (`nvim`)
- **Kate** — KDE text editor (`kate`)
- **Zed** — fast modern editor (`zed`)

### Git
- `git` + `lazygit` (TUI, run `lazygit`)

### Containers
- **Docker** — already running (`docker ps`)

### AI Tools
- **Ollama** — local LLMs (auto-started)
- **ai-chat** — terminal chat (`ai-chat`)
- **ai-setup** — download models (`ai-setup`)
- **ai-webui** — Open WebUI via Docker (`ai-webui` → http://localhost:3000)

## Quick Commands
```
fastfetch     — system info
btop          — resource monitor
eza -la       — list files (replaces ls)
bat file      — cat with syntax highlighting
fd pattern    — fast file search
rg pattern    — fast text search
lazygit       — git TUI
ai-chat       — AI chat in terminal
ai-setup      — download AI models
```

## First Steps
1. Run `ai-setup` to download AI models
2. Run `rustup default stable` for Rust
3. Run `pyenv install 3.12` for Python
4. Run `nvm install --lts` for Node.js
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

# VSCodium shortcut
cat > /home/vibe/Desktop/VSCodium.desktop << EOF
[Desktop Entry]
Type=Application
Name=VSCodium
Icon=vscodium
Exec=/usr/bin/codium
Terminal=false
Categories=Development;IDE;
EOF
chmod 755 /home/vibe/Desktop/VSCodium.desktop

chown -R vibe:vibe /home/vibe

echo "=== Done ==="
