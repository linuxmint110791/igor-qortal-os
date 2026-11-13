# Igorcoin Qortal OS

**Debian 13 Trixie + KDE Plasma + the official Qortal Linux installer.**

Igorcoin Qortal OS is a Debian-based desktop ISO project. It provides a Debian 13 KDE desktop, Calamares installer and the official Qortal Linux setup script embedded in the ISO.

## Included
- Debian 13 Trixie
- KDE Plasma desktop with Wayland session support
- Debian kernel and official Debian repositories
- Calamares installer
- NetworkManager and common firmware packages
- Java 21 runtime and dependencies used by the Qortal setup script
- Official Qortal Linux installer script from https://link.qortal.dev/linux-script
- First-login launch of the Qortal installer, plus a manual Applications-menu launcher

## Qortal installation
The ISO contains the official installer script itself. After the operating system is installed and the user logs into KDE for the first time, the installer opens in a terminal automatically. It can also be started later from **Applications → Install Qortal**.

The official script installs and configures Qortal Core and Qortal Hub, creates launchers and offers its additional node setup options. It downloads the current Qortal components during installation, so an internet connection is required. The installer runs as the normal desktop user and requests sudo when it needs system-level package installation.

The ISO does **not** contain blockchain data, private keys, seed phrases or personal wallet data. Those remain under the user's control.

## Download the ISO
The ISO is published as a separate GitHub Actions artifact, not committed into the source repository.

1. Open https://github.com/linuxmint110791/igor-qortal-os/actions
2. Select the newest successful Build Igorcoin Qortal OS — Debian 13 Trixie run.
3. In the Artifacts section, download Igorcoin-Qortal-OS-Debian13-amd64.
4. Extract the ZIP. It contains the ISO image.

Artifacts are retained for 90 days. Failed builds do not publish an ISO artifact.

## Build the ISO
On a Debian-based amd64 build machine:
~~~bash
git clone https://github.com/linuxmint110791/igor-qortal-os.git
cd igor-qortal-os
sudo bash build-iso.sh
~~~

Output file:
- igorcoin-qortal-os-debian13-amd64.iso

GitHub Actions builds when the build script or workflow changes and supports manual runs from the Actions tab.

## Installation
1. Extract the ISO from the downloaded artifact ZIP.
2. Write the ISO to a USB drive (this erases the selected USB drive).
3. Boot from USB and start the live desktop.
4. Launch Calamares and complete Debian installation.
5. Log into KDE. The official Qortal installer starts automatically on first login.

Back up important data before installing an operating system. Test the ISO in a virtual machine first.

## Project status
The project is under active development. An ISO is ready for testing only after GitHub Actions completes successfully.

## Official resources
- https://www.debian.org/releases/trixie/
- https://qortal.org/
- https://qortal.dev/downloads
- https://github.com/Qortal/qortal
- https://github.com/Qortal/Qortal-Hub
- https://github.com/Qortal/QORTector-scripts
