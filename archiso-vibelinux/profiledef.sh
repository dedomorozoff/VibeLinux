#!/usr/bin/env bash
# VibeLinux archiso profile

iso_name="vibelinux"
iso_label="VIBELINUX_ARCH"
iso_publisher="VibeLinux <https://vibelinux.org>"
iso_application="VibeLinux Live/Install DVD"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd -15: balance скорости сборки и размера. -19 на 11 ГБ rootfs
# занимает часы на слабом CPU и почти не уменьшает размер.
# NB: -b 1M пробовали — mksquashfs зависал на 4-ядерной машине с 8 ГБ RAM.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
)
