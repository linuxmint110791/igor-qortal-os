#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Debian release/source metadata is centralized in debian-source.env.
SOURCE_CONFIG="$SCRIPT_DIR/debian-source.env"
if [[ -f "$SOURCE_CONFIG" ]]; then
  # This file is maintained in the repository and contains only simple assignments.
  # shellcheck disable=SC1090
  source "$SOURCE_CONFIG"
fi
DEBIAN_SUITE="${DEBIAN_SUITE:-trixie}"
DEBIAN_POINT_RELEASE="${DEBIAN_POINT_RELEASE:-13.3}"
DEBIAN_SNAPSHOT="${DEBIAN_SNAPSHOT:-20260111T000000Z}"
if [[ ! "$DEBIAN_SNAPSHOT" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "Invalid Debian snapshot timestamp: $DEBIAN_SNAPSHOT" >&2
  exit 2
fi
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build-${DEBIAN_SUITE}}"
OUTPUT_ISO="${OUTPUT_ISO:-$SCRIPT_DIR/igorcoin-qortal-os-debian-${DEBIAN_POINT_RELEASE}-amd64.iso}"
QORTAL_INSTALLER_URL="https://link.qortal.dev/linux-script"

case "$BUILD_DIR" in
  ""|"/"|"$SCRIPT_DIR"|"$HOME"|"/home"|"/root")
    echo "Refusing unsafe build directory: $BUILD_DIR" >&2
    exit 1
    ;;
esac
if [[ "$OUTPUT_ISO" == "$BUILD_DIR"* ]]; then
  echo "Output ISO must be outside build directory." >&2
  exit 1
fi

APT_NETWORK_OPTIONS=(-o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o Acquire::Retries=2)
apt-get "${APT_NETWORK_OPTIONS[@]}" update
apt-get "${APT_NETWORK_OPTIONS[@]}" install -y --no-install-recommends \
  live-build debootstrap debian-archive-keyring curl wget ca-certificates xorriso squashfs-tools \
  dosfstools mtools grub-pc-bin grub-efi-amd64-bin \
  isolinux syslinux-common syslinux-utils

rm -rf -- "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

lb config \
  --mode debian \
  --initsystem systemd \
  --distribution "$DEBIAN_SUITE" \
  --mirror-bootstrap "$DEBIAN_PACKAGE_ARCHIVE" \
  --mirror-chroot "$DEBIAN_PACKAGE_ARCHIVE" \
  --mirror-binary "$DEBIAN_BINARY_ARCHIVE" \
  --mirror-binary-security "$DEBIAN_SECURITY_ARCHIVE" \
  --apt-options "--yes -o Acquire::Check-Valid-Until=false -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o Acquire::Retries=2" \
  --security false \
  --linux-packages none \
  --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid \
  --apt-recommends false \
  --apt-indices false \
  --apt-source-archives false \
  --bootappend-live "boot=live components quiet splash"

mkdir -p \
  config/package-lists \
  config/includes.chroot/usr/local/share/igorcoin-qortal-os \
  config/includes.chroot/usr/local/bin \
  config/includes.chroot/usr/local/sbin \
  config/includes.chroot/usr/share/applications \
  config/includes.chroot/usr/share/icons/hicolor/scalable/apps \
  config/includes.chroot/usr/share/backgrounds/igorcoin-qortal \
  config/includes.chroot/usr/share/wallpapers/Igorcoin-Qortal/contents/images/1920x1080 \
  config/includes.chroot/usr/share/pixmaps \
  config/includes.chroot/etc/xdg \
  config/includes.chroot/etc/systemd/system \
  config/includes.chroot/etc/xdg/autostart \
  config/includes.chroot/etc/ssh/sshd_config.d \
  config/includes.chroot/etc/apt/apt.conf.d \
  config/includes.chroot/etc/default \
  config/includes.chroot/etc/ufw \
  config/hooks/normal \
  config/archives

# Official Qortal visual assets from the Qortal Project press kit.
# The press-kit page explicitly permits community use of its images.
QORTAL_MEDIA_BASE="https://wiki.qortal.org/lib/exe/fetch.php?media="
QORTAL_ASSET_DIR="config/includes.chroot/usr/share/backgrounds/igorcoin-qortal"
download_qortal_asset() {
  local media_name="$1"
  local output_name="$2"
  curl --fail --location --connect-timeout 20 --max-time 180 --retry 4 --retry-all-errors \
    "${QORTAL_MEDIA_BASE}${media_name}" -o "$QORTAL_ASSET_DIR/$output_name"
  test -s "$QORTAL_ASSET_DIR/$output_name"
}
download_qortal_asset "qortal_background_dark_.jpg" "qortal-dark.jpg"
download_qortal_asset "qortal_background_extra_dark_.jpg" "qortal-extra-dark.jpg"
download_qortal_asset "qortal_background_light_.jpg" "qortal-light.jpg"
download_qortal_asset "qortal-thefuture-wallpaper.png" "qortal-future.png"
curl --fail --location --connect-timeout 20 --max-time 180 --retry 4 --retry-all-errors \
  "${QORTAL_MEDIA_BASE}qortal_official_logo_transparent_.png" \
  -o config/includes.chroot/usr/share/pixmaps/qortal-logo.png
test -s config/includes.chroot/usr/share/pixmaps/qortal-logo.png

# Expose a curated default Qortal wallpaper in KDE's wallpaper chooser.
install -m 0644 "$QORTAL_ASSET_DIR/qortal-dark.jpg" \
  config/includes.chroot/usr/share/wallpapers/Igorcoin-Qortal/contents/images/1920x1080/default.jpg
cat > config/includes.chroot/usr/share/wallpapers/Igorcoin-Qortal/metadata.json <<'WALLPAPER'
{
  "KPlugin": {
    "Id": "Igorcoin-Qortal",
    "Name": "Igorcoin Qortal",
    "Description": "Official Qortal dark background"
  }
}
WALLPAPER
cat > config/includes.chroot/usr/share/wallpapers/Igorcoin-Qortal/contents/metadata.json <<'WALLPAPER'
{
  "KPlugin": {
    "Id": "Igorcoin-Qortal/contents",
    "Name": "Igorcoin Qortal wallpaper"
  }
}
WALLPAPER

# Enable the standard freedesktop notification sound theme in KDE.
cat > config/includes.chroot/etc/xdg/kdeglobals <<'KDEGLOBALS'
[Sounds]
Theme=freedesktop
KDEGLOBALS

# Disable the legacy security entry generated by the runner live-build and
# add the matching official Debian security archive for this selected suite.
# HTTP avoids bootstrap CA-certificate timing issues; APT still verifies the
# signed Debian repository metadata and packages.
printf 'deb http://security.debian.org/debian-security %s-security main contrib non-free non-free-firmware\n' "$DEBIAN_SUITE" > config/archives/debian-security.list.chroot
cp config/archives/debian-security.list.chroot config/archives/debian-security.list.binary

cat > config/package-lists/igorcoin-qortal-os.list.chroot <<'PACKAGES'
# Desktop: KDE Plasma session running on Wayland (Xwayland is intentionally omitted).
# Install kernel explicitly; skip live-build's obsolete Contents index autodetection.
linux-image-amd64
isolinux
kde-plasma-desktop
kwin-wayland
sddm
konsole
dolphin
kate
ark
plasma-nm
plasma-pa
network-manager
pipewire
wireplumber
pavucontrol
sound-theme-freedesktop
calamares
calamares-settings-debian
sudo
curl
wget
ca-certificates
git
unzip
zip
jq
imagemagick
rsync
openjdk-21-jre-headless
desktop-file-utils
xdg-utils
ffmpeg
yt-dlp
fastfetch
age
kdialog
python3-pyqt6
python3-venv
kwalletmanager
libpam-kwallet5
libsecret-tools
ufw
unattended-upgrades
apt-listchanges
apparmor
apparmor-utils
pciutils
usbutils
iproute2
iputils-ping
firmware-linux
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
firmware-mediatek
firmware-atheros
firmware-brcm80211
PACKAGES

# SSH is deliberately unavailable by default. Even if an SSH server is added
# later, the service/socket remain masked until the owner explicitly unmasks them.
cat > config/includes.chroot/etc/ssh/sshd_config.d/99-igorcoin-hardening.conf <<'SSH'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 20
AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
PermitTunnel no
SSH

# Firewall defaults: block unsolicited inbound connections, allow outbound traffic.
cat > config/includes.chroot/etc/default/ufw <<'UFW'
# Igorcoin Qortal OS firewall defaults
IPV6=yes
DEFAULT_INPUT_POLICY="DROP"
DEFAULT_OUTPUT_POLICY="ACCEPT"
DEFAULT_FORWARD_POLICY="DROP"
DEFAULT_APPLICATION_POLICY="SKIP"
UFW
cat > config/includes.chroot/etc/ufw/ufw.conf <<'UFWCONF'
# Igorcoin Qortal OS: firewall enabled on installed systems
ENABLED=yes
LOGLEVEL=low
UFWCONF

# Automatically install Debian security updates.
cat > config/includes.chroot/etc/apt/apt.conf.d/20auto-upgrades <<'APT'
# Igorcoin OS: the dedicated hourly systemd timer below controls update cadence.
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT

cat > config/includes.chroot/etc/apt/apt.conf.d/52igorcoin-unattended-upgrades <<'APT'
Unattended-Upgrade::Origins-Pattern {
  "origin=Debian,codename=${distro_codename},label=Debian";
  "origin=Debian,codename=${distro_codename}-updates,label=Debian";
  "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "false";
Unattended-Upgrade::Remove-New-Unused-Dependencies "false";
APT

cat > config/includes.chroot/usr/local/sbin/igorcoin-auto-update <<'UPDATE'
#!/usr/bin/env bash
set -Eeuo pipefail
exec 9>/run/lock/igorcoin-auto-update.lock
if ! flock -n 9; then
  echo "Another Igorcoin update process is already running."
  exit 0
fi
LOG=/var/log/igorcoin-auto-update.log
mkdir -p /var/log
{
  echo "===== Igorcoin Debian update: $(date --iso-8601=seconds) ====="
  apt-get update
  unattended-upgrade --verbose
  echo "===== Update check finished: $(date --iso-8601=seconds) ====="
} 2>&1 | tee -a "$LOG"
UPDATE
chmod 0755 config/includes.chroot/usr/local/sbin/igorcoin-auto-update

cat > config/includes.chroot/etc/systemd/system/igorcoin-auto-update.service <<'UNIT'
[Unit]
Description=Igorcoin OS hourly Debian package updates
Wants=network-online.target
After=network-online.target
ConditionPathExists=/usr/bin/apt-get

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/igorcoin-auto-update
Nice=10
IOSchedulingClass=idle
UNIT

cat > config/includes.chroot/etc/systemd/system/igorcoin-auto-update.timer <<'UNIT'
[Unit]
Description=Check Debian package updates every hour

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
RandomizedDelaySec=5min
Persistent=true
Unit=igorcoin-auto-update.service

[Install]
WantedBy=timers.target
UNIT

cat > config/hooks/normal/0900-igorcoin-security.hook.chroot <<'SECURITY'
#!/bin/sh
set -eu

# Never ship an SSH daemon in the default desktop installation.
if dpkg-query -W -f='${Status}' openssh-server 2>/dev/null | grep -q 'install ok installed'; then
  apt-get purge -y openssh-server openssh-sftp-server
fi

# Mask both service and socket activation, so SSH cannot start accidentally.
mkdir -p /etc/systemd/system
ln -sfn /dev/null /etc/systemd/system/ssh.service
ln -sfn /dev/null /etc/systemd/system/ssh.socket
ln -sfn /dev/null /etc/systemd/system/sshd.service

# Enable KWallet PAM integration: the user's KDE wallet can unlock at SDDM
# login when its password matches the Linux account password.
# Optional PAM modules must never become a login dependency.
PAM_SDDM="/etc/pam.d/sddm"
if [[ -f "$PAM_SDDM" ]]; then
  if ! grep -q 'pam_kwallet5.so' "$PAM_SDDM"; then
    cat >> "$PAM_SDDM" <<'PAM'

# Igorcoin Qortal OS: unlock the KDE Wallet after successful desktop login.
auth optional pam_kwallet5.so
session optional pam_kwallet5.so auto_start
PAM
  fi
else
  echo "Warning: SDDM PAM file not found; KWallet PAM auto-unlock was not configured."
fi

# Keep Qortal Core and Qortal Hub reachable while retaining deny-by-default
# inbound policy. These are the standard Qortal P2P, QDN data-peer, and
# Qortal Hub Reticulum mesh listener ports. Public Reticulum bootstrap
# connections are outbound and do not require broad inbound access.
if command -v ufw >/dev/null 2>&1; then
  ufw allow 12392/tcp comment 'Qortal blockchain peers'
  ufw allow 12394/tcp comment 'Qortal QDN data peers'
  ufw allow 4243/tcp comment 'Qortal Hub Reticulum mesh'
fi

# Install Reticulum into an isolated virtual environment. This is a separate
# system daemon with its own identity/config; it does not overwrite Hub files.
if ! id reticulum >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/reticulum --create-home --shell /usr/sbin/nologin reticulum
fi
install -d -o reticulum -g reticulum -m 0700 /var/lib/reticulum/.reticulum
python3 -m venv /opt/reticulum-venv
/opt/reticulum-venv/bin/python -m pip install --disable-pip-version-check --no-cache-dir rns
chown -R root:root /opt/reticulum-venv
chmod -R a+rX /opt/reticulum-venv

cat > /var/lib/reticulum/.reticulum/config <<'RNSCONFIG'
[reticulum]
enable_transport = No

[logging]
loglevel = 4

[interfaces]
  [[Igorcoin Reticulum TCP uplink]]
    type = TCPClientInterface
    interface_enabled = Yes
    target_host = node.reticulumnet.nl
    target_port = 4242

  [[Local LAN AutoInterface]]
    type = AutoInterface
    interface_enabled = Yes
RNSCONFIG
chown reticulum:reticulum /var/lib/reticulum/.reticulum/config
chmod 0600 /var/lib/reticulum/.reticulum/config

cat > /etc/systemd/system/igorcoin-reticulum.service <<'RNSUNIT'
[Unit]
Description=Igorcoin Reticulum Network Stack
Documentation=https://reticulum.network/manual/using.html
After=network.target
Wants=network.target

[Service]
Type=simple
User=reticulum
Group=reticulum
Environment=HOME=/var/lib/reticulum
Environment=MALLOC_ARENA_MAX=2
ExecStart=/opt/reticulum-venv/bin/rnsd --service
Restart=always
RestartSec=5
StartLimitIntervalSec=0
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/var/lib/reticulum

[Install]
WantedBy=multi-user.target
RNSUNIT

systemctl --root=/ enable igorcoin-reticulum.service

# Enable firewall and security services in the installed system image.
systemctl --root=/ enable ufw.service
systemctl --root=/ enable apparmor.service
# The Igorcoin hourly timer owns package-list refresh and unattended installs.
# Disable the standard daily APT timers to avoid overlapping package-manager jobs.
systemctl --root=/ disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl --root=/ enable igorcoin-auto-update.timer
SECURITY
chmod 0755 config/hooks/normal/0900-igorcoin-security.hook.chroot

echo "Embedding the official Qortal Linux installer into the ISO..."
QORTAL_INSTALLER="config/includes.chroot/usr/local/share/igorcoin-qortal-os/Qortal-Setup-Linux.sh"
curl --fail --location --connect-timeout 20 --max-time 180 --retry 5 --retry-all-errors \
  "$QORTAL_INSTALLER_URL" -o "$QORTAL_INSTALLER"
test -s "$QORTAL_INSTALLER"
bash -n "$QORTAL_INSTALLER"
chmod 0644 "$QORTAL_INSTALLER"

# Optional personal wallet backup: only an age-encrypted file may enter the ISO.
# Plain JSON wallet exports are deliberately rejected.
WALLET_SOURCE="$SCRIPT_DIR/wallet/Igorcoin-Wallet.json.age"
WALLET_TARGET="config/includes.chroot/usr/local/share/igorcoin-qortal-os/Igorcoin-Wallet.json.age"
if [[ -f "$WALLET_SOURCE" ]]; then
  if ! head -n 1 "$WALLET_SOURCE" | grep -Fxq 'age-encryption.org/v1'; then
    echo "Wallet backup is not an age-encrypted file; refusing to add it to the ISO." >&2
    exit 1
  fi
  install -m 0644 "$WALLET_SOURCE" "$WALLET_TARGET"
  echo "Encrypted Igorcoin wallet backup included (age-encrypted; passphrase not included)."
else
  echo "No encrypted wallet backup found; building without personal wallet data."
fi

cat > config/includes.chroot/usr/local/bin/igor-install-qortal <<'INSTALL'
#!/usr/bin/env bash
set -Eeuo pipefail
INSTALLER="/usr/local/share/igorcoin-qortal-os/Qortal-Setup-Linux.sh"

if [[ ! -s "$INSTALLER" ]]; then
  echo "The Qortal Linux installer is missing from this ISO." >&2
  exit 1
fi

echo "Starting the official Qortal Linux installer."
echo "Source: https://link.qortal.dev/linux-script"
echo "The installer runs as the logged-in user and requests sudo when needed."
exec bash "$INSTALLER"
INSTALL
chmod 0755 config/includes.chroot/usr/local/bin/igor-install-qortal

cat > config/includes.chroot/usr/local/bin/igor-qortal-first-login <<'FIRSTLOGIN'
#!/usr/bin/env bash
set -Eeuo pipefail

MARKER="$HOME/.local/state/igor-qortal-os/official-installer-completed"
[[ -e "$MARKER" ]] && exit 0

mkdir -p "$(dirname "$MARKER")"
if command -v konsole >/dev/null 2>&1; then
  if konsole --hold -e /bin/bash -lc '/usr/local/bin/igor-install-qortal'; then
    touch "$MARKER"
    if [[ -s /usr/local/share/igorcoin-qortal-os/Igorcoin-Wallet.json.age ]]; then
      konsole --hold -e /usr/local/bin/igorcoin-restore-wallet
    fi
  else
    echo "Qortal setup did not complete. You can retry from Applications > Install Qortal."
  fi
fi
FIRSTLOGIN
chmod 0755 config/includes.chroot/usr/local/bin/igor-qortal-first-login

cat > config/includes.chroot/usr/local/bin/igorcoin-restore-wallet <<'WALLET'
#!/usr/bin/env bash
set -Eeuo pipefail

BUNDLED="/usr/local/share/igorcoin-qortal-os/Igorcoin-Wallet.json.age"
TARGET_DIR="$HOME/qortal"
ENCRYPTED_TARGET="$TARGET_DIR/Igorcoin-Wallet.json.age"
RESTORED_TARGET="$TARGET_DIR/Igorcoin-Wallet.json"

if [[ ! -d "$TARGET_DIR" ]]; then
  kdialog --error "Qortal Core kausta ei leitud. Paigalda Qortal enne rahakoti taastamist."
  exit 1
fi

if [[ -s "$BUNDLED" ]]; then
  SOURCE="$BUNDLED"
else
  SOURCE="$(kdialog --getopenfilename "$HOME" "*.age|Krüpteeritud Igorcoin wallet (*.age)" --title "Vali krüpteeritud walleti varukoopia")" || true
  [[ -n "$SOURCE" ]] || exit 0
fi

if [[ -e "$RESTORED_TARGET" ]]; then
  kdialog --error "Fail $RESTORED_TARGET on juba olemas. Seda ei kirjutata üle."
  exit 1
fi

if ! head -n 1 "$SOURCE" | grep -Fxq 'age-encryption.org/v1'; then
  kdialog --error "Valitud fail ei paista olevat age-krüpteeritud varukoopia."
  exit 1
fi

mkdir -p "$TARGET_DIR"
if ! kdialog --yesno "Valitud walleti varukoopia taastatakse kausta $TARGET_DIR. Järgmises aknas sisesta krüpteerimisparool. Jätkame?"; then
  exit 0
fi

# age reads the passphrase securely from the interactive terminal, not from
# command-line arguments, environment variables, or an ISO-stored secret.
if konsole --hold -e age --decrypt --output "$RESTORED_TARGET" "$SOURCE"; then
  chmod 0600 "$RESTORED_TARGET"
  if [[ "$SOURCE" != "$BUNDLED" ]]; then
    install -m 0600 "$SOURCE" "$ENCRYPTED_TARGET"
  fi
  kdialog --msgbox "Walleti varukoopia taastati edukalt kausta $TARGET_DIR."
else
  rm -f "$RESTORED_TARGET"
  kdialog --error "Dekrüpteerimine ebaõnnestus. Kontrolli parooli ja proovi uuesti."
  exit 1
fi
WALLET
chmod 0755 config/includes.chroot/usr/local/bin/igorcoin-restore-wallet

cat > config/includes.chroot/usr/local/bin/igorcoin-encrypt-wallet <<'ENCRYPT'
#!/usr/bin/env bash
set -Eeuo pipefail

DEST_DIR="$HOME/igorcoin-wallet-export"
mkdir -p "$DEST_DIR"
SOURCE="$(kdialog --getopenfilename "$HOME" "*.json|Qortal wallet JSON (*.json)" --title "Vali oma Qortali walleti varukoopia")" || true
[[ -n "$SOURCE" ]] || exit 0
if ! kdialog --yesno "Valitud fail krüpteeritakse eraldi parooliga. Algset faili ei muudeta. Krüpteeritud koopia salvestatakse kausta $DEST_DIR. Jätkame?"; then
  exit 0
fi
BASENAME="Igorcoin-Wallet.json.age"
if [[ -e "$DEST_DIR/$BASENAME" ]]; then
  kdialog --error "Krüpteeritud fail on juba olemas. Muuda või varunda see enne uuesti loomist."
  exit 1
fi
if konsole --hold -e age --passphrase --output "$DEST_DIR/$BASENAME" "$SOURCE"; then
  chmod 0600 "$DEST_DIR/$BASENAME"
  kdialog --msgbox "Valmis! Krüpteeritud fail asub kaustas $DEST_DIR. Hoia parool alles. Ära jaga ega laadi üles algset JSON-faili."
else
  rm -f "$DEST_DIR/$BASENAME"
  kdialog --error "Krüpteerimine ebaõnnestus."
  exit 1
fi
ENCRYPT
chmod 0755 config/includes.chroot/usr/local/bin/igorcoin-encrypt-wallet

cat > config/includes.chroot/usr/share/applications/igorcoin-encrypt-wallet.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Prepare Encrypted Igorcoin Wallet
Name[et]=Valmista ette krüpteeritud Igorcoin rahakott
Comment=Encrypt a wallet backup for optional inclusion in the ISO
Comment[et]=Krüpteeri rahakoti varukoopia ISO jaoks
Exec=/usr/local/bin/igorcoin-encrypt-wallet
Icon=folder-encrypted
Terminal=false
Categories=Network;System;
DESKTOP


cat > config/includes.chroot/usr/share/applications/igorcoin-restore-wallet.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Restore Igorcoin Wallet
Name[et]=Taasta Igorcoin rahakott
Comment=Restore an encrypted wallet backup using graphical dialogs
Comment[et]=Taasta krüpteeritud rahakoti varukoopia graafiliste akende abil
Exec=/usr/local/bin/igorcoin-restore-wallet
Icon=wallet-open
Terminal=false
Categories=Network;System;
DESKTOP

cat > config/includes.chroot/etc/xdg/autostart/igor-qortal-first-login.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Qortal first-login setup
Name[et]=Qortali esmakäivitus
Comment=Run the official Qortal Linux installer once after first login
Comment[et]=Käivita esimesel sisselogimisel ametlik Qortali Linuxi paigaldaja
Exec=/usr/local/bin/igor-qortal-first-login
OnlyShowIn=KDE;
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP

cat > config/includes.chroot/usr/share/applications/igor-install-qortal.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install Qortal
Name[et]=Paigalda Qortal
Comment=Run the official Qortal Linux installer
Comment[et]=Käivita ametlik Qortali Linuxi paigaldaja
Exec=konsole --hold -e /usr/local/bin/igor-install-qortal
Icon=applications-internet
Terminal=false
Categories=Network;System;
DESKTOP

cat > config/includes.chroot/usr/share/icons/hicolor/scalable/apps/igorcoin-reticulum.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <g fill="none" stroke="#21b7d5" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
    <path d="M32 12 L13 46 L51 46 Z"/>
    <path d="M32 12 L32 31 M13 46 L32 31 L51 46"/>
  </g>
  <g fill="#21b7d5" stroke="#0b1720" stroke-width="2">
    <circle cx="32" cy="12" r="7"/>
    <circle cx="13" cy="46" r="7"/>
    <circle cx="51" cy="46" r="7"/>
    <circle cx="32" cy="31" r="5"/>
  </g>
</svg>
SVG

cat > config/includes.chroot/usr/local/bin/igorcoin-reticulum <<'RNSCTL'
#!/usr/bin/env bash
set -Eeuo pipefail
SERVICE="igorcoin-reticulum.service"
case "${1:-status}" in
  status)
    systemctl --no-pager --full status "$SERVICE"
    ;;
  start)
    sudo systemctl start "$SERVICE"
    ;;
  stop)
    sudo systemctl stop "$SERVICE"
    ;;
  restart)
    sudo systemctl restart "$SERVICE"
    ;;
  logs)
    journalctl -u "$SERVICE" -n 100 --no-pager
    ;;
  *)
    echo "Usage: igorcoin-reticulum {status|start|stop|restart|logs}" >&2
    exit 2
    ;;
esac
RNSCTL
chmod 0755 config/includes.chroot/usr/local/bin/igorcoin-reticulum

cat > config/includes.chroot/usr/local/bin/igorcoin-network-tray <<'PY'
#!/usr/bin/python3
import os
import shutil
import subprocess
import sys

from PyQt6.QtCore import QTimer
from PyQt6.QtGui import QAction, QIcon
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

APP = QApplication(sys.argv)
APP.setQuitOnLastWindowClosed(False)

def command_exists(name):
    return shutil.which(name) is not None

def run_detached(*args):
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    except Exception:
        pass

def core_status():
    try:
        result = subprocess.run(
            ["bash", "-lc", "ss -lnt"],
            capture_output=True, text=True, timeout=2, check=False
        )
        return "RUNNING" if ":12391 " in result.stdout else "NOT DETECTED"
    except Exception:
        return "UNKNOWN"

def reticulum_status():
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "igorcoin-reticulum.service"],
            capture_output=True, text=True, timeout=2, check=False
        )
        return "RUNNING" if result.returncode == 0 else "OFFLINE"
    except Exception:
        return "UNKNOWN"

def open_hub():
    # Prefer the desktop launcher installed by the official Qortal Hub setup.
    for desktop in (
        os.path.expanduser("~/.local/share/applications/qortal-hub.desktop"),
        "/usr/share/applications/qortal-hub.desktop",
        "/usr/share/applications/Qortal-Hub.desktop",
    ):
        if os.path.isfile(desktop):
            run_detached("gtk-launch", os.path.basename(desktop)[:-8])
            return
    for binary in ("qortal-hub", "Qortal-Hub", "qortalhub"):
        if command_exists(binary):
            run_detached(binary)
            return
    run_detached("xdg-open", "applications:")

def open_network_settings():
    run_detached("kcmshell6", "kcm_networkmanagement")

def open_hub_settings():
    open_hub()

tray = QSystemTrayIcon(QIcon("/usr/share/icons/hicolor/scalable/apps/igorcoin-reticulum.svg"))
tray.setToolTip("Igorcoin Qortal Network")
menu = QMenu()

core_action = QAction("Qortal Core: checking…", menu)
core_action.setEnabled(False)
menu.addAction(core_action)

reticulum_action = QAction("Reticulum: checking…", menu)
reticulum_action.setEnabled(False)
menu.addAction(reticulum_action)

menu.addSeparator()
hub_action = QAction("Open Qortal Hub", menu)
hub_action.triggered.connect(open_hub)
menu.addAction(hub_action)

hub_settings_action = QAction("Qortal node settings (inside Hub)", menu)
hub_settings_action.triggered.connect(open_hub_settings)
menu.addAction(hub_settings_action)

wifi_action = QAction("Wi-Fi and network settings", menu)
wifi_action.triggered.connect(open_network_settings)
menu.addAction(wifi_action)

menu.addSeparator()
quit_action = QAction("Close Qortal Network indicator", menu)
quit_action.triggered.connect(APP.quit)
menu.addAction(quit_action)

tray.setContextMenu(menu)
tray.show()

def refresh_status():
    core_action.setText("Qortal Core: " + core_status())
    reticulum_action.setText("Reticulum: " + reticulum_status())
    tray.setToolTip("Igorcoin Qortal Network | Core " + core_status() +
                    " | Reticulum " + reticulum_status())

timer = QTimer()
timer.timeout.connect(refresh_status)
timer.start(5000)
refresh_status()

sys.exit(APP.exec())
PY
chmod 0755 config/includes.chroot/usr/local/bin/igorcoin-network-tray

cat > config/includes.chroot/etc/xdg/autostart/igorcoin-network-tray.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Igorcoin Qortal Network
Name[et]=Igorcoin Qortali võrk
Comment=Qortal Core and Reticulum status beside the network tray
Comment[et]=Qortal Core'i ja Reticulumi olek süsteemisalves
Exec=/usr/local/bin/igorcoin-network-tray
Icon=igorcoin-reticulum
Terminal=false
OnlyShowIn=KDE;
X-GNOME-Autostart-enabled=true
DESKTOP

cat > config/includes.chroot/usr/share/applications/igor-qortal-os-info.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Igorcoin Qortal OS information
Name[et]=Igorcoin Qortal OS teave
Comment=Debian 13 Trixie with the official Qortal Linux installer included
Exec=konsole -e bash -lc 'cat /etc/os-release; echo; echo "Official Qortal installer: /usr/local/bin/igor-install-qortal"; read -rp "Press Enter to close..."'
Icon=help-about
Terminal=false
Categories=System;
DESKTOP

lb build --verbose

ISO_FILE="$(find . -maxdepth 1 -type f -name '*.iso' -print -quit)"
if [[ -z "$ISO_FILE" || ! -s "$ISO_FILE" ]]; then
  echo "ISO build failed: no ISO image was produced." >&2
  exit 1
fi

mkdir -p "$(dirname -- "$OUTPUT_ISO")"
cp -- "$ISO_FILE" "$OUTPUT_ISO"
echo "Igorcoin Qortal OS Debian ${DEBIAN_POINT_RELEASE} baseline ISO ready: $OUTPUT_ISO"
ISO_BYTES="$(stat -c '%s' "$OUTPUT_ISO")"
ISO_GIB="$(awk -v bytes="$ISO_BYTES" 'BEGIN { printf "%.2f", bytes / 1024 / 1024 / 1024 }')"
ISO_GB="$(awk -v bytes="$ISO_BYTES" 'BEGIN { printf "%.2f", bytes / 1000000000 }')"
echo "ISO size: $ISO_GB GB decimal ($ISO_GIB GiB; $ISO_BYTES bytes)"
if (( ISO_BYTES > 2300000000 )); then
  echo "WARNING: ISO exceeds the 2.3 GB target. Review the package list before release." >&2
else
  echo "ISO is within the 2.3 GB target."
fi
