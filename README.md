# Igorcoin Qortal OS

**Debian 13 Trixie + KDE Plasma + Qortal applications bundled in the ISO.**

Igorcoin Qortal OS is a Debian-based desktop ISO project. The goal is a stable Debian 13 system with Qortal ready to set up on first login.

## Included
- Debian 13 Trixie
- KDE Plasma desktop with Wayland session support
- Debian kernel and official Debian repositories
- Calamares installer
- NetworkManager and common firmware packages
- Java runtime and FUSE support
- Official Qortal Core release bundle
- Official Qortal Hub AppImage
- Official Qortal UI AppImage
- First-login setup that copies the bundled Qortal applications into the user account and creates application-menu launchers

The Qortal Core, Hub and UI application files are downloaded from their official GitHub release download endpoints during the ISO build and stored inside the ISO. The blockchain database, account seed, wallet data and bootstrap are **not** included. Each user creates or restores their own account, and the node downloads blockchain data when started.

## Download the ISO
The ISO is published as a separate GitHub Actions artifact, not committed into the source repository.

1. Open https://github.com/linuxmint110791/igor-qortal-os/actions
2. Select the newest successful Build Igorcoin Qortal OS — Debian 13 Trixie run.
3. In the Artifacts section, download Igorcoin-Qortal-OS-Debian13-amd64.
4. Extract the ZIP. It contains the ISO image.

Artifacts are retained for 90 days. Failed builds do not publish an ISO artifact.

## Qortal setup
After installing Debian and logging into KDE for the first time, a setup window copies Qortal Core, Qortal Hub and Qortal UI from the ISO to your home folder and creates launchers in the Applications menu. You can also run **Applications → Install Qortal components** later.

Start **Qortal Core** first. Then open **Qortal Hub** or **Qortal UI**. An internet connection is still required for node synchronization and normal Qortal network use. The ISO does not contain blockchain data or personal wallet/seed information.

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
5. On first KDE desktop login, install the bundled Qortal applications when prompted.

Back up important data before installing an operating system. Test the ISO in a virtual machine first.

## Project status
The project is under active development. An ISO is ready for testing only after GitHub Actions completes successfully.

## Official resources
- https://www.debian.org/releases/trixie/
- https://qortal.org/
- https://github.com/Qortal/qortal
- https://github.com/Qortal/Qortal-Hub
- https://github.com/Qortal/qortal-ui
