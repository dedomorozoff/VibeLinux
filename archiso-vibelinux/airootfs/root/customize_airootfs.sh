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

# KDE user defaults
mkdir -p /home/vibe/.config
cat > /home/vibe/.config/kglobalshortcutsrc << EOF
EOF

# Fix permissions
chown -R vibe:vibe /home/vibe

# Rust setup (run as user after boot)
cat >> /home/vibe/.zshrc << 'EOF'
if command -v rustup &>/dev/null && [[ ! -f "$HOME/.cargo/env" ]]; then
  rustup default stable 2>/dev/null || true
fi
EOF

echo "=== Done ==="
