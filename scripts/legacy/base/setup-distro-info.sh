#!/usr/bin/env bash
set -euo pipefail

# Скрипт настройки информации о дистрибутиве VibeCode OS

if [[ $EUID -ne 0 ]]; then
  echo "Пожалуйста, запустите этот скрипт с sudo или от root."
  exit 1
fi

echo "[distro-info] Настройка информации о дистрибутиве..."

# Создаём /etc/lsb-release
cat > /etc/lsb-release << 'EOF'
DISTRIB_ID=VibeCodeOS
DISTRIB_RELEASE=alpha
DISTRIB_CODENAME=vibecode
DISTRIB_DESCRIPTION="VibeCode OS alpha"
EOF

# Создаём /etc/os-release
cat > /etc/os-release << 'EOF'
NAME="VibeCode OS"
VERSION="alpha"
ID=vibecodeos
ID_LIKE=ubuntu
PRETTY_NAME="VibeCode OS alpha"
VERSION_ID="alpha"
HOME_URL="https://github.com/yourusername/vibecodeos"
SUPPORT_URL="https://github.com/yourusername/vibecodeos/issues"
BUG_REPORT_URL="https://github.com/yourusername/vibecodeos/issues"
PRIVACY_POLICY_URL="https://github.com/yourusername/vibecodeos"
VERSION_CODENAME=vibecode
UBUNTU_CODENAME=noble
EOF

# Создаём /etc/issue
cat > /etc/issue << 'EOF'
VibeCode OS alpha \n \l

EOF

# Создаём /etc/issue.net
cat > /etc/issue.net << 'EOF'
VibeCode OS alpha
EOF

# Обновляем hostname
echo "vibecodeos" > /etc/hostname

# Обновляем /etc/hosts
cat > /etc/hosts << 'EOF'
127.0.0.1       localhost
127.0.1.1       vibecodeos

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

echo "[distro-info] Информация о дистрибутиве настроена."
