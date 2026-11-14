#!/usr/bin/env bash
iso_name="igorcoin-qortal-os"
iso_label="IGORCOIN_QORTAL"
iso_publisher="IgorCoin-Qortal OS"
iso_application="IgorCoin-Qortal Live System"
iso_version="0.1.1"
install_dir="arch"
buildmodes=('iso')
# GRUB provides a readable green UEFI boot menu; Syslinux remains for legacy BIOS.
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '10')
file_permissions=(
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/etc/sudoers.d/99-liveuser"]="0:0:440"
)
