#!/usr/bin/env bash
# VibeLinux Minimal archiso profile — CLI-only live image

iso_name="vibelinux-mini"
iso_label="VIBELINUX_MINI"
iso_publisher="VibeLinux <https://vibelinux.org>"
iso_application="VibeLinux Minimal Live DVD"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/usr/local/bin/vinstall"]="0:0:755"
)
