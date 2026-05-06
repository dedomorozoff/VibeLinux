#!/bin/bash
set -e

# Скрипт настройки Full версии VibeCode OS в chroot
# Включает: MATE Desktop, терминалы, dev-инструменты, AI-стек

echo "[full-chroot] Настройка sources.list..."
cat > /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main universe restricted multiverse
deb http://security.ubuntu.com/ubuntu noble-security main universe restricted multiverse
EOF

echo "[full-chroot] Обновление списка пакетов..."
apt-get update

# === БАЗОВАЯ СИСТЕМА ===
echo "[full-chroot] Установка базовой системы..."
apt-get install -y \
    linux-image-virtual \
    linux-headers-virtual \
    casper \
    squashfs-tools \
    systemd-sysv \
    udev \
    initramfs-tools \
    sudo \
    locales \
    console-setup \
    kbd

# === MATE DESKTOP ===
echo "[full-chroot] Установка MATE Desktop..."
apt-get install -y \
    ubuntu-mate-desktop \
    lightdm \
    lightdm-gtk-greeter \
    mate-tweak \
    marco \
    compiz-mate \
    mate-terminal \
    caja \
    eom \
    atril \
    engrampa \
    pluma \
    mate-system-monitor \
    mate-control-center \
    mate-panel \
    mate-menu \
    mate-notification-daemon \
    mate-screensaver \
    mate-power-manager \
    network-manager \
    network-manager-gnome \
    gnome-disk-utility \
    seahorse \
    file-roller \
    avahi-daemon \
    avahi-discover \
    libnss-mdns

# === ТЕРМИНАЛ И ОБОЛОЧКА ===
echo "[full-chroot] Установка Kitty и Zsh..."
apt-get install -y \
    kitty \
    zsh \
    oh-my-zsh \
    fonts-powerline

# Starship (промпт)
apt-get install -y curl
curl -sS https://starship.rs/install.sh | sh -s -- -y

# CLI утилиты
apt-get install -y \
    eza \
    bat \
    fd-find \
    ripgrep \
    fzf \
    zoxide \
    btop \
    jq \
    yq

# === ШРИФТЫ ===
echo "[full-chroot] Установка шрифтов..."
apt-get install -y \
    fonts-jetbrains-mono \
    fonts-firacode \
    fonts-cascadia-code \
    fonts-hack \
    fonts-dejavu \
    fonts-noto-color-emoji

# === ЯЗЫКИ ПРОГРАММИРОВАНИЯ ===
echo "[full-chroot] Установка языков программирования..."

# Python
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# Node.js (через nvm будет установлен позже)
apt-get install -y \
    nodejs \
    npm

# Go
apt-get install -y golang-go

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Java (OpenJDK)
apt-get install -y \
    openjdk-17-jdk \
    openjdk-17-jre

# PHP
apt-get install -y \
    php \
    php-cli \
    php-common \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \
    php-sqlite3 \
    php-mysql \
    php-pgsql \
    php-json \
    php-intl \
    php-bcmath

# === РЕДАКТОРЫ ===
echo "[full-chroot] Установка редакторов..."

# VSCodium
curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/vscodium.gpg
echo 'deb https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs vscodium main' > /etc/apt/sources.list.d/vscodium.list
apt-get update
apt-get install -y codium

# Neovim
apt-get install -y neovim

# Zed — быстрый современный редактор (официальный скрипт установки)
echo "[full-chroot] Установка Zed..."
if curl -sf --connect-timeout 5 https://zed.dev >/dev/null 2>&1; then
  curl -f https://zed.dev/install.sh 2>/dev/null | sh || echo "[full-chroot] WARNING: Zed install failed"
else
  echo "[full-chroot] Пропуск Zed — нет сети"
fi

# VS Code — проприетарный редактор от Microsoft (опционально, для Full)
echo "[full-chroot] Установка VS Code..."
if curl -sf --connect-timeout 5 https://packages.microsoft.com >/dev/null 2>&1; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
  apt-get update
  apt-get install -y code || echo "[full-chroot] WARNING: VS Code install failed"
else
  echo "[full-chroot] Пропуск VS Code — нет сети"
fi

# === GIT И DEVTOOLS ===
echo "[full-chroot] Установка Git и инструментов..."
apt-get install -y \
    git \
    git-lfs \
    tig \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libsqlite3-dev \
    libreadline-dev \
    libbz2-dev \
    liblzma-dev \
    libncursesw5-dev \
    zlib1g-dev

# Docker
apt-get install -y \
    docker.io \
    docker-compose \
    docker-compose-v2

# === AI-СТЕК ===
echo "[full-chroot] Установка AI-инструментов..."

# Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Python AI библиотеки
python3 -m venv /opt/venv-ai
source /opt/venv-ai/bin/activate
pip install --upgrade pip
pip install \
    torch \
    torchvision \
    torchaudio \
    transformers \
    accelerate \
    langchain \
    langchain-community \
    llama-index \
    ollama \
    numpy \
    pandas \
    matplotlib \
    jupyter
deactivate

# === ДОПОЛНИТЕЛЬНЫЕ УТИЛИТЫ ===
echo "[full-chroot] Установка дополнительных утилит..."
apt-get install -y \
    htop \
    neofetch \
    curl \
    wget \
    unzip \
    zip \
    p7zip-full \
    rar \
    tree \
    mc \
    tmux \
    vim \
    nano \
    net-tools \
    iputils-ping \
    traceroute \
    speedtest-cli \
   htop \
    ncdu \
    lsof \
    strace \
    ltrace

# VirtualBox guest
apt-get install -y \
    virtualbox-guest-utils \
    virtualbox-guest-x11 \
    virtualbox-guest-dkms

# Firefox
apt-get install -y firefox

# Pinta — графический редактор
apt-get install -y pinta

# SQLite3 CLI + DB Browser for SQLite (лёгкий GUI для БД)
apt-get install -y sqlite3 sqlitebrowser

# Bruno — API-клиент (альтернатива Postman)
echo "[full-chroot] Установка Bruno..."
if curl -sf --connect-timeout 5 https://api.github.com >/dev/null 2>&1; then
  BRUNO_DEB=$(curl -sL "https://api.github.com/repos/usebruno/bruno/releases/latest" | grep -oP '"browser_download_url": "\K[^"]*amd64\.deb' | head -1)
  if [[ -n "$BRUNO_DEB" ]]; then
    curl -sL "$BRUNO_DEB" -o /tmp/bruno.deb
    apt-get install -y /tmp/bruno.deb || echo "[full-chroot] WARNING: Bruno install failed"
    rm -f /tmp/bruno.deb
  else
    echo "[full-chroot] WARNING: Bruno .deb not found in latest release"
  fi
else
  echo "[full-chroot] Пропуск Bruno — нет сети"
fi

# === НАСТРОЙКА ЛОКАЛИ ===
echo "[full-chroot] Настройка локали..."
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen ru_RU.UTF-8
update-locale LANG=ru_RU.UTF-8

# Настройка клавиатуры
cat > /etc/default/keyboard << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle,grp_led:scroll"
EOF

# === НАСТРОЙКА ПОЛЬЗОВАТЕЛЯ ===
echo "[full-chroot] Создание пользователя vibecode..."
useradd -m -s /bin/bash vibecode
echo "vibecode:vibecode" | chpasswd
usermod -aG sudo vibecode
usermod -aG docker vibecode

# Копирование конфигов для vibecode
cp -r /root/.config /home/vibecode/ 2>/dev/null || true
chown -R vibecode:vibecode /home/vibecode

# === НАСТРОЙКА LIGHTDM ===
echo "[full-chroot] Настройка LightDM..."
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=vibecode
autologin-user-timeout=0
autologin-guest=false
allow-guest=false
greeter-session=lightdm-gtk-greeter
user-session=mate
EOF

# === НАСТРОЙКА CASPER ===
echo "[full-chroot] Настройка casper для live-образа..."
mkdir -p /etc/initramfs-tools/conf.d
cat > /etc/initramfs-tools/conf.d/casper.conf << 'EOF'
BOOT=casper
CASPERFLAGS="noprompt quiet"
EOF

cat >> /etc/initramfs-tools/modules << 'EOF'
overlay
squashfs
loop
aufs
sr_mod
cdrom
EOF

# === БРЕНДИНГ ===
echo "[full-chroot] Применение брендинга..."
if [[ -d /root/branding ]]; then
    cp -r /root/branding/* /usr/local/ 2>/dev/null || true
fi

# === ОЧИСТКА ===
echo "[full-chroot] Очистка..."
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*

echo "[full-chroot] Готово!"
