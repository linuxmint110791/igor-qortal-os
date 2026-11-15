# IgorCoin-Qortal OS — official Archiso releng profile

This image intentionally follows the upstream Arch Linux live ISO as closely as possible. Only the ISO identity and the existing Qortal installer command are customized.

## What is included

- Current official Archiso `releng` profile and package list.
- Official Arch Linux package repositories and package signatures.
- Syslinux legacy BIOS boot and systemd-boot UEFI boot, matching upstream releng.
- Standard Arch live shell and `archinstall`.
- One additional package, `curl`, required by the unchanged Qortal installer wrapper.
- The unchanged `scripts/install-qortal.sh`, available in the live shell as `igorcoin-qortal-install`.

No custom desktop, display manager, Calamares installer, DNS configuration, Reticulum services, or custom GRUB theme is added.

## Build on Linux

Install Docker, then run:

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
bash ./archiso/build.sh
```

The build runs inside an official Arch Linux container and does not install Arch packages onto the host OS.

Output: `archiso/out/amd.iso`.

## GitHub Actions

The workflow builds on pushes to `main), on a daily schedule, and when manually dispatched. A successful daily build updates the `rolling` GitHub Release. Failed builds leave the previous release assets untouched.

## Boot and installation

Boot the ISO and use the standard Arch live environment. Start the guided installer with:

```bash
archinstall
```

This is the upstream Arch installer, not a custom graphical installer.

## Qortal

Run the optional Qortal setup only when desired:

```bash
igorcoin-qortal-install
```

The wrapper fetches the official Qortal Linux installer at run time. Its repository source is preserved unchanged at `scripts/install-qortal.sh`.

## Testing and security

Test BIOS and UEFI boot in a virtual machine before installing on physical hardware. The current image does not include a certified Secure Boot signing chain. Verify the published SHA-256 checksum before writing the ISO to USB.
