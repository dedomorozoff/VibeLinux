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

# User
if ! id vibe &>/dev/null; then
  useradd -m -s /usr/bin/zsh vibe
  echo "vibe:vibe" | chpasswd
fi
echo "vibe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90_vibe
chmod 440 /etc/sudoers.d/90_vibe

# Services
systemctl enable NetworkManager || true
systemctl enable systemd-timesyncd || true

# Oh My Zsh (if not installed)
if [[ ! -d /home/vibe/.oh-my-zsh ]]; then
  runuser -u vibe -- bash -c 'CI=true sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' 2>/dev/null || true
fi

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  echo 'eval "$(starship init zsh)"' >> /home/vibe/.zshrc
fi

echo "=== Done ==="
