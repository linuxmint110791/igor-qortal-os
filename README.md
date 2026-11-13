# Igorcoin Qortal OS

![ISO build status](https://github.com/linuxmint110791/igor-qortal-os/actions/workflows/build-iso.yml/badge.svg)


**Debian 13.3 Trixie snapshot baseline + KDE Plasma + the official Qortal Linux installer.**

Igorcoin Qortal OS is a Debian-based desktop ISO project. It provides a Debian 13 KDE desktop, Calamares installer and the official Qortal Linux setup script embedded in the ISO.

## Included
- Debian 13.3 Trixie package baseline, resolved from the official Debian Snapshot archive dated 11 January 2026
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

## Reticulum background service and brief network outages

The ISO build installs the Python Reticulum Network Stack into an isolated virtual environment at `/opt/reticulum-venv` and enables `igorcoin-reticulum.service`. It starts in the background at boot, runs as the unprivileged `reticulum` system user, and restarts if the daemon itself exits. It is not tied to `network-online.target`, so a missing Internet connection does not stop the service from running.

The initial Reticulum config is stored at `/var/lib/reticulum/.reticulum/config` and enables:
- TCP client uplink to `node.reticulumnet.nl:4242`.
- Reticulum AutoInterface for compatible peers on the local LAN.
- Transport forwarding disabled by default; this desktop is a client node unless the owner later chooses to configure transport.

Reticulum's TCP client interface is designed to tolerate intermittent IP connectivity and restore the connection when the remote endpoint is reachable again. The local LAN AutoInterface may continue to work during an Internet outage if the local link and peer devices remain available. Internet-based TCP uplinks cannot work while the Internet path is down. Off-grid operation requires an independent physical link such as a configured LoRa/RNode interface; no LoRa hardware is assumed or enabled by this ISO.

Service controls:
- `igorcoin-reticulum status`
- `sudo igorcoin-reticulum start|stop|restart`
- `igorcoin-reticulum logs`

Qortal Core is not configured to restart merely because the network disappears. A brief outage should leave the Core process running; P2P peers will disconnect and reconnect when connectivity returns. During a complete network isolation, no software can deliver minted blocks to the wider Qortal network, so successful network-wide minting cannot be guaranteed until peers are reachable again. The ISO does not install a blind Core restart loop, because restarting a healthy Core during a transient outage would make recovery worse.

## Hourly Debian package updates

The installed system checks the configured Debian 13.3 Trixie APT repositories hourly, starting ten minutes after boot. It refreshes package indexes and runs `unattended-upgrade` for packages allowed by the explicit Debian stable, stable-updates, and stable-security origins. This applies package updates within the installed Debian release; it does not silently change the system to a newer Debian major release or run `full-upgrade`.

Automatic reboots are disabled. Kernel and other updates that require a reboot are installed but take effect fully after the user chooses to reboot. Packages are installed only from configured Debian APT origins accepted by unattended-upgrades. The hourly task uses a lock to avoid overlapping APT operations.

To inspect update history:
- `sudo journalctl -u igorcoin-auto-update.service`
- `sudo tail -n 100 /var/log/igorcoin-auto-update.log`
- `systemctl list-timers igorcoin-auto-update.timer`
- `sudo systemctl start igorcoin-auto-update.service` to run a check immediately.

This is hourly checking, not instantaneous push delivery: a package published just after a check may take up to roughly an hour plus the configured random delay to be detected. Debian's unattended-upgrades is designed to install only packages from explicitly allowed APT origins and records its actions in its logs. <https://wiki.debian.org/PeriodicUpdates>

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
The ISO is published as a GitHub Release asset and as a temporary GitHub Actions artifact; it is not committed into the source repository.

1. Open https://github.com/linuxmint110791/igor-qortal-os/releases
2. Select the newest release named Igorcoin Qortal OS.
3. Download every numbered `.part` file, plus the `.sha256` file and `DOWNLOAD-INSTRUCTIONS.txt`.
4. Reconstruct the ISO using the instructions and verify the SHA256 checksum before writing it to USB.

The Actions artifact is retained for 90 days. Failed builds do not publish a release.

## Build the ISO
The build uses the official Debian 13.3 Trixie package baseline, pinned to the Debian Snapshot archive dated 11 January 2026. The original Debian 13.3 netinst ISO directory is recorded in `debian-source.env`; the custom image is assembled from signed Debian packages with Debian Live `live-build`, not by modifying the netinst ISO byte-for-byte. The built system uses the official current Trixie and security repositories for subsequent hourly updates.

Official Debian installer source: https://cdimage.debian.org/cdimage/archive/13.3.0/amd64/iso-cd/  
Official package snapshot: https://snapshot.debian.org/archive/debian/20260111T000000Z/  
Debian Live build documentation: https://live-team.pages.debian.net/live-manual/

### Prepare an Ubuntu/Debian build computer

Run the setup script as your normal desktop user (not with `sudo`):
~~~bash
bash setup-build-host.sh
~~~

It installs the build dependencies from the host's configured Ubuntu/Debian repositories and clones the project into `~/igorcoin-os-build`. It does not install the new OS or write to a USB drive.

To build manually after setup:
~~~bash
cd ~/igorcoin-os-build
sudo bash ./build-iso.sh
~~~

GitHub Actions performs the same validation and build automatically after changes to the build files, or through a manual workflow run.

Output file:
- igorcoin-qortal-os-debian-13.3-amd64.iso

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
