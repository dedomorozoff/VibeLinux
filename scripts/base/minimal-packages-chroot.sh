#!/bin/sh
set -e

echo "[chroot] Настройка sources.list..."
cat > /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main universe restricted multiverse
deb http://security.ubuntu.com/ubuntu noble-security main universe restricted multiverse
EOF

echo "[chroot] Обновление списка пакетов..."
apt-get update

echo "[chroot] Установка базовых пакетов..."
apt-get install -y --no-install-recommends \
    zstd \
    linux-image-virtual \
    casper \
    squashfs-tools \
    systemd-sysv \
    udev \
    bash \
    sudo \
    zsh \
    tmux \
    nano \
    vim-tiny \
    mc \
    htop \
    curl \
    wget \
    unzip \
    zip \
    git \
    build-essential \
    ca-certificates \
    initramfs-tools \
    fdisk \
    e2fsprogs \
    dosfstools \
    grub2-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    locales \
    console-setup \
    kbd \
    network-manager \
    network-manager-openvpn \
    iputils-ping \
    net-tools \
    traceroute \
    tree \
    p7zip-full \
    virtualbox-guest-utils \
    neofetch

# --- НАСТРОЙКА РУССКОГО ЯЗЫКА ---
echo "[chroot] Настройка локали..."
echo "ru_RU.UTF-8 UTF-8" > /etc/locale.gen
locale-gen ru_RU.UTF-8
update-locale LANG=ru_RU.UTF-8

# Настройка шрифтов для консоли
echo "[chroot] Настройка консольных шрифтов..."
cat > /etc/default/console-setup << 'EOF'
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="CyrSlav"
FONTFACE="Fixed"
FONTSIZE="16x8"
EOF

# Настройка клавиатуры (Alt+Shift для переключения)
echo "[chroot] Настройка клавиатуры..."
cat > /etc/default/keyboard << 'EOF'
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle,grp_led:scroll"
EOF

# Отключение casper-md5check (чтобы не было ошибки)
echo "[chroot] Отключение casper-md5check..."
systemctl mask casper-md5check.service 2>/dev/null || true

# Точка входа (entrypoint)
echo "[chroot] Создание entrypoint..."
cat > /usr/local/bin/entrypoint.sh << 'EOF'
#!/bin/bash
if grep -q "mode=install" /proc/cmdline; then
    /usr/local/bin/install-to-hd.sh
else
    exec /bin/bash
fi
EOF
chmod +x /usr/local/bin/entrypoint.sh

# Скрипт установки на HDD
echo "[chroot] Создание установщика..."
cat > /usr/local/bin/install-to-hd.sh << 'INSTALLER'
#!/bin/bash
clear
echo "==========================================="
echo "   UNIVERSAL INSTALLER (UEFI/BIOS)         "
echo "==========================================="

if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="BIOS"
fi

echo "Boot mode: $MODE"
echo ""
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop" | grep -v "sr"
echo ""

read -p "Enter target disk name (e.g. sda or nvme0n1): " DISK_NAME
TARGET_DISK="/dev/$DISK_NAME"

if [ ! -b "$TARGET_DISK" ]; then
    echo "Error: Disk $TARGET_DISK not found!"
    exit 1
fi

echo "!!! WARNING !!! All data on $TARGET_DISK will be destroyed!"
read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then exit 1; fi

wipefs -a "$TARGET_DISK"

if [ "$MODE" = "UEFI" ]; then
    echo "--> Partitioning GPT (UEFI)..."
    fdisk "$TARGET_DISK" << 'FDISK_GPT'
g
n
1

+512M
t
1
1
n
2


w
FDISK_GPT

    PART_EFI="${TARGET_DISK}1"
    PART_ROOT="${TARGET_DISK}2"
    if [[ "$TARGET_DISK" =~ "nvme" ]]; then
        PART_EFI="${TARGET_DISK}p1"
        PART_ROOT="${TARGET_DISK}p2"
    fi

    echo "--> Formatting EFI (vfat)..."
    mkfs.vfat -F 32 "$PART_EFI"
    echo "--> Formatting Root (ext4)..."
    mkfs.ext4 -F "$PART_ROOT"

else
    echo "--> Partitioning MBR (BIOS)..."
    fdisk "$TARGET_DISK" << 'FDISK_MBR'
o
n
p
1


w
FDISK_MBR

    PART_ROOT="${TARGET_DISK}1"
    if [[ "$TARGET_DISK" =~ "nvme" ]]; then
        PART_ROOT="${TARGET_DISK}p1"
    fi
    echo "--> Formatting Root (ext4)..."
    mkfs.ext4 -F "$PART_ROOT"
fi

echo "--> Copying OS files..."
mkdir -p /mnt/target
mount "$PART_ROOT" /mnt/target

for dir in bin etc lib lib64 root sbin usr var; do
    if [ -d "/$dir" ]; then cp -a "/$dir" /mnt/target/; fi
done

mkdir -p /mnt/target/boot /mnt/target/dev /mnt/target/proc /mnt/target/sys /mnt/target/run

if [ "$MODE" = "UEFI" ]; then
    mkdir -p /mnt/target/boot/efi
    mount "$PART_EFI" /mnt/target/boot/efi
fi

cp -a /boot/* /mnt/target/boot/ || true

mount -o bind /dev /mnt/target/dev
mount -o bind /proc /mnt/target/proc
mount -o bind /sys /mnt/target/sys

echo "--> Setting up GRUB bootloader ($MODE)..."
if [ "$MODE" = "UEFI" ]; then
    chroot /mnt/target grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck
else
    chroot /mnt/target grub-install --target=i386-pc "$TARGET_DISK"
fi

chroot /mnt/target update-grub

UUID_ROOT=$(blkid -s UUID -o value "$PART_ROOT")
echo "UUID=$UUID_ROOT / ext4 errors=remount-ro 0 1" > /mnt/target/etc/fstab

if [ "$MODE" = "UEFI" ]; then
    UUID_EFI=$(blkid -s UUID -o value "$PART_EFI")
    echo "UUID=$UUID_EFI /boot/efi vfat defaults 0 2" >> /mnt/target/etc/fstab
fi

rm -f /mnt/target/usr/local/bin/entrypoint.sh

umount -l /mnt/target

echo ""
echo "==========================================="
echo " SUCCESS! Unplug ISO and reboot the system."
echo "==========================================="
exec /bin/bash
INSTALLER
chmod +x /usr/local/bin/install-to-hd.sh

# Настройка autologin для root
echo "[chroot] Настройка autologin..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --login-program /usr/local/bin/entrypoint.sh %I $TERM
EOF

# Убираем пароль у root для автологина
echo "[chroot] Удаление пароля root..."
passwd -d root

# Очистка
echo "[chroot] Очистка кэша..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[chroot] Готово!"
