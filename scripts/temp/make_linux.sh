#!/bin/bash

set -e

WORK_DIR="$HOME/ubuntu-minimal-build"
ROOTFS="$WORK_DIR/rootfs"
ISO_DIR="$WORK_DIR/iso"
CODENAME="noble" # Ubuntu 24.04
ARCH="amd64"

echo "=== Очистка старых сборок ==="
umount -lf $ROOTFS/proc || true
umount -lf $ROOTFS/sys || true
umount -lf $ROOTFS/dev || true
rm -rf "$WORK_DIR"

mkdir -p "$ROOTFS"
mkdir -p "$ISO_DIR/boot/grub"

echo "=== 1. Развертывание базовой системы Ubuntu (Noble) ==="
debootstrap --variant=minbase --arch=$ARCH $CODENAME "$ROOTFS" http://archive.ubuntu.com/ubuntu/

echo "=== 2. Настройка системы внутри chroot ==="
mount -t proc /proc "$ROOTFS/proc"
mount -t sysfs /sys "$ROOTFS/sys"
mount -o bind /dev "$ROOTFS/dev"

cat << '_SETUP_' > "$ROOTFS/setup.sh"
#!/bin/sh
set -e

echo "deb http://archive.ubuntu.com/ubuntu noble main universe" > /etc/apt/sources.list
apt-get update

# Добавлены пакеты locales и console-setup для поддержки шрифтов и русского языка
apt-get install -y --no-install-recommends \
    zstd \
    linux-image-virtual \
    casper \
    systemd-sysv \
    udev \
    bash \
    mc \
    initramfs-tools \
    fdisk \
    e2fsprogs \
    dosfstools \
    grub2-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    locales \
    console-setup \
    kbd

# --- НАСТРОЙКА РУССКОГО ЯЗЫКА ---
echo "ru_RU.UTF-8 UTF-8" > /etc/locale.gen
locale-gen ru_RU.UTF-8
update-locale LANG=ru_RU.UTF-8

# Настройка шрифтов для консоли (чтобы не было квадратов)
cat << 'EOT' > /etc/default/console-setup
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="CyrSlav"
FONTFACE="Fixed"
FONTSIZE="16x8"
EOT

# Переключение раскладки клавиатуры: Alt+Shift
cat << 'EOT' > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle,grp_led:scroll"
EOT

# --- УДАЛЕНИЕ ОШИБКИ casper-md5check ---
systemctl mask casper-md5check.service


# Точка входа
cat << '_ENTRYPOINT_' > /usr/local/bin/entrypoint.sh
#!/bin/bash
if grep -q "mode=install" /proc/cmdline; then
    /usr/local/bin/install-to-hd.sh
else
    exec /bin/bash
fi
_ENTRYPOINT_
chmod +x /usr/local/bin/entrypoint.sh


# Скрипт Установки
cat << '_INSTALLER_' > /usr/local/bin/install-to-hd.sh
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
    
fdisk "$TARGET_DISK" << '_FDISK_GPT_'
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
_FDISK_GPT_

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

fdisk "$TARGET_DISK" << '_FDISK_MBR_'
o
n
p
1


w
_FDISK_MBR_

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
_INSTALLER_
chmod +x /usr/local/bin/install-to-hd.sh

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat << '_GETTY_' > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --login-program /usr/local/bin/entrypoint.sh %I \$TERM
_GETTY_

passwd -d root

apt-get clean
rm -rf /var/lib/apt/lists/*
_SETUP_

chmod +x "$ROOTFS/setup.sh"
chroot "$ROOTFS" /bin/bash /setup.sh
rm "$ROOTFS/setup.sh"

echo "=== 3. Подготовка ядра и initrd для ISO ==="
KERNEL_FILE=$(find "$ROOTFS/boot" -maxdepth 1 -name "vmlinuz-*" -type f | sort -V | tail -n 1)
KERNEL_VERSION=$(basename "$KERNEL_FILE" | sed 's/vmlinuz-//')

cp "$ROOTFS/boot/vmlinuz-$KERNEL_VERSION" "$ISO_DIR/boot/vmlinuz"
cp "$ROOTFS/boot/initrd.img-$KERNEL_VERSION" "$ISO_DIR/boot/initrd.img"

umount -lf "$ROOTFS/proc"
umount -lf "$ROOTFS/sys"
umount -lf "$ROOTFS/dev"

echo "=== 4. Создание SquashFS ==="
mkdir -p "$ISO_DIR/casper"
mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" -noappend -comp xz -e boot

echo "=== 5. Настройка загрузчика GRUB для ISO-образа ==="
cat << EOF > "$ISO_DIR/boot/grub/grub.cfg"
set default=0
set timeout=5

# Меню на английском, чтобы избежать проблем со шрифтами на этапе GRUB
menuentry "Run Live Ubuntu (Bash + MC)" {
    linux /boot/vmlinuz boot=casper noprompt quiet splash ---
    initrd /boot/initrd.img
}

menuentry "Install Ubuntu to Hard Drive" {
    linux /boot/vmlinuz boot=casper noprompt mode=install quiet splash ---
    initrd /boot/initrd.img
}
EOF

echo "=== 6. Создание ISO-образа ==="
grub-mkrescue -o "$WORK_DIR/minimal-ubuntu.iso" "$ISO_DIR"

echo "================================================="
echo " Готово! ISO-образ создан:"
echo " $WORK_DIR/minimal-ubuntu.iso"
echo "================================================="
