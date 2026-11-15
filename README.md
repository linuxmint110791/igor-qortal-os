# IgorCoin-Qortal OS

**IgorCoin-Qortal OS** is an experimental x86_64 Linux distribution built from the official Arch Linux repositories and the official Archiso `releng` profile.

## Download

**[Download the latest rolling IgorCoin-Qortal OS image](https://github.com/linuxmint110791/igor-qortal-os/releases/tag/rolling)**

The `rolling` release is refreshed automatically once every day from the current official Arch Linux repositories. Each successful build replaces the previous ISO assets in that rolling release, so this link always points to the latest successful daily image.

Versioned builds triggered by source changes are published separately. GitHub Actions also retains a downloadable build artifact for 90 days.

If the compressed image is below GitHub's per-file release limit, download `igorcoin-qortal-os.iso.zst` and `igorcoin-qortal-os.iso.sha256`. Decompress and verify:

```bash
zstd -d igorcoin-qortal-os.iso.zst -o igorcoin-qortal-os.iso
sha256sum --check igorcoin-qortal-os.iso.sha256
```

If the compressed image is too large, the Release contains numbered `igorcoin-qortal-os.iso.zst.part-*` files. Download every part into one directory, reassemble, decompress, and verify:

```bash
cat igorcoin-qortal-os.iso.zst.part-* > igorcoin-qortal-os.iso.zst
zstd -t igorcoin-qortal-os.iso.zst
zstd -d igorcoin-qortal-os.iso.zst -o igorcoin-qortal-os.iso
sha256sum --check igorcoin-qortal-os.iso.sha256
```

Only use the ISO if the checksum reports `OK`. Write the resulting `.iso` file to a USB drive with balenaEtcher, GNOME Disks, or another image writer. Writing the image erases the USB drive.

## Rolling-release model

- A scheduled GitHub Actions build runs daily at 03:17 UTC.
- Every build refreshes the Arch package database and upgrades the build environment using `pacman -Syu`.
- The ISO is rebuilt from the current official Arch Linux repositories, not from a frozen package snapshot.
- The build validates the ISO and compressed archive, then verifies the SHA-256 checksum.
- Only a successful scheduled build updates the `rolling` release. If a build fails, the previous working rolling ISO remains available.
- Pushes to `main` still trigger a separate versioned build; manual runs may specify a release tag.

Rolling releases can include new upstream packages and occasional breaking changes. They are intended for testing and early adoption, not guaranteed long-term reproducibility. Keep backups and verify the checksum before writing an image to USB.

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
- Latest rolling download: https://github.com/linuxmint110791/igor-qortal-os/releases/tag/rolling
- All releases: https://github.com/linuxmint110791/igor-qortal-os/releases
- Custom ISO build workflow: https://github.com/linuxmint110791/igor-qortal-os/actions/workflows/build-igorcoin-qortal.yml
