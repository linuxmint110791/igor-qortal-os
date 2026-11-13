#!/usr/bin/env bash
set -Eeuo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "Run as root: sudo bash $0"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$SCRIPT_DIR/build-trixie}"
OUTPUT_ISO="${OUTPUT_ISO:-$SCRIPT_DIR/igorcoin-qortal-os-debian13-amd64.iso}"
case "$BUILD_DIR" in ""|"/"|"$SCRIPT_DIR"|"$HOME"|"/home"|"/root") echo "Refusing unsafe build directory: $BUILD_DIR" >&2; exit 1;; esac
if [[ "$OUTPUT_ISO" == "$BUILD_DIR"* ]]; then echo "Output ISO must be outside build directory." >&2; exit 1; fi

apt-get update
apt-get install -y --no-install-recommends live-build debootstrap curl wget ca-certificates xorriso squashfs-tools dosfstools mtools grub-pc-bin grub-efi-amd64-bin unzip
rm -rf -- "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

lb config --mode debian --distribution trixie --architectures amd64 --archive-areas "main contrib non-free non-free-firmware" --binary-images iso-hybrid --apt-recommends true --apt-indices true --bootappend-live "boot=live components quiet splash"

mkdir -p config/package-lists config/includes.chroot/opt/igorcoin-qortal-os config/includes.chroot/usr/local/bin config/includes.chroot/usr/share/applications config/includes.chroot/etc/xdg/autostart

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
ffmpeg
yt-dlp
fastfetch
pciutils
usbutils
iproute2
iputils-ping
openjdk-21-jre-headless
libfuse2t64
jq
rsync
imagemagick
desktop-file-utils
firmware-linux
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
firmware-mediatek
firmware-atheros
firmware-brcm80211
PACKAGES

echo "Downloading official Qortal components for inclusion in the ISO..."
QORTAL_DIR="$BUILD_DIR/config/includes.chroot/opt/igorcoin-qortal-os"
curl --fail --location --retry 5 --retry-all-errors --output "$QORTAL_DIR/qortal.zip" "https://github.com/Qortal/qortal/releases/latest/download/qortal.zip"
curl --fail --location --retry 5 --retry-all-errors --output "$QORTAL_DIR/Qortal-Hub.AppImage" "https://github.com/Qortal/Qortal-Hub/releases/latest/download/Qortal-Hub.AppImage"
curl --fail --location --retry 5 --retry-all-errors --output "$QORTAL_DIR/Qortal-UI.AppImage" "https://github.com/Qortal/qortal-ui/releases/latest/download/Qortal-Setup-amd64.AppImage"
test -s "$QORTAL_DIR/qortal.zip"
test -s "$QORTAL_DIR/Qortal-Hub.AppImage"
test -s "$QORTAL_DIR/Qortal-UI.AppImage"
chmod 0644 "$QORTAL_DIR/qortal.zip"
chmod 0755 "$QORTAL_DIR/Qortal-Hub.AppImage" "$QORTAL_DIR/Qortal-UI.AppImage"

cat > config/includes.chroot/usr/local/bin/igor-install-qortal <<'INSTALL'
#!/usr/bin/env bash
set -Eeuo pipefail
SOURCE="/opt/igorcoin-qortal-os"
[[ -s "$SOURCE/qortal.zip" && -s "$SOURCE/Qortal-Hub.AppImage" && -s "$SOURCE/Qortal-UI.AppImage" ]] || {
  echo "Qortal installation files are missing from this ISO." >&2
  exit 1
}
mkdir -p "$HOME"
if [[ ! -d "$HOME/qortal" ]]; then
  echo "Installing Qortal Core from the ISO..."
  unzip -oq "$SOURCE/qortal.zip" -d "$HOME"
fi
mkdir -p "$HOME/qortal-hub" "$HOME/qortal-ui" "$HOME/.local/share/applications"
install -m 0755 "$SOURCE/Qortal-Hub.AppImage" "$HOME/qortal-hub/Qortal-Hub"
install -m 0755 "$SOURCE/Qortal-UI.AppImage" "$HOME/qortal-ui/Qortal-UI"
if [[ -d "$HOME/qortal" ]]; then chmod +x "$HOME/qortal/"*.sh 2>/dev/null || true; fi

cat > "$HOME/.local/share/applications/qortal-core.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Qortal Core
Comment=Start the Qortal blockchain node
Exec=konsole --hold -e /bin/bash -lc "cd $HOME/qortal && ./start.sh"
Icon=network-server
Terminal=false
Categories=Network;
DESKTOP

cat > "$HOME/.local/share/applications/qortal-hub.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Qortal Hub
Comment=Open Qortal Hub
Exec=sh -c "$HOME/qortal-hub/Qortal-Hub"
Icon=applications-internet
Terminal=false
Categories=Network;
DESKTOP

cat > "$HOME/.local/share/applications/qortal-ui.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Qortal UI
Comment=Open the Qortal desktop interface installer
Exec=sh -c "$HOME/qortal-ui/Qortal-UI"
Icon=applications-internet
Terminal=false
Categories=Network;
DESKTOP

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
echo
echo "Qortal Core, Qortal Hub and Qortal UI are installed locally."
echo "Find them in the Applications menu. Start Qortal Core first."
echo "The blockchain data/bootstrap is not included; the node downloads it when started."
INSTALL
chmod 0755 config/includes.chroot/usr/local/bin/igor-install-qortal

cat > config/includes.chroot/usr/local/bin/igor-qortal-first-login <<'FIRSTLOGIN'
#!/usr/bin/env bash
set -Eeuo pipefail
MARKER="$HOME/.local/state/igor-qortal-os/qortal-components-installed"
[[ -e "$MARKER" ]] && exit 0
mkdir -p "$(dirname "$MARKER")"
if command -v konsole >/dev/null 2>&1; then
  konsole --hold -e /usr/local/bin/igor-install-qortal
  mkdir -p "$(dirname "$MARKER")"
  touch "$MARKER"
fi
FIRSTLOGIN
chmod 0755 config/includes.chroot/usr/local/bin/igor-qortal-first-login

cat > config/includes.chroot/etc/xdg/autostart/igor-qortal-first-login.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Qortal first-login setup
Name[et]=Qortali esmakäivitus
Comment=Install the Qortal applications bundled in this ISO
Exec=/usr/local/bin/igor-qortal-first-login
OnlyShowIn=KDE;
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP

cat > config/includes.chroot/usr/share/applications/igor-install-qortal.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install Qortal components
Name[et]=Paigalda Qortali komponendid
Comment=Install the Qortal applications bundled in this ISO
Comment[et]=Paigalda ISO-s kaasas olevad Qortali rakendused
Exec=konsole --hold -e /usr/local/bin/igor-install-qortal
Icon=applications-internet
Terminal=false
Categories=Network;System;
DESKTOP

cat > config/includes.chroot/usr/share/applications/igor-qortal-os-info.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Igorcoin Qortal OS information
Name[et]=Igorcoin Qortal OS teave
Comment=Debian 13 Trixie with Qortal applications included
Exec=konsole -e bash -lc 'cat /etc/os-release; echo; echo "Bundled: Qortal Core, Qortal Hub, Qortal UI"; read -rp "Press Enter to close..."'
Icon=help-about
Terminal=false
Categories=System;
DESKTOP

lb build
ISO_FILE="$(find . -maxdepth 1 -type f -name '*.iso' -print -quit)"
if [[ -z "$ISO_FILE" || ! -s "$ISO_FILE" ]]; then echo "ISO build failed: no ISO image was produced." >&2; exit 1; fi
mkdir -p "$(dirname -- "$OUTPUT_ISO")"
cp -- "$ISO_FILE" "$OUTPUT_ISO"
echo "Igorcoin Qortal OS ISO ready: $OUTPUT_ISO"
du -h "$OUTPUT_ISO"
