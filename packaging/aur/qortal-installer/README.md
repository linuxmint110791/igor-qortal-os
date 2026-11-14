# qortal-installer

Arch Linux/AUR package proposal for a desktop launcher that runs the official Qortal Linux setup script.

## What it does

- Adds **Qortal Installer** to the desktop application menu.
- Downloads the official installer from https://link.qortal.dev/linux-script over HTTPS when launched.
- Shows the downloaded script's SHA-256 digest before execution.
- Asks for confirmation before running the upstream script.
- Runs as the logged-in user; the upstream installer requests sudo only where it needs system-level changes.

The upstream script installs/configures Qortal Core and Qortal Hub. Read its source before running it:
https://github.com/Qortal/QORTector-scripts/blob/main/Qortal-Setup-Linux.sh

## Install locally

From this directory:

```bash
makepkg -si
```

Then launch **Qortal Installer** from the application menu or run:

```bash
qortal-installer
```

## Updates

The package contains a launcher, not a bundled copy of the upstream installer. Each launch downloads the current upstream script. Update the launcher itself with the normal package manager after a new package release.

## AUR publication status

This directory is the source proposal in the IgorCoin OS repository. Publishing to AUR still requires an AUR account and an authorized SSH key. Before AUR publication, replace the placeholder `SKIP` source checksums with verified checksums and generate `.SRCINFO` using `makepkg --printsrcinfo`.
