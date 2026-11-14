# IgorCoin-Qortal OS — Archiso profile

This Arch Linux/Archiso implementation is isolated beside the existing Debian project; it does not replace the Debian build.

## Target and versions
- x86_64 Live ISO; UEFI and BIOS boot profile.
- Arch `linux` and `linux-headers`; the build aborts unless the official package version is 7.3.4.x.
- KDE Plasma from Arch's rolling `plasma` group.
- Calamares is built from the Arch User Repository (AUR); inspect its PKGBUILD before production use.
- AMD: amdgpu + Mesa/Vulkan. NVIDIA: nvidia-open-dkms + matching headers. Test DKMS and Secure Boot on actual hardware.

## Build on Linux Mint
```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
bash ./archiso/build.sh
```
The script builds inside a privileged Arch container. It does not install Arch packages on Mint. Privileged containers have broad access to the host kernel; use only with trusted source.

Output: `archiso/out/igorcoin-qortal-os-x86_64.iso`.

## GitHub Actions
Actions → **Build IgorCoin-Qortal OS (Archiso)** → Run workflow. The ISO and SHA256 file are uploaded as a 90-day artifact. Set `release_tag` to publish a GitHub Release. ISO binaries are not committed.

## QEMU
```bash
qemu-system-x86_64 -enable-kvm -m 8192 -smp 4 -cdrom archiso/out/igorcoin-qortal-os-x86_64.iso -boot d
```
Use OVMF for UEFI. QEMU cannot validate physical hybrid graphics, Wi-Fi, Bluetooth, suspend/resume or LoRa devices.

## Installer
The profile uses Calamares' `unpackfs` module to deploy the Archiso squashfs, then configures machine-id, fstab, initramfs, users, SDDM and GRUB. The squashfs path and module behavior must be verified against the actual Archiso build. This installer is experimental until UEFI/GPT, ext4, Btrfs, account creation and first boot pass in a disposable VM. Btrfs subvolumes must be tested separately.

## Decentralized stack
Qortal Core and Hub are retrieved from official GitHub latest-release APIs during image creation. For reproducible releases, pin versions and verify checksums. RNS and NomadNet use an isolated Python venv. Reticulum MeshChat is downloaded as its official Linux AppImage from the upstream GitHub release API and gets a desktop launcher.

## Security
The live account `liveuser` has passwordless sudo for the live session. Qortal and Reticulum run as separate unprivileged accounts. DNS defaults to Cloudflare with Quad9 fallback. No wallet, seed phrase or private key is embedded.

## Status
This is committed build configuration, not a claim that the ISO has already been built or hardware-tested. Review AUR build recipes and release assets; inspect Actions logs and test the artifact before calling a release stable.
