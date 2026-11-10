# Igorcoin Qortal OS

**Debian 13 Trixie + KDE Plasma + Qortal installer.**

Igorcoin Qortal OS is a Debian-based desktop ISO project. The goal is a straightforward, stable Debian 13 system with the Qortal installation workflow ready on first login.

## Included

- Debian 13 **Trixie** (Stable)
- KDE Plasma desktop with Wayland session support
- Debian kernel and official Debian repositories
- Calamares installer
- NetworkManager and common firmware packages
- Qortal Linux installer launcher
- First-login Qortal setup: opens the installer once after the first desktop login
- A permanent **Install Qortal** application-menu entry
- SHA-256 checksum for each generated ISO

## Qortal setup

The ISO includes a launcher that runs the Qortal Linux installation script supplied at:

`https://link.qortal.dev/linux-script`

After the first desktop login, a Konsole window opens and starts:

```bash
bash <(curl -fsSL https://link.qortal.dev/linux-script || wget -qO- https://link.qortal.dev/linux-script)
```

You can also start it later from **Applications → Install Qortal**.

**Important:** Qortal Core and related components are installed by the Qortal setup script after the first login; they are not pre-installed as static packages inside the ISO. The ISO contains the launcher and first-login integration. An internet connection is required for the script download.

Only run installation scripts from sources you trust. Never share your Qortal seed phrase or private keys.

## Build the ISO

On a Debian-based build machine:

```bash
git clone https://github.com/linuxmint110791/igor-qortal-os.git
cd igor-qortal-os
sudo bash build-iso.sh
```

The output files are:

- `igorcoin-qortal-os-debian13-amd64.iso`
- `igorcoin-qortal-os-debian13-amd64.iso.sha256`

GitHub Actions also builds the ISO on pushes affecting the build script/workflow and supports manual runs from the Actions tab. Download the ISO from the successful workflow's artifact.

## Installation

1. Write the ISO to a USB drive (this erases the selected USB drive).
2. Boot the computer from USB.
3. Start the live desktop and launch the installer.
4. Complete the Debian installation.
5. On the first KDE desktop login, the Qortal installer opens automatically.
6. Follow the Qortal installer's instructions.

Back up important data before installing an operating system. Test the ISO in a virtual machine first when possible.

## Project status

This project is under active development. GitHub Actions must complete successfully before an ISO artifact is considered ready for testing.

## Official resources

- [Debian 13 Trixie](https://www.debian.org/releases/trixie/)
- [Qortal](https://qortal.org/)
- [Qortal Core](https://github.com/Qortal/qortal)
- [Qortal Hub](https://github.com/Qortal/Qortal-Hub)
- [Qortal Hub releases](https://github.com/Qortal/Qortal-Hub/releases)

---

**Igorcoin Qortal OS — Qortal on kaasas.** 🚀
