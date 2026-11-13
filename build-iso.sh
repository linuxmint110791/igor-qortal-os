#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build-trixie}"
OUTPUT_ISO="${OUTPUT_ISO:-$SCRIPT_DIR/igorcoin-qortal-os-debian13-amd64.iso}"
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

apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap curl wget ca-certificates xorriso squashfs-tools \
  dosfstools mtools grub-pc-bin grub-efi-amd64-bin

rm -rf -- "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

lb config \
  --mode debian \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid \
  --apt-recommends true \
  --apt-indices true \
  --bootappend-live "boot=live components quiet splash"

mkdir -p \
  config/package-lists \
  config/includes.chroot/usr/local/share/igorcoin-qortal-os \
  config/includes.chroot/usr/local/bin \
  config/includes.chroot/usr/share/applications \
  config/includes.chroot/etc/xdg/autostart \
  config/includes.chroot/etc/ssh/sshd_config.d \
  config/includes.chroot/etc/apt/apt.conf.d \
  config/includes.chroot/etc/default \
  config/includes.chroot/etc/ufw \
  config/hooks/normal

cat > config/package-lists/igorcoin-qortal-os.list.chroot <<'PACKAGES'
kde-plasma-desktop
plasma-workspace-wayland
kwin-wayland
sddm
xwayland
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
zlib1g-dev
openjdk-21-jre-headless
libfuse2t64
desktop-file-utils
xdg-utils
ffmpeg
yt-dlp
fastfetch
age
kdialog
python3-pyqt6
kwalletmanager
libpam-kwallet5
libsecret-tools
ufw
unattended-upgrades
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
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT

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

# Enable firewall and security services in the installed system image.
systemctl --root=/ enable ufw.service
systemctl --root=/ enable apparmor.service
systemctl --root=/ enable apt-daily.timer apt-daily-upgrade.timer

# Ensure unattended-upgrades is enabled even on systems without a desktop prompt.
systemctl --root=/ enable unattended-upgrades.service 2>/dev/null || true
SECURITY
chmod 0755 config/hooks/normal/0900-igorcoin-security.hook.chroot

echo "Embedding the official Qortal Linux installer into the ISO..."
QORTAL_INSTALLER="config/includes.chroot/usr/local/share/igorcoin-qortal-os/Qortal-Setup-Linux.sh"
curl --fail --location --retry 5 --retry-all-errors \
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
            ["pgrep", "-af", "rnsd|reticulum"],
            capture_output=True, text=True, timeout=2, check=False
        )
        return "PROCESS DETECTED" if result.returncode == 0 else "NOT DETECTED"
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

lb build

ISO_FILE="$(find . -maxdepth 1 -type f -name '*.iso' -print -quit)"
if [[ -z "$ISO_FILE" || ! -s "$ISO_FILE" ]]; then
  echo "ISO build failed: no ISO image was produced." >&2
  exit 1
fi

mkdir -p "$(dirname -- "$OUTPUT_ISO")"
cp -- "$ISO_FILE" "$OUTPUT_ISO"
echo "Igorcoin Qortal OS ISO ready: $OUTPUT_ISO"
du -h "$OUTPUT_ISO"
