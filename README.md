# IgorCoin-Qortal OS

**IgorCoin-Qortal OS** is an experimental Arch Linux-based distribution project. It uses the official Archiso releng profile as its starting point and produces a separately branded x86_64 live ISO.

## Current design

- Arch Linux base and rolling package repositories
- **Cinnamon 6.8 as the intended default desktop session**
- **KDE Plasma available as an alternative session** through SDDM
- SDDM display manager; the live session is configured to start Cinnamon
- Linux kernel **7.3.4 is the requested release target**; the current profile still installs the repository `linux` package and does not yet pin or build 7.3.4
- Qortal Core and Qortal Hub fetched from their upstream GitHub releases during image customization
- Reticulum (RNS), NomadNet and Reticulum MeshChat
- NetworkManager, Bluetooth, PipeWire and common laptop utilities
- Archinstall available for installation; a polished graphical installer is not yet part of this first build
- No wallet seed, private key or user credentials are embedded in the image

## Build

GitHub Actions → **Build IgorCoin-Qortal OS (Archiso)** → **Run workflow**.

A successful run uploads the artifact:

**IgorCoin-Qortal-OS-x86_64**

The ZIP contains:
- `igorcoin-qortal-os-x86_64.iso`
- `igorcoin-qortal-os-x86_64.iso.sha256`

Verify after extracting:

```bash
sha256sum -c igorcoin-qortal-os-x86_64.iso.sha256
```

## Important security status

**Secure Boot is not yet implemented or certified in this build.** The image has UEFI boot support, but its bootloader is not signed with a key trusted by a typical PC's factory Secure Boot database. Keep Secure Boot enabled only after a signed boot chain and the required trust/enrollment process have been implemented and tested. Do not assume that a successful ISO build means Secure Boot compatibility.

The live session's `liveuser` account has passwordless sudo for installation and recovery tasks. Do not use the live account as a permanent daily account. The installed system and installer workflow still need further testing.

## Project status

This is an experimental first distribution build, not a stable release. Each successful artifact must be tested in a UEFI virtual machine and on physical hardware before being recommended for installation. Qortal and Reticulum upstream assets are fetched during the image build, so the build is not yet fully reproducible or version-pinned. Cinnamon and KDE package availability and session startup must be verified in CI before the ISO is considered successful. The kernel 7.3.4 target requires a separately pinned package/build step.
