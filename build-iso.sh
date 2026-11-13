#!/usr/bin/env bash
set -Eeuo pipefail
if [[ \${EUID} -ne 0 ]]; then echo "Run as root: sudo bash $0"; exit 1; fi
export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="\${BUILD_DIR:-$SCRIPT_DIR/build-trixie}"
OUTPUT_ISO="\${OUTPUT_ISO:-$SCRIPT_DIR/igorcoin-qortal-os-debian13-amd64.iso}"
case "$BUILD_DIR" in ""|"/"|"$SCRIPT_DIR"|"$HOME"|"/home"|"/root") echo "Refusing unsafe build directory: $BUILD_DIR" >&2; exit 1;; esac
if [[ "$OUTPUT_ISO" == "$BUILD_DIR"* ]]; then echo "Output ISO must be outside build directory." >&2; exit 1; fi
apt-get update
apt-get install -y --no-install-recommends live-build debootstrap curl wget ca-certificates xorriso squashfs-tools dosfstools mtools grub-pc-bin grub-efi-amd64-bin
rm -rf -- "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
lb config --mode debian --distribution trixie --architectures amd64 --archive-areas "main contrib non-free non-free-firmware" --binary-images iso-hybrid --apt-recommends true --apt-indices true --bootappend-live "boot=live components quiet splash"
mkdir -p config/package-lists config/includes.chroot/usr/local/bin config/includes.chroot/usr/share/applications config/includes.chroot/etc/xdg/autostart
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
firmware-linux
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
firmware-mediatek
firmware-atheros
firmware-brcm80211
PACKAGES
cat > config/includes.chroot/usr/local/bin/igor-install-qortal <<'QORTAL'
#!/usr/bin/env bash
set -Eeuo pipefail
URL="https://link.qortal.dev/linux-script"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
echo "Igorcoin Qortal OS — Qortal installer"
echo "Installer source: $URL"
echo "Do not enter your seed phrase on websites or share it with anyone."
read -r -p "Continue? [y/N] " answer
case "$answer" in y|Y|yes|YES) ;; *) echo "Cancelled."; exit 0;; esac
if command -v curl >/dev/null 2>&1; then curl --fail --location --silent --show-error "$URL" -o "$TMP"; else wget -qO "$TMP" "$URL"; fi
bash "$TMP"
QORTAL
chmod 0755 config/includes.chroot/usr/local/bin/igor-install-qortal
cat > config/includes.chroot/usr/local/bin/igor-qortal-first-login <<'FIRSTLOGIN'
#!/usr/bin/env bash
set -Eeuo pipefail
MARKER="$HOME/.local/state/igor-qortal-os/qortal-installer-started"
[[ -e "$MARKER" ]] && exit 0
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"
if command -v konsole >/dev/null 2>&1; then konsole --hold -e /usr/local/bin/igor-install-qortal; fi
FIRSTLOGIN
chmod 0755 config/includes.chroot/usr/local/bin/igor-qortal-first-login
cat > config/includes.chroot/etc/xdg/autostart/igor-qortal-first-login.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Qortal first-login setup
Name[et]=Qortali esmakäivitus
Comment=Start the Qortal installer once after the first desktop login
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
Comment=Install Qortal Core and related components
Comment[et]=Paigalda Qortal Core ja vajalikud komponendid
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
Comment=Debian 13 Trixie with the Qortal installer included
Exec=konsole -e bash -lc 'cat /etc/os-release; echo; echo "Qortal installer: /usr/local/bin/igor-install-qortal"; read -rp "Press Enter to close..."'
Icon=help-about
Terminal=false
Categories=System;
DESKTOP
lb build
ISO_FILE="$(find . -maxdepth 1 -type f -name '*.iso' -print -quit)"
if [[ -z "$ISO_FILE" || ! -s "$ISO_FILE" ]]; then echo "ISO build failed: no ISO image was produced." >&2; exit 1; fi
mkdir -p "$(dirname -- "$OUTPUT_ISO")"
cp -- "$ISO_FILE" "$OUTPUT_ISO"
sha256sum "$OUTPUT_ISO" > "$OUTPUT_ISO.sha256"
echo "Igorcoin Qortal OS ISO ready: $OUTPUT_ISO"
du -h "$OUTPUT_ISO"
cat "$OUTPUT_ISO.sha256"
