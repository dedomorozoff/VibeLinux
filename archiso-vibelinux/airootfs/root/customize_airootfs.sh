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
  useradd -m -G wheel -s /usr/bin/zsh vibe
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

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  echo 'eval "$(starship init zsh)"' >> /home/vibe/.zshrc
fi

# AI Stack scripts
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

# Branding — wallpapers
mkdir -p /usr/share/wallpapers/VibeLinux/contents/images
if [[ -f /root/branding/wallpapers/vibecode-dark.svg ]]; then
  cp /root/branding/wallpapers/vibecode-dark.svg /usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
fi

# SDDM theme config
mkdir -p /usr/share/sddm/themes/breeze
cat > /usr/share/sddm/themes/breeze/theme.conf.user << EOF
[General]
background=/usr/share/wallpapers/VibeLinux/contents/images/2560x1440.svg
EOF

# KDE user defaults
mkdir -p /home/vibe/.config

cat > /home/vibe/.config/kdeglobals << EOF
[General]
ColorScheme=BreezeDark

[Colors:Window]
BackgroundNormal=11,16,32
ForegroundNormal=255,255,255
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

# Rust setup hint
cat >> /home/vibe/.zshrc << 'EOF'
if command -v rustup &>/dev/null && [[ ! -f "$HOME/.cargo/env" ]]; then
  rustup default stable 2>/dev/null || true
fi
EOF

# Fix permissions
chown -R vibe:vibe /home/vibe

echo "=== Done ==="
