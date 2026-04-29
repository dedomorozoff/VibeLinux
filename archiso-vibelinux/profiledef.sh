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
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
)
