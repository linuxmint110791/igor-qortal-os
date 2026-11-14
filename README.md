# IgorCoin-Qortal OS

**IgorCoin-Qortal OS** is an experimental x86_64 Linux distribution built from the official Arch Linux repositories and the official Archiso `releng` profile.

## Download

**[Download IgorCoin-Qortal OS — official GitHub Releases](https://github.com/linuxmint110791/igor-qortal-os/releases/latest)**

A successful GitHub Actions build also publishes an `IgorCoin-Qortal-OS-amd64` workflow artifact containing the ISO, its SHA-256 checksum, and a compressed copy. Workflow artifacts are temporary (90-day retention); published Releases are the permanent download location.

GitHub limits each individual release asset to less than 2 GB. If the compressed ISO fits, download `amd.iso.zst` and `amd.iso.sha256`. Decompress and verify:

```bash
zstd -d amd.iso.zst -o amd.iso
sha256sum --check amd.iso.sha256
```

If the compressed image is too large, the Release contains numbered `amd.iso.zst.part-*` files. Download every part into one directory, reassemble, decompress, and verify:

```bash
cat amd.iso.zst.part-* > amd.iso.zst
zstd -t amd.iso.zst
zstd -d amd.iso.zst -o amd.iso
sha256sum --check amd.iso.sha256
```

Only use the ISO if the checksum reports `OK`. Write the resulting `amd.iso` to a USB drive with balenaEtcher, GNOME Disks, or another image writer. Writing the image erases the USB drive.

## System design

- Official Arch Linux package repositories: `core`, `extra`, and `multilib`
- Official Archiso `releng` profile as the image foundation
- Branded IgorCoin-Qortal OS live environment
- Cinnamon is the intended default desktop; KDE Plasma is included as an alternative session. Actual session availability must be confirmed against the built image.
- Archinstall is included as the guided installation tool
- Reticulum / RNS and NomadNet integration, with a systemd service
- Qortal installation is optional. The desktop offers a setup choice, and the upstream universal installer is available from the application menu.
- The upstream Qortal universal installer is maintained by the Qortal community and is fetched from `https://link.qortal.dev/linux-script` when the user chooses to run it. It is not silently executed during OS installation.
- The live desktop account is `igorcoin` and has passwordless sudo for installation and system administration. This is convenient for a live test image, not a hardened multi-user setup.

## Qortal installer

The repository includes `scripts/install-qortal.sh`, a wrapper for the official upstream Qortal universal Linux installer:

```bash
bash <(curl -fsSL https://link.qortal.dev/linux-script || wget -qO- https://link.qortal.dev/linux-script)
```

The same installer is available in the desktop application menu as **Qortal Universal Linux Installer**. Review upstream script changes before running it; it installs software and may modify the user's Qortal directories.

## Build status and security

This is an experimental distribution, not yet a certified stable release. Pull requests and pushes to `main` run the custom Archiso build workflow. A successful build and checksum do not replace testing in a UEFI virtual machine and on physical hardware.

Secure Boot signing has not been implemented or certified. The requested Linux kernel 7.3.4 is not pinned in the current profile; the image uses the Arch repository kernel package. Do not assume either feature is present until explicitly implemented and tested.

The live account has elevated installation privileges. Do not treat the live session as a hardened daily-use installation.

## Source and build

- Source: https://github.com/linuxmint110791/igor-qortal-os
- Official downloads: https://github.com/linuxmint110791/igor-qortal-os/releases/latest
- Custom ISO build workflow: https://github.com/linuxmint110791/igor-qortal-os/actions/workflows/build-igorcoin-qortal.yml
