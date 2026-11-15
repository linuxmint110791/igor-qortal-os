# IgorCoin-Qortal OS

**IgorCoin-Qortal OS** is an x86_64 Arch Linux live image built from the current official Arch Linux repositories and the upstream Archiso `releng` profile.

The goal is a Qortal-centred KDE desktop. No general-purpose web browser (including Brave or Firefox) is installed. Qortal Hub is the primary network interface.

## Download

**[Latest rolling ISO — GitHub Releases](https://github.com/linuxmint110791/igor-qortal-os/releases/tag/rolling)**

A scheduled build runs every day at 03:17 UTC. It refreshes the official Arch packages, builds a new ISO, verifies its SHA-256 checksum, and updates the `rolling` release only if every build step succeeds. If a build fails, the previous working rolling ISO remains available.

Pushes to `main` trigger a separate versioned build. GitHub Actions also stores temporary build artifacts for 90 days.

Download the compressed ISO and checksum from the rolling release. Decompress and verify:

```bash
zstd -d igorcoin-qortal-os.iso.zst -o igorcoin-qortal-os.iso
sha256sum --check igorcoin-qortal-os.iso.sha256
```

If the compressed image is split into numbered parts, download every part and reassemble before decompressing:

```bash
cat igorcoin-qortal-os.iso.zst.part-* > igorcoin-qortal-os.iso.zst
zstd -t igorcoin-qortal-os.iso.zst
zstd -d igorcoin-qortal-os.iso.zst -o igorcoin-qortal-os.iso
sha256sum --check igorcoin-qortal-os.iso.sha256
```

Only write the ISO to USB after the checksum reports `OK`. Writing an image erases the selected USB drive.

## Standard Arch Linux base

- Official Arch Linux repositories and package signatures.
- Current upstream Archiso `releng` live environment and package set.
- Standard Arch boot menu: Syslinux for legacy BIOS and systemd-boot for UEFI.
- Standard Arch live shell and official `archinstall` installer.
- No custom desktop environment, custom display manager, Calamares installer, DNS override, or custom service stack is added.
- Only the distribution identity and Qortal installer command are layered on top of upstream Archiso.

The live environment is a standard Arch installation environment, not a preconfigured desktop distribution. Use `archinstall` from the live shell to install Arch Linux to disk.

## Qortal installer

The existing upstream Qortal installer wrapper is preserved in `scripts/install-qortal.sh` and copied unchanged into the live image as:

```bash
igorcoin-qortal-install
```

It downloads and runs the official Qortal Linux installer from `https://link.qortal.dev/linux-script` when the user explicitly starts it. The first-time Core installation remains an explicit action; the ISO does not silently install or initialize a wallet.

## Qortal login integration

After the user has installed Qortal Core once and the Core start script exists at `~/qortal/start.sh`, desktop login runs `igorcoin-qortal-session`. It starts the local Core if it is not already running, then opens the native Qortal Hub AppImage. The Core log is written to `~/.local/state/igorcoin-qortal/core.log`.

Qortal Hub is the central interface for the Qortal network. Its local-node features require the local Core to be installed and running. Wallet unlock and account authentication are not bypassed: users must unlock their Qortal account inside Qortal Hub when required. Linux login does not expose or automatically unlock wallet secrets.

## Rolling-release details

- Daily ISO rebuild from current official Arch repositories.
- Full package refresh with `pacman -Syu` inside the clean Arch build container.
- ISO and compressed archive integrity checks.
- SHA-256 verification before publishing.
- Failed builds do not replace the previous successful `rolling` release.

The daily job updates the downloadable ISO; it does not remotely update an already installed computer. On an installed Arch system, use the normal full system upgrade command:

```bash
sudo pacman -Syu
```

Arch is a rolling-release distribution. Read Arch news before large upgrades and keep backups.

## Security and status

This is an experimental community image, not an official Arch Linux release. The ISO uses upstream Archiso boot components and does not currently provide a signed Secure Boot chain. Secure Boot may need to be disabled to boot it.

A successful build and checksum do not replace testing on a UEFI virtual machine and physical hardware. Always review the build logs and verify the checksum before installation.

## Project links

- Source: https://github.com/linuxmint110791/igor-qortal-os
- Latest rolling ISO: https://github.com/linuxmint110791/igor-qortal-os/releases/tag/rolling
- All releases: https://github.com/linuxmint110791/igor-qortal-os/releases
- Build status: https://github.com/linuxmint110791/igor-qortal-os/actions/workflows/build-igorcoin-qortal.yml
