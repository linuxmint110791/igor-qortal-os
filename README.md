# Igorcoin Qortal OS

**Debian 13 Trixie + KDE Plasma + Qortal installer.**

Igorcoin Qortal OS is a Debian-based desktop ISO project. The goal is a stable Debian 13 system with the Qortal installation workflow ready on first login.

## Included
- Debian 13 Trixie
- KDE Plasma desktop with Wayland session support
- Debian kernel and official Debian repositories
- Calamares installer
- NetworkManager and common firmware packages
- Qortal Linux installer launcher and first-login setup
- SHA-256 checksum for each generated ISO

## Download the ISO
The ISO is published as a separate GitHub Actions artifact, not committed into the source repository.

1. Open https://github.com/linuxmint110791/igor-qortal-os/actions
2. Select the newest successful Build Igorcoin Qortal OS — Debian 13 Trixie run.
3. In the Artifacts section, download Igorcoin-Qortal-OS-Debian13-amd64.
4. Extract the ZIP. It contains the ISO and its SHA-256 checksum.

Artifacts are retained for 90 days. Failed builds do not publish an ISO artifact.

## Qortal setup
The ISO includes a launcher that downloads the Qortal Linux installer from:
https://link.qortal.dev/linux-script

The first desktop login offers the installer; it is also available from Applications → Install Qortal. Qortal Core and related components are installed after login, not embedded as static packages in the ISO. An internet connection is required.

Only run installation scripts from sources you trust. Never share your Qortal seed phrase or private keys.

## Build the ISO
On a Debian-based amd64 build machine:
~~~bash
git clone https://github.com/linuxmint110791/igor-qortal-os.git
cd igor-qortal-os
sudo bash build-iso.sh
~~~

Output files:
- igorcoin-qortal-os-debian13-amd64.iso
- igorcoin-qortal-os-debian13-amd64.iso.sha256

GitHub Actions builds when the build script or workflow changes and supports manual runs from the Actions tab.

## Installation
1. Extract the ISO from the downloaded artifact ZIP.
2. Verify its SHA-256 checksum.
3. Write the ISO to a USB drive (this erases the selected USB drive).
4. Boot from USB and start the live desktop.
5. Launch the installer and complete Debian installation.
6. On first KDE desktop login, the Qortal installer is offered.

Back up important data before installing an operating system. Test the ISO in a virtual machine first.

## Project status
The project is under active development. An ISO is ready for testing only after GitHub Actions completes successfully.

## Official resources
- https://www.debian.org/releases/trixie/
- https://qortal.org/
- https://github.com/Qortal/qortal
- https://github.com/Qortal/Qortal-Hub
