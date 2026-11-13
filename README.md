# Igorcoin Qortal OS

**Debian 13 Trixie + KDE Plasma + the official Qortal Linux installer.**

Igorcoin Qortal OS is a Debian-based desktop ISO project. It provides a Debian 13 KDE desktop, Calamares installer and the official Qortal Linux setup script embedded in the ISO.

## Included
- Debian 13 Trixie
- KDE Plasma desktop with Wayland session support
- Debian kernel and official Debian repositories
- Calamares installer
- NetworkManager and common firmware packages
- UFW firewall enabled by default: inbound connections denied, outbound connections allowed
- No SSH server installed by default; SSH service and socket activation are masked
- Hardened SSH daemon policy staged for any deliberate future SSH installation (public-key authentication only, root login and password authentication disabled)
- AppArmor enabled and Debian unattended security updates configured
- Java 21 runtime and dependencies used by the Qortal setup script
- Official Qortal Linux installer script from https://link.qortal.dev/linux-script
- First-login launch of the Qortal installer, plus a manual Applications-menu launcher

## Security defaults

The installed system starts with a deny-incoming UFW firewall and allows normal outbound connections. An SSH server is not installed, and SSH service/socket activation is masked. This prevents unsolicited SSH login attempts from reaching an SSH daemon. The image also enables AppArmor and configures Debian unattended security updates.

If you later deliberately need remote SSH access, you must install and explicitly unmask/enable the SSH service and socket yourself. The included SSH hardening drop-in disables password and root login and permits public-key authentication only. Keep the firewall enabled and add a narrowly scoped allow rule only for the trusted source network before enabling SSH. No configuration can guarantee that a machine is impossible to compromise; keep the OS and applications updated and protect your private keys.

## Single-login foundation (Linux + KDE Wallet)

The ISO installs KDE Wallet, the Secret Service command-line client and Debian's `libpam-kwallet5` integration. SDDM is configured to unlock the KDE Wallet during a successful Linux login, provided the KDE Wallet password is the same as the Linux account password. The PAM entries are optional, so a KWallet issue should not prevent Linux login.

This prepares the operating-system side for a single-login Qortal experience. It does **not yet automatically unlock Qortal Hub**: the current upstream Hub lock screen still asks for the Qortal wallet password and does not expose a Linux Secret Service/KWallet auto-unlock integration. Hub-side support must be added and built into a compatible Hub release before the full one-login flow can be claimed. The Qortal wallet password must never be copied into a shell script, environment variable, plaintext file, or made equal to the Linux password just to simulate single sign-on.

## Qortal Network tray indicator

KDE starts an **Igorcoin Qortal Network** system-tray indicator beside the Wi-Fi/network icon after login. Its menu shows whether the local Qortal Core API port (12391) is listening and whether a Reticulum-related process is detected. It provides shortcuts to open Qortal Hub and KDE network settings. Status is refreshed every five seconds.

Choose **Local**, **Public**, or **Custom** node inside Qortal Hub's own connection-mode screen. The tray indicator is a quick status/launch panel; it does not replace NetworkManager's Wi-Fi controls or silently change Hub connection settings. Reticulum reachability is more than a process check, so the indicator currently reports process detection rather than claiming that a remote Reticulum route is working.

## Qortal node and Reticulum networking

The official Qortal Hub installer is used so the ISO receives the current Hub release. The Hub's connection selector already supports:

- **Local node** — connects to the Qortal Core running on this computer (the default local API endpoint is `https://127.0.0.1:12391` in the desktop app).
- **Public node** — connects to the configured Qortal public endpoint for hosted access.
- **Custom node** — lets the user save and switch between additional node URLs, including other machines on the LAN or self-operated public nodes.

These modes are selected inside Qortal Hub's connection-mode screen; they are not separate blockchain networks. A local Core remains the preferred full-node setup. Public-node access depends on the operator of that public service.

Qortal Hub also includes its own Reticulum integration. It manages its Reticulum daemon, bridge, mesh interfaces and bootstrap connections itself; Igorcoin OS does not start a competing system-wide `rnsd` service. The Hub's documented default mesh bootstrap endpoints include `phantom.mobilefabrik.com:4400`, `reticulum.qortal.link:4444` and `reticulum2.qortal.link:4444`. Reticulum options and connection status are available in Hub's Settings.

### Firewall ports

The default firewall blocks unsolicited inbound traffic but allows outbound connections. The ISO adds narrowly scoped inbound TCP rules for:
- `12392/tcp` — Qortal blockchain peer connections.
- `12394/tcp` — Qortal QDN data-peer connections.
- `4243/tcp` — Qortal Hub's Linux Reticulum mesh listener.

These rules allow other nodes to initiate connections to this computer when the router/network also permits it. Outbound connections to public Qortal nodes and Reticulum bootstrap hubs work without opening broad inbound access. Qortal API port `12391` is not opened to the network; it remains a local interface.

## Qortal installation
The ISO contains the official installer script itself. After the operating system is installed and the user logs into KDE for the first time, the installer opens in a terminal automatically. It can also be started later from **Applications → Install Qortal**.

The official script installs and configures Qortal Core and Qortal Hub, creates launchers and offers its additional node setup options. It downloads the current Qortal components during installation, so an internet connection is required. The installer runs as the normal desktop user and requests sudo when it needs system-level package installation.

The ISO does **not** contain blockchain data, private keys, seed phrases or personal wallet data. Those remain under the user's control.

## Optional encrypted Igorcoin wallet backup

The installed desktop provides graphical launchers under Applications:

- **Prepare Encrypted Igorcoin Wallet** opens a file picker for the original Qortal wallet JSON, then encrypts a copy with an age passphrase. The original JSON is not modified. The encrypted copy is saved in the user's `igorcoin-wallet-export` folder.
- **Restore Igorcoin Wallet** lets the user select an `.age` backup (or uses the optional backup bundled in the ISO), then opens a secure passphrase prompt in Konsole and restores the Qortal-encrypted JSON to `~/qortal/Igorcoin-Wallet.json`.
- The restore tool refuses to overwrite an existing restored wallet.

To include the encrypted backup in a later ISO, upload only `Igorcoin-Wallet.json.age` to the repository's `wallet/` folder using GitHub's web interface. The workflow automatically rebuilds the ISO when that encrypted file changes. Never upload the original JSON, and never put the age passphrase in GitHub, the ISO, or the build script. If the encrypted file is not present in the repository during the build, no personal wallet backup is bundled.

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
