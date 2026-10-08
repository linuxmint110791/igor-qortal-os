#!/usr/bin/env bash
# ==============================================================================
# Igor-Qortal OS v2
# Debian Sid/Unstable + Cinnamon + Wayland + EFI/Secure Boot support
# Qortal + Arch Distrobox + Reticulum Mesh
# ==============================================================================

set -euo pipefail
# Privacy / telemetry policy: no Debian popularity-contest or other optional
# usage-reporting package is included, and any accidental installation is
# disabled/removed while building the image.


# ==============================================================================
# ROOT CHECK
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "[!] Käivita root-õigustes:"
    echo
    echo "    sudo bash $0"
    echo
    exit 1
fi

# ==============================================================================
# BUILD OPTIONS
# ==============================================================================

BUILD_DIR="${BUILD_DIR:-igor-qortal-os-build}"
OUTPUT_ISO="${OUTPUT_ISO:-igor-qortal-os-v2.iso}"
DISTRO="${DISTRO:-unstable}"
ARCH="${ARCH:-amd64}"
SECURE_BOOT_ARGS=()
BINARY_IMAGE_MODE="iso-hybrid"
if [[ "$ARCH" == "amd64" ]]; then
    SECURE_BOOT_ARGS=(--uefi-secure-boot enable)
elif [[ "$ARCH" == "arm64" || "$ARCH" == "armhf" ]]; then
    BINARY_IMAGE_MODE="hdd"
fi
case "$ARCH" in amd64|arm64|armhf|i386) ;; *) echo "[!] Unsupported ARCH: $ARCH"; exit 1 ;; esac

# 0 = ära lisa kunstlikku paddingut
ISO_PADDING_MB="${ISO_PADDING_MB:-0}"

# Soovi korral RNS TCP/Backbone ühendus.
#
# Näide:
#
# RNS_TCP_HOST=example.org \
# RNS_TCP_PORT=4242 \
# sudo bash build.sh
#
RNS_TCP_HOST="${RNS_TCP_HOST:-}"
RNS_TCP_PORT="${RNS_TCP_PORT:-}"

# Bootloader profile. Debian live-build supports GRUB BIOS (grub-pc),
# GRUB EFI (grub-efi) and Syslinux. A normal ISO uses Syslinux/ISOLINUX;
# GRUB selection is available for HDD images.
BOOTLOADER="${BOOTLOADER:-auto}"
if [[ "$BOOTLOADER" == "auto" ]]; then
    if [[ -t 0 && -t 1 ]]; then
        echo "=================================================="
        echo "       Igor-Qortal OS alglaaduri valik"
        echo "=================================================="
        echo "1) ISO / Syslinux + GRUB EFI (soovituslik)"
        echo "2) ISO / Syslinux ainult"
        echo "3) ISO / GRUB EFI ainult"
        echo "4) Syslinux / HDD image (x86)"
        echo
        read -rp "Valik [1]: " BOOT_CHOICE
        case "${BOOT_CHOICE:-1}" in
            2) BOOTLOADER="iso-syslinux" ;;
            3) BOOTLOADER="iso-grub-efi" ;;
            4) BOOTLOADER="syslinux-hdd" ;;
            *) BOOTLOADER="iso-syslinux-grub" ;;
        esac
    else
        BOOTLOADER="iso-syslinux-grub"
    fi
fi

BOOTLOADER_ARGS=()
case "$BOOTLOADER" in
    iso-syslinux-grub)
        BINARY_IMAGE_MODE="iso-hybrid"
        BOOTLOADER_ARGS=(--bootloaders "syslinux grub-efi")
        ;;
    iso-syslinux)
        BINARY_IMAGE_MODE="iso-hybrid"
        BOOTLOADER_ARGS=(--bootloaders syslinux)
        ;;
    iso-grub-efi)
        BINARY_IMAGE_MODE="iso"
        BOOTLOADER_ARGS=(--bootloaders grub-efi)
        ;;
    syslinux-hdd)
        BINARY_IMAGE_MODE="hdd"
        BOOTLOADER_ARGS=(--bootloaders syslinux)
        if [[ "$ARCH" != "amd64" && "$ARCH" != "i386" ]]; then
            echo "[!] Syslinux HDD režiim on siin ainult x86 jaoks."
            exit 1
        fi
        ;;
    *)
        echo "[!] Tundmatu BOOTLOADER: $BOOTLOADER"
        echo "    Lubatud: iso-syslinux-grub, iso-syslinux, iso-grub-efi, syslinux-hdd"
        exit 1
        ;;
esac

# GRUB EFI requires an EFI-capable image. Secure Boot is enabled only for
# amd64 GRUB EFI builds where Debian signed GRUB/shim packages are present.
if [[ "$BOOTLOADER" == "iso-syslinux-grub" || "$BOOTLOADER" == "iso-grub-efi" ]]; then
    if [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" ]]; then
        SECURE_BOOT_ARGS=(--uefi-secure-boot enable)
    else
        SECURE_BOOT_ARGS=()
    fi
fi

# ==============================================================================
# LOCALE
# ==============================================================================

echo
echo "=================================================="
echo "       Igor-Qortal OS Keele ja Lokaadi Seadistus"
echo "=================================================="
echo
echo "1) Eesti   (et_EE.UTF-8)"
echo "2) English (en_US.UTF-8)"
echo

read -rp "Valik [1]: " LANG_CHOICE

case "${LANG_CHOICE:-1}" in
    2)
        SELECTED_LOCALE="en_US.UTF-8"
        SELECTED_KEYBOARD="us"
        ;;
    *)
        SELECTED_LOCALE="et_EE.UTF-8"
        SELECTED_KEYBOARD="ee"
        ;;
esac

echo
echo "[+] Locale:   $SELECTED_LOCALE"
echo "[+] Keyboard: $SELECTED_KEYBOARD"
echo

# ==============================================================================
# HOST BUILD DEPENDENCIES
# ==============================================================================

if [[ "${SKIP_HOST_DEPS:-0}" != "1" ]]; then
    echo "[+] Paigaldan ISO buildimise tööriistad..."

    apt-get update

    apt-get install -y \
        live-build \
        debootstrap \
        curl \
        wget \
        git \
        xorriso \
        squashfs-tools \
        grub-efi-amd64-bin \
        grub-efi-amd64-signed \
        shim-signed \
        dosfstools \
        mtools
else
    echo "[+] GitHub Actions: hosti build-sõltuvused on workflow poolt juba paigaldatud."
fi

# ==============================================================================
# CLEAN BUILD TREE
# ==============================================================================

rm -rf "$BUILD_DIR"

mkdir -p "$BUILD_DIR"

cd "$BUILD_DIR"

# ==============================================================================
# DEBIAN LIVE CONFIG
# ==============================================================================

echo "[+] Seadistan Debian Live'i..."

lb config \
    --architectures "$ARCH" \
    --distribution "$DISTRO" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --binary-images "$BINARY_IMAGE_MODE" \
    "${BOOTLOADER_ARGS[@]}" \
    "${SECURE_BOOT_ARGS[@]}" \
    --parent-mirror-bootstrap "http://deb.debian.org/debian/" \
    --parent-mirror-chroot "http://deb.debian.org/debian/" \
    --parent-mirror-binary "http://deb.debian.org/debian/" \
    --bootappend-live "boot=live components quiet splash" \
    --apt-recommends false \
    --chroot-squashfs-compression-type xz \
    --chroot-squashfs-compression-level 9

# ==============================================================================
# DIRECTORY STRUCTURE
# ==============================================================================

mkdir -p config/includes.chroot/usr/share/sounds/igor-qortal-os

mkdir -p \
    config/package-lists \
    config/includes.chroot/usr/local/bin \
    config/includes.chroot/etc/systemd/system \
    config/includes.chroot/etc/systemd/system/multi-user.target.wants \
    config/includes.chroot/etc/systemd/user/default.target.wants \
    config/includes.chroot/etc/reticulum \
    config/includes.chroot/etc/default \
    config/includes.chroot/etc/environment.d \
    config/includes.chroot/etc/xdg/autostart \
    config/includes.chroot/usr/share/applications \
    config/includes.chroot/etc/igor-qortal-os \
    config/includes.chroot/etc/igor-qortal-os/linq \
    config/includes.chroot/opt/linq \
    config/includes.chroot/etc/skel/.config/neofetch \
    config/hooks/live

# ==============================================================================
# PACKAGE LIST
# ==============================================================================

cat > config/package-lists/igor-qortal-os.list.chroot <<'EOF'
cinnamon
cinnamon-session
cinnamon-desktop-data
cinnamon-settings-daemon
cinnamon-control-center
cinnamon-screensaver
cinnamon-l10n
nemo
nemo-fileroller
muffin
wayland-protocols
wayland-utils
libwayland-client0
libwayland-server0
gdm3
dconf-cli
pipewire
pipewire-audio
wireplumber
pavucontrol
locales
console-setup
keyboard-configuration
x11-xkb-utils
python3
python3-pip
python3-cryptography
python3-netifaces
python3-pyserial
unattended-upgrades
apt-listchanges
bash
sudo
curl
wget
git
ca-certificates
unzip
zip
yt-dlp
ffmpeg
python3-requests
fwupd
fwupd-signed
coreboot-utils
flashrom
pciutils
usbutils
iproute2
net-tools
iputils-ping
fastfetch
chafa
xterm
linux-image-amd64
EOF

if [[ "$ARCH" == "arm64" ]]; then
  sed -i '/linux-image-amd64/d' config/package-lists/igor-qortal-os.list.chroot
  echo 'linux-image-arm64' >> config/package-lists/igor-qortal-os.list.chroot
elif [[ "$ARCH" == "armhf" ]]; then
  sed -i '/linux-image-amd64/d' config/package-lists/igor-qortal-os.list.chroot
  echo 'linux-image-armmp' >> config/package-lists/igor-qortal-os.list.chroot
elif [[ "$ARCH" == "i386" ]]; then
  sed -i '/linux-image-amd64/d' config/package-lists/igor-qortal-os.list.chroot
  echo 'linux-image-686-pae' >> config/package-lists/igor-qortal-os.list.chroot
fi

if [[ "$ARCH" == "amd64" ]]; then
cat >> config/package-lists/igor-qortal-os.list.chroot <<'ARCHPKG'
shim-signed
grub-efi-amd64-signed
mokutil
efibootmgr
intel-microcode
firmware-iwlwifi
firmware-realtek
firmware-misc-nonfree
grub-pc
grub-efi-amd64-bin
grub-efi-amd64-signed
shim-signed
podman
distrobox
ARCHPKG
elif [[ "$ARCH" == "arm64" ]]; then
cat >> config/package-lists/igor-qortal-os.list.chroot <<'ARCHPKG'
firmware-brcm80211
firmware-atheros
firmware-realtek
firmware-mediatek
u-boot-menu
grub-efi-arm64
grub-efi-arm64-bin
grub-efi-arm64-signed
shim-signed
u-boot-rpi
raspi-firmware
podman
distrobox
ARCHPKG
elif [[ "$ARCH" == "armhf" ]]; then
cat >> config/package-lists/igor-qortal-os.list.chroot <<'ARCHPKG'
firmware-brcm80211
firmware-atheros
firmware-realtek
firmware-mediatek
u-boot-menu
grub-efi-arm
grub-efi-arm-bin
u-boot-rpi
raspi-firmware
podman
distrobox
ARCHPKG
else
cat >> config/package-lists/igor-qortal-os.list.chroot <<'ARCHPKG'
firmware-iwlwifi
firmware-realtek
firmware-misc-nonfree
ARCHPKG
fi

# ==============================================================================
# DEBIAN ROLLING RELEASE (UNSTABLE / SID)
# ==============================================================================
#
# Igorcoin Qortal OS follows Debian Unstable, Debian's continuously updated
# development branch. This is the closest Debian-native model to an Arch-style
# rolling system: packages arrive continuously and there is no major-release
# reinstall.
#
# IMPORTANT: Debian calls this "Unstable" / "Sid", not an officially supported
# rolling-release edition. It is newer and less tested than Debian Testing or
# Stable. The OS therefore uses Debian's own repositories only and performs
# full-upgrades rather than partial upgrades.

mkdir -p config/includes.chroot/etc/apt/sources.list.d
mkdir -p config/includes.chroot/etc/apt/apt.conf.d
mkdir -p config/includes.chroot/etc/systemd/system
mkdir -p config/includes.chroot/etc/systemd/system/timers.target.wants

cat > config/includes.chroot/etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: unstable
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

cat > config/includes.chroot/etc/apt/apt.conf.d/20igor-qortal-os-updates <<'EOF'

// Package lists are refreshed daily. Full upgrades are performed by the
// igor-qortal-os-rolling-update.timer.
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "0";
EOF

cat > config/includes.chroot/etc/systemd/system/igor-qortal-os-rolling-update.service <<'EOF'
[Unit]
Description=Igorcoin Qortal OS Debian Rolling Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/apt-get update
ExecStart=/usr/bin/apt-get -y full-upgrade
ExecStart=/usr/bin/apt-get -y autoremove
ExecStart=/usr/bin/apt-get autoclean
EOF

cat > config/includes.chroot/etc/systemd/system/igor-qortal-os-rolling-update.timer <<'EOF'
[Unit]
Description=30-Minute Igorcoin Qortal OS Debian Rolling Update

[Timer]
OnBootSec=15min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

ln -sf /etc/systemd/system/igor-qortal-os-rolling-update.timer \
    config/includes.chroot/etc/systemd/system/timers.target.wants/igor-qortal-os-rolling-update.timer

# Manual rolling update command:
#   sudo apt update && sudo apt full-upgrade

# ==============================================================================
# KEYBOARD
# ==============================================================================

cat > config/includes.chroot/etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="$SELECTED_KEYBOARD"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# ==============================================================================
# LOCALE
# ==============================================================================

cat > config/includes.chroot/etc/default/locale <<EOF
LANG=$SELECTED_LOCALE
LANGUAGE=$SELECTED_LOCALE
EOF

# ==============================================================================
# LOCALE GENERATION
# ==============================================================================

cat > config/hooks/live/0100-locale.chroot <<EOF
#!/bin/sh

set -e

if grep -q "^# *${SELECTED_LOCALE} UTF-8" /etc/locale.gen; then
    sed -i "s/^# *${SELECTED_LOCALE} UTF-8/${SELECTED_LOCALE} UTF-8/" /etc/locale.gen
elif ! grep -q "^${SELECTED_LOCALE} UTF-8" /etc/locale.gen; then
    echo "${SELECTED_LOCALE} UTF-8" >> /etc/locale.gen
fi

locale-gen

update-locale LANG="${SELECTED_LOCALE}"

EOF

chmod +x config/hooks/live/0100-locale.chroot

# ==============================================================================
# IGOR-QORTAL OS OFFICIAL Q-CUBE LOGO
# ==============================================================================
# Embedded directly into this script; no external logo download is required.

LOGO_B64='''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'''

mkdir -p config/includes.chroot/usr/share/pixmaps

printf '%s' "$LOGO_B64" | base64 -d >     config/includes.chroot/usr/share/pixmaps/igor-qortal-os.png

chmod 0644     config/includes.chroot/usr/share/pixmaps/igor-qortal-os.png

# ==============================================================================
# QORTAL WALLPAPERS
# ==============================================================================
# Official Qortal wallpapers from the Qortal Project press kit.
# The dark Qortal background is the default Cinnamon desktop wallpaper.

QORTAL_WALLPAPER_DIR="config/includes.chroot/usr/share/backgrounds/igor-qortal-os"
mkdir -p "$QORTAL_WALLPAPER_DIR"

QORTAL_MEDIA_BASE="https://wiki.qortal.org/lib/exe/fetch.php?media="

download_qortal_wallpaper() {
    local filename="$1"
    local media_name="$2"

    echo "[+] Laen Qortali taustapildi: $filename"

    curl -fL --retry 3 --retry-delay 2 \
        "${QORTAL_MEDIA_BASE}${media_name}" \
        -o "${QORTAL_WALLPAPER_DIR}/${filename}"
}

download_qortal_wallpaper "qortal-background-dark.jpg" "qortal_background_dark_.jpg"
download_qortal_wallpaper "qortal-background-light.jpg" "qortal_background_light_.jpg"
download_qortal_wallpaper "qortal-background-extra-dark.jpg" "qortal_background_extra_dark_.jpg"
download_qortal_wallpaper "qortal-background-dark-blue.jpg" "49d3e4f0-955d-4bd6-9a14-71c1cbffbb86.jpeg"
download_qortal_wallpaper "qortal-welcome-to-the-future.png" "qortal-thefuture-wallpaper.png"

chmod 0644 "$QORTAL_WALLPAPER_DIR"/*

# ==============================================================================
# CINNAMON DEFAULT WALLPAPER
# ==============================================================================
# Make the official dark Qortal background the desktop default for new users.

mkdir -p \
    config/includes.chroot/etc/dconf/profile \
    config/includes.chroot/etc/dconf/db/local.d

cat > config/includes.chroot/etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF

cat > config/includes.chroot/etc/dconf/db/local.d/00-igor-qortal-wallpaper <<'EOF'
[org/cinnamon/desktop/background]
picture-uri='file:///usr/share/backgrounds/igor-qortal-os/qortal-background-dark.jpg'
picture-uri-dark='file:///usr/share/backgrounds/igor-qortal-os/qortal-background-dark.jpg'
picture-options='zoom'
EOF

cat > config/hooks/live/0400-qortal-wallpaper.chroot <<'EOF'
#!/bin/sh
set -e

if command -v dconf >/dev/null 2>&1; then
    dconf update || true
fi
EOF

chmod +x config/hooks/live/0400-qortal-wallpaper.chroot

# ==============================================================================
# RETICULUM RESILIENCE / MULTI-LINK NETWORKING
# ==============================================================================
mkdir -p config/includes.chroot/etc/reticulum
cat > config/includes.chroot/etc/reticulum/config <<'EOF'
[reticulum]
enable_transport = Yes
share_instance = Yes
panic_on_interface_error = No

[interfaces]
  [[AutoInterface]]
    type = AutoInterface
    enabled = Yes
    mode = full
    group_id = igor-qortal-os
EOF
cat > config/includes.chroot/etc/systemd/system/rnsd.service <<'EOF'
[Unit]
Description=Reticulum resilient mesh networking
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rnsd --config /etc/reticulum
Restart=always
RestartSec=5
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF
mkdir -p config/includes.chroot/etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/rnsd.service config/includes.chroot/etc/systemd/system/multi-user.target.wants/rnsd.service
# ==============================================================================
# RETICULUM CONFIGURATION
# ==============================================================================

echo "[+] Koostan Reticulum konfiguratsiooni..."

cat > config/includes.chroot/etc/reticulum/config <<'EOF'
[reticulum]
enable_transport = Yes
share_instance = Yes
panic_on_interface_error = No

[interfaces]
  [[Igor-Qortal Local Mesh]]
    type = AutoInterface
    enabled = Yes
    mode = full
    group_id = igor-qortal-os
EOF

# Optional Internet backbone/TCP entry point supplied with RNS_TCP_HOST/RNS_TCP_PORT.
if [[ -n "$RNS_TCP_HOST" && -n "$RNS_TCP_PORT" ]]; then
cat >> config/includes.chroot/etc/reticulum/config <<EOF

  [[Igor-Qortal RNS TCP Backbone]]
    type = TCPClientInterface
    enabled = Yes
    target_host = $RNS_TCP_HOST
    target_port = $RNS_TCP_PORT
    mode = boundary
EOF
fi

# ==============================================================================
# OPTIONAL TCP/BACKBONE INTERFACE
# ==============================================================================

if [[ -n "$RNS_TCP_HOST" && -n "$RNS_TCP_PORT" ]]; then

    echo "[+] Lisan RNS TCP ühenduse:"
    echo "    Host: $RNS_TCP_HOST"
    echo "    Port: $RNS_TCP_PORT"

    cat >> config/includes.chroot/etc/reticulum/config <<EOF

  # --------------------------------------------------------------------------
  # Optional RNS TCP interface
  # --------------------------------------------------------------------------

  [[Igor-Qortal RNS TCP]]

    type = TCPClientInterface
    enabled = Yes
    target_host = $RNS_TCP_HOST
    target_port = $RNS_TCP_PORT

EOF

fi

# ==============================================================================
# RETICULUM INSTALL
# ==============================================================================

cat > config/hooks/live/0200-reticulum.chroot <<'EOF'
#!/bin/sh

set -e

echo "=================================================="
echo " Installing Reticulum Network Stack"
echo "=================================================="

python3 -m pip install \
    --break-system-packages \
    --no-cache-dir \
    rns

RNSD_PATH="$(command -v rnsd)"
RNSTATUS_PATH="$(command -v rnstatus)"

echo "[+] rnsd:     $RNSD_PATH"
echo "[+] rnstatus: $RNSTATUS_PATH"

ln -sf "$RNSD_PATH" /usr/local/bin/rnsd
ln -sf "$RNSTATUS_PATH" /usr/local/bin/rnstatus

EOF

chmod +x config/hooks/live/0200-reticulum.chroot

# ==============================================================================
# RETICULUM USER
# ==============================================================================

cat > config/hooks/live/0300-reticulum-user.chroot <<'EOF'
#!/bin/sh

set -e

if ! id reticulum >/dev/null 2>&1; then

    useradd \
        --system \
        --home-dir /var/lib/reticulum \
        --create-home \
        --shell /usr/sbin/nologin \
        reticulum

fi

mkdir -p /var/lib/reticulum

chown -R reticulum:reticulum /var/lib/reticulum

chown root:reticulum /etc/reticulum/config

chmod 0640 /etc/reticulum/config

EOF

chmod +x config/hooks/live/0300-reticulum-user.chroot

# ==============================================================================
# RETICULUM SYSTEMD SERVICE
# ==============================================================================

cat > config/includes.chroot/etc/systemd/system/rnsd.service <<'EOF'

[Unit]
Description=Reticulum Network Stack
Documentation=https://reticulum.network/manual/using.html

Wants=network-online.target
After=network-online.target

[Service]

Type=simple

User=reticulum
Group=reticulum

ExecStart=/usr/local/bin/rnsd --config /etc/reticulum --service

Restart=always
RestartSec=3

NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full

[Install]

WantedBy=multi-user.target

EOF

ln -sf \
    /etc/systemd/system/rnsd.service \
    config/includes.chroot/etc/systemd/system/multi-user.target.wants/rnsd.service

# ==============================================================================
# RNS STATUS
# ==============================================================================

cat > config/includes.chroot/usr/local/bin/qortal-rns-status <<'EOF'

#!/usr/bin/env bash

echo
echo "=================================================="
echo "       Igor-Qortal OS - Reticulum Status"
echo "=================================================="
echo

if systemctl is-active --quiet rnsd; then
    echo "Reticulum daemon : ACTIVE"
else
    echo "Reticulum daemon : INACTIVE"
fi

echo

if command -v rnstatus >/dev/null 2>&1; then
    rnstatus --config /etc/reticulum
else
    echo "[!] rnstatus ei ole saadaval."
fi

echo

EOF

chmod +x config/includes.chroot/usr/local/bin/qortal-rns-status

# ==============================================================================
# LINQ -> QORTAL VIDEO SYNC
# ==============================================================================
# LinQ is integrated as a first-class Qortal OS service.
#
# Behaviour:
#   - starts automatically with the graphical user session
#   - waits for Qortal Hub to be running
#   - launches the installed LinQ engine only after the Qortal desktop is up
#   - keeps the existing LinQ configuration in /etc/igor-qortal-os/linq
#   - publisher defaults to igorcoin
#
# The wallet seed/private key is NOT stored in the ISO. Qortal Core deliberately
# does not store private keys; Qortal Hub keeps the encrypted wallet and signs
# transactions. This keeps the OS image from containing wallet secrets.

cat > config/includes.chroot/etc/igor-qortal-os/linq/linq.conf <<'EOF'
# Igor-Qortal OS LinQ configuration
PUBLISHER_NAME="igorcoin"
QUBE_CATEGORY="26"
MAX_VIDEO_SIZE_MB="2048"
POLL_INTERVAL_MINUTES="30"

# Optional: one YouTube channel URL per line.
# Example:
# https://www.youtube.com/@example
CHANNELS_FILE="/etc/igor-qortal-os/linq/channels.txt"

# LinQ engine entry point. The wrapper checks these locations in order:
# 1) LINQ_COMMAND environment variable
# 2) /opt/linq/linq
# 3) /opt/linq/linq-yt-subs
# 4) /usr/local/bin/linq
LINQ_COMMAND=""
EOF

cat > config/includes.chroot/etc/igor-qortal-os/linq/channels.txt <<'EOF'
# Add YouTube channel URLs here, one per line.
# LinQ will monitor these channels and publish new videos to Q-Tube.
EOF

cat > config/includes.chroot/usr/local/bin/igor-linq-qortal-sync <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/igor-qortal-os/linq/linq.conf"

if [[ -r "$CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG"
else
    echo "[LinQ] Configuration missing: $CONFIG" >&2
    exit 1
fi

find_linq() {
    if [[ -n "${LINQ_COMMAND:-}" && -x "${LINQ_COMMAND}" ]]; then
        printf '%s\n' "$LINQ_COMMAND"
        return 0
    fi

    for candidate in         /opt/linq/linq         /opt/linq/linq-yt-subs         /usr/local/bin/linq
    do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

echo "[LinQ] Igor-Qortal OS video synchronisation starting."
echo "[LinQ] Publisher: ${PUBLISHER_NAME:-igorcoin}"
echo "[LinQ] Category:  ${QUBE_CATEGORY:-26}"
echo "[LinQ] Max video: ${MAX_VIDEO_SIZE_MB:-2048} MB"

# Qortal Hub is the wallet/UI layer. Do not attempt to copy wallet secrets into
# the service. Start the sync only once the Hub desktop process is present.
while ! pgrep -f 'Qortal-Hub|qortal-hub|Qortal Hub' >/dev/null 2>&1; do
    sleep 5
done

echo "[LinQ] Qortal Hub detected."

if ! LINQ_BIN="$(find_linq)"; then
    echo "[LinQ] LinQ engine is not installed yet."
    echo "[LinQ] Expected: /opt/linq/linq"
    echo "[LinQ] The service will keep waiting for the LinQ engine."
    while ! LINQ_BIN="$(find_linq)"; do
        sleep 30
    done
fi

echo "[LinQ] Engine: $LINQ_BIN"

exec "$LINQ_BIN"
EOF
chmod +x config/includes.chroot/usr/local/bin/igor-linq-qortal-sync

cat > config/includes.chroot/etc/systemd/user/igor-linq-qortal-sync.service <<'EOF'
[Unit]
Description=Igor-Qortal OS LinQ -> Q-Tube video synchronisation
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/igor-linq-qortal-sync
Restart=always
RestartSec=10
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=default.target
EOF

mkdir -p config/includes.chroot/etc/systemd/user/default.target.wants
ln -sf /etc/systemd/user/igor-linq-qortal-sync.service     config/includes.chroot/etc/systemd/user/default.target.wants/igor-linq-qortal-sync.service

cat > config/includes.chroot/usr/share/applications/linq-qortal-sync.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=LinQ → Qortal Video Sync
Comment=Synchronise new videos to Q-Tube after Qortal Hub starts
Exec=systemctl --user start igor-linq-qortal-sync.service
Icon=video-x-generic
Terminal=false
Categories=Network;AudioVideo;
EOF

# ==============================================================================
# QORTAL OS INTEGRATED SESSION
# ==============================================================================
# Qortal is the identity/application layer of Igor-Qortal OS.
# Linux starts the local Qortal Core and Qortal Hub automatically.
# Wallet credentials remain inside Qortal Hub and are never copied into Linux
# authentication files.

mkdir -p config/includes.chroot/etc/systemd/system
mkdir -p config/includes.chroot/usr/share/applications
mkdir -p config/includes.chroot/etc/xdg/autostart

cat > config/includes.chroot/etc/systemd/system/igor-qortal-stack.service <<'EOF'
[Unit]
Description=Igor-Qortal OS integrated Qortal stack
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl start qortal.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/igor-qortal-stack.service config/includes.chroot/etc/systemd/system/multi-user.target.wants/igor-qortal-stack.service

cat > config/includes.chroot/usr/local/bin/igor-qortal-session <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
systemctl start qortal.service 2>/dev/null || true
for _ in {1..60}; do
    if curl -fsS http://127.0.0.1:12391/ >/dev/null 2>&1; then break; fi
    sleep 2
done
if command -v qortal-hub >/dev/null 2>&1; then
    exec qortal-hub
elif command -v Qortal-Hub >/dev/null 2>&1; then
    exec Qortal-Hub
elif command -v qortal >/dev/null 2>&1; then
    exec qortal
else
    gtk-launch qortal-hub 2>/dev/null || true
fi
EOF
chmod +x config/includes.chroot/usr/local/bin/igor-qortal-session

cat > config/includes.chroot/etc/xdg/autostart/igor-qortal-session.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Qortal OS Session
Comment=Start Qortal Core and Qortal Hub automatically with the Linux desktop
Exec=/usr/local/bin/igor-qortal-session
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# Qortal applications appear directly in the Linux application menu.
# Qortal Hub registers qortal:// links, so these launch the requested Q-App
# directly inside the already running Hub session.
cat > config/includes.chroot/usr/local/bin/igor-qortal-app <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
app="${1:?Qortal app name required}"
systemctl --user start igor-qortal-session.service 2>/dev/null || true
sleep 1
exec xdg-open "qortal://APP/${app}"
EOF
chmod +x config/includes.chroot/usr/local/bin/igor-qortal-app

create_qortal_app() {
    local name="$1"
    local app="$2"
    local slug="$3"
    cat > "config/includes.chroot/usr/share/applications/$slug.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$name — Qortal application
Exec=/usr/local/bin/igor-qortal-app "$app"
Terminal=false
Categories=Network;Qortal;
StartupNotify=true
EOF
}

create_qortal_app "Q-Tube" "Q-Tube" "q-tube"
create_qortal_app "Q-Mail" "Q-Mail" "q-mail"
create_qortal_app "Q-Blog" "Q-Blog" "q-blog"
create_qortal_app "Q-Chat" "Q-Chat" "q-chat"
create_qortal_app "Q-Manager" "Q-Manager" "q-manager"


# ==============================================================================
# QORTAL HUB - INSTALL DURING ISO BUILD
# ==============================================================================
# Qortal Hub is the current official desktop interface for Qortal.
# Install the official Debian package directly into the image so the
# installed OS starts with Qortal already available.
#
# Official release source:
# https://github.com/Qortal/Qortal-Hub/releases/latest

mkdir -p config/hooks/live

# Privacy: remove optional usage-reporting/telemetry packages and disable
# Debian popularity-contest reporting inside the finished live system.
cat > config/hooks/live/0105-disable-telemetry.chroot <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get purge -y popularity-contest 2>/dev/null || true
rm -f /etc/cron.d/popularity-contest
rm -f /etc/cron.weekly/popularity-contest
rm -f /etc/default/popularity-contest
rm -f /etc/popularity-contest.conf

# Disable common opt-in package-usage reporting if present.
if [ -f /etc/popularity-contest.conf ]; then
    sed -i 's/^PARTICIPATE=.*/PARTICIPATE="no"/' /etc/popularity-contest.conf
fi
EOF
chmod +x config/hooks/live/0105-disable-telemetry.chroot

cat > config/hooks/live/0500-install-qortal-hub.chroot <<'EOF'
#!/bin/sh
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[+] Paigaldan ametliku Qortal Hubi..."

tmp_deb="/tmp/Qortal-Hub-Setup.deb"

curl -fL --retry 5 --retry-delay 3 \
    "https://github.com/Qortal/Qortal-Hub/releases/latest/download/Qortal-Hub-Setup.deb" \
    -o "$tmp_deb"

apt-get update
apt-get install -y "$tmp_deb"

rm -f "$tmp_deb"

echo "[+] Qortal Hub on ISO-sse paigaldatud."
EOF

chmod +x config/hooks/live/0500-install-qortal-hub.chroot

# ==============================================================================
# MULTI-ARCH QORTAL HUB INSTALLER
# ==============================================================================
cat > config/hooks/live/0500-install-qortal-hub.chroot <<'EOF'
#!/bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
arch="$(dpkg --print-architecture)"
tmp="/tmp/qortal-hub"
case "$arch" in
amd64)
  curl -fL --retry 5 --retry-delay 3 "https://github.com/Qortal/Qortal-Hub/releases/latest/download/Qortal-Hub-Setup.deb" -o "$tmp.deb"
  apt-get update
  apt-get install -y "$tmp.deb"
  rm -f "$tmp.deb"
  ;;
arm64)
  curl -fL --retry 5 --retry-delay 3 "https://github.com/Qortal/Qortal-Hub/releases/latest/download/Qortal-Hub-arm64.AppImage" -o "$tmp.AppImage"
  install -Dm755 "$tmp.AppImage" /opt/qortal/Qortal-Hub-arm64.AppImage
  ln -sf /opt/qortal/Qortal-Hub-arm64.AppImage /usr/local/bin/qortal-hub
  ;;
i386) echo "[!] Qortal Hub i386 native build puudub; Reticulum ja OS komponendid jäävad alles." ;;
esac
EOF
chmod +x config/hooks/live/0500-install-qortal-hub.chrootF
chmod +x config/hooks/live/0500-install-qortal-hub.chroot
# ==============================================================================
# QORTAL REPAIR / REINSTALL TOOL
# ==============================================================================

cat > config/includes.chroot/usr/local/bin/igor-qortal-install.sh <<'EOF'

#!/usr/bin/env bash

set -euo pipefail

echo
echo "=================================================="
echo "        Igor-Qortal OS - Qortal Installer"
echo "=================================================="
echo

echo "[+] Käivitan Qortali Linux installeri..."

bash <(
    curl -fsSL https://link.qortal.dev/linux-script
)

echo
echo "[+] Qortali paigaldus lõpetatud."

EOF

chmod +x config/includes.chroot/usr/local/bin/igor-qortal-install.sh

# ==============================================================================
# QORTAL DESKTOP ENTRY
# ==============================================================================

cat > config/includes.chroot/usr/share/applications/qortal-installer.desktop <<'EOF'

[Desktop Entry]
Type=Application
Name=Qortal Repair / Reinstall
Comment=Repair or reinstall Qortal on Igor-Qortal OS
Exec=gnome-terminal -- /usr/local/bin/igor-qortal-install.sh
Icon=utilities-terminal
Terminal=false
Categories=System;Network;

EOF

# ==============================================================================
# ARCH DISTROBOX
# ==============================================================================

cat > config/includes.chroot/usr/local/bin/igor-arch-setup.sh <<'EOF'

#!/usr/bin/env bash

set -euo pipefail

echo
echo "=================================================="
echo "       Igor-Qortal OS - Arch Environment"
echo "=================================================="
echo

if ! command -v distrobox >/dev/null 2>&1; then
    echo "[!] Distrobox puudub."
    exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
    echo "[!] Podman puudub."
    exit 1
fi

if ! distrobox list 2>/dev/null | grep -qE '(^|[[:space:]])arch-env([[:space:]]|$)'; then

    echo "[+] Loon Arch Linuxi konteineri..."

    distrobox create \
        --image archlinux:latest \
        --name arch-env \
        --yes

fi

echo "[+] Sisenen Arch Linuxi..."

exec distrobox enter arch-env

EOF

chmod +x config/includes.chroot/usr/local/bin/igor-arch-setup.sh

# ==============================================================================
# ARCH DESKTOP ENTRY
# ==============================================================================

cat > config/includes.chroot/usr/share/applications/arch-env.desktop <<'EOF'

[Desktop Entry]
Type=Application
Name=Arch Linux Terminal
Comment=Enter Arch Linux through Distrobox
Exec=gnome-terminal -- /usr/local/bin/igor-arch-setup.sh
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;

EOF

# ==============================================================================
# QORTAL OS INFO
# ==============================================================================

cat > config/includes.chroot/usr/local/bin/qortal-os <<'EOF'

#!/usr/bin/env bash

echo
echo "=================================================="
echo "              IGOR-QORTAL OS"
echo "=================================================="
echo

if command -v chafa >/dev/null 2>&1 &&    [[ -f /usr/share/pixmaps/igor-qortal-os.png ]]; then
    chafa --format symbols --colors 256 --size 28x18         /usr/share/pixmaps/igor-qortal-os.png || true
    echo
fi

if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
else
    echo "fastfetch pole paigaldatud."
fi

echo
echo "Reticulum daemon:"
systemctl is-active rnsd 2>/dev/null || true

echo

EOF

chmod +x config/includes.chroot/usr/local/bin/qortal-os

# ==============================================================================
# NEOFETCH ASCII
# ==============================================================================

cat > config/includes.chroot/etc/skel/.config/neofetch/qortal_ascii.txt <<'EOF'

             .------------------------.
            /                        / \
           /        .-------.       /   \
          /        /  Q     /      /     \
         /        /    ORT /      /       \
        /        /        AL     /         \
       /        '-------'       /           \
      /                        /             \
     /------------------------'               \
     \                        \               /
      \                        \             /
       \                        \           /
        \                        \         /
         \                        \       /
          \                        \     /
           \                        \   /
            \                        \ /
             '------------------------'

EOF

# ==============================================================================
# NEOFETCH CONFIG
# ==============================================================================

cat > config/includes.chroot/etc/skel/.config/neofetch/config.conf <<'EOF'

print_info() {
    info title
    info underline
    info "OS" os
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "DE" de
    info "WM" wm
    info "Terminal" terminal
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
}

os_arch="off"

uptime_shorthand="on"

memory_percent="on"

package_managers="on"

shell_path="off"

shell_version="on"

image_backend="ascii"

image_source="/etc/skel/.config/neofetch/qortal_ascii.txt"

ascii_colors=(4 6 1 8 8 6)

ascii_bold="on"

EOF

# ==============================================================================
# GLOBAL BASH ALIASES
# ==============================================================================

cat >> config/includes.chroot/etc/bash.bashrc <<'EOF'

# ==========================================================
# Igor-Qortal OS
# ==========================================================

alias qortal-os="/usr/local/bin/qortal-os"

alias qortal-rns-status="/usr/local/bin/qortal-rns-status"

EOF

# ==============================================================================
# WAYLAND ENVIRONMENT
# ==============================================================================

cat > config/includes.chroot/etc/environment.d/igor-qortal-wayland.conf <<'EOF'

XDG_SESSION_TYPE=wayland

MOZ_ENABLE_WAYLAND=1

QT_QPA_PLATFORM=wayland

SDL_VIDEODRIVER=wayland

EOF

# ==============================================================================
# GDM WAYLAND
# ==============================================================================

mkdir -p config/includes.chroot/etc/gdm3

cat > config/includes.chroot/etc/gdm3/daemon.conf <<'EOF'

[daemon]

WaylandEnable=true

EOF

# ==============================================================================
# REMOVE XORG SERVER IF SOMETHING PULLED IT IN
# ==============================================================================

cat > config/hooks/live/9000-no-xorg-server.chroot <<'EOF'

#!/bin/sh

set -e

echo "=================================================="
echo " Checking Xorg server state"
echo "=================================================="

apt-get purge -y \
    xserver-xorg \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-all \
    xinit \
    x11-xserver-utils \
    || true

apt-get autoremove -y || true

EOF

chmod +x config/hooks/live/9000-no-xorg-server.chroot

# ==============================================================================
# NO QORTAL AUTOSTART
# ==============================================================================

rm -f \
    config/includes.chroot/etc/xdg/autostart/qortal-install.desktop

# ==============================================================================
# OPTIONAL ISO PADDING
# ==============================================================================

if [[ "$ISO_PADDING_MB" -gt 0 ]]; then

    echo
    echo "[+] Lisan $ISO_PADDING_MB MB paddingut..."

    mkdir -p \
        config/includes.chroot/var/lib/igor-qortal-os

    dd \
        if=/dev/zero \
        of=config/includes.chroot/var/lib/igor-qortal-os/padding.dat \
        bs=1M \
        count="$ISO_PADDING_MB" \
        status=progress

fi

# ==============================================================================
# LEGACY INTEL COMPATIBILITY CHECK
# ==============================================================================
# The main image is amd64 and therefore supports old 64-bit Intel CPUs that
# implement Intel 64/EM64T (for example many Core 2 and later systems).
# Debian no longer provides a normal i386 installer/kernel in Trixie/Sid;
# i386 is now only a co-architecture on amd64. Therefore we deliberately do
# not pretend that a 32-bit-only Intel Pentium can boot this Qortal ISO.
# The generic amd64 kernel is used rather than a CPU-specific build.

cat > config/includes.chroot/usr/local/bin/igor-hardware-info <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Igor-Qortal OS CPU compatibility"
echo
if grep -qw lm /proc/cpuinfo; then
    echo "Architecture: 64-bit Intel/AMD capable (amd64)"
    echo "Status:       supported"
else
    echo "Architecture: 32-bit-only CPU"
    echo "Status:       not supported by the main Qortal ISO"
    echo "Reason:       Qortal Hub and Debian Sid target amd64."
    exit 1
fi

echo
lscpu | grep -E '^(Model name|CPU\\(s\\)|Architecture|Flags):' || true
EOF
chmod +x config/includes.chroot/usr/local/bin/igor-hardware-info

# ==============================================================================
# # ==============================================================================
# OPEN FIRMWARE + DECENTRALIZED DRIVER DELIVERY
# ==============================================================================

cat > config/hooks/live/0600-firmware-tools.chroot <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
install -d -m 0755 /var/lib/igor-qortal-os/firmware-backups
cat > /usr/local/bin/igor-firmware-center <<'SCRIPT'
#!/bin/bash
set -e
echo "Igor-Qortal OS — Firmware / BIOS Center"
echo
command -v fwupdmgr >/dev/null && echo "fwupd: available" || true
command -v cbfstool >/dev/null && echo "coreboot tools: available" || true
command -v flashrom >/dev/null && echo "flashrom: available" || true
echo
echo "No BIOS/ROM is flashed automatically."
echo "Hardware support and a ROM backup must be verified first."
fwupdmgr get-devices 2>/dev/null || true
echo
fwupdmgr get-updates 2>/dev/null || true
SCRIPT
chmod 0755 /usr/local/bin/igor-firmware-center
cat > /usr/share/applications/igor-firmware-center.desktop <<'DESKTOP'
[Desktop Entry]
Name=Firmware / BIOS Center
Name[et]=Püsivara / BIOS keskus
Exec=xterm -e /usr/local/bin/igor-firmware-center
Icon=computer
Terminal=false
Type=Application
Categories=System;Settings;
DESKTOP
EOF
chmod +x config/hooks/live/0600-firmware-tools.chroot

cat > config/includes.chroot/etc/igor-qortal-os/driver-network.conf <<'EOF'
TRANSPORT=reticulum
SOURCE=qdn
REQUIRE_SHA256=yes
REQUIRE_SIGNATURE=yes
ALLOW_UNSIGNED=no
EOF

cat > config/includes.chroot/usr/local/bin/igor-driver-sync <<'SCRIPT'
#!/bin/bash
set -e
echo "Igor-Qortal OS — decentralized driver channel"
echo "Transport: Reticulum"
echo "Source: QDN / approved Reticulum peers"
echo "Trust: SHA-256 + cryptographic signature required"
echo
systemctl is-active --quiet rnsd && echo "Reticulum: ONLINE" || echo "Reticulum: waiting for connectivity"
SCRIPT
chmod 0755 config/includes.chroot/usr/local/bin/igor-driver-sync

cat > config/includes.chroot/usr/share/applications/igor-driver-sync.desktop <<'DESKTOP'
[Desktop Entry]
Name=Decentralized Driver Sync
Name[et]=Detsentraliseeritud draiverite sünkroonimine
Exec=xterm -e /usr/local/bin/igor-driver-sync
Icon=network-wired
Terminal=false
Type=Application
Categories=System;Network;
DESKTOP

mkdir -p config/includes.chroot/usr/share/sounds/igor-qortal-os
if [[ -f "$SCRIPT_DIR/assets/qortal-hub-startup.wav" ]]; then
    cp "$SCRIPT_DIR/assets/qortal-hub-startup.wav" config/includes.chroot/usr/share/sounds/igor-qortal-os/qortal-hub-startup.wav
fi

cat > config/includes.chroot/usr/local/bin/igor-qortal-startup-sound <<'SCRIPT'
#!/bin/bash
set -e
SOUND=/usr/share/sounds/igor-qortal-os/qortal-hub-startup.wav
if [[ -f "$SOUND" ]] && command -v paplay >/dev/null 2>&1; then
    paplay "$SOUND" >/dev/null 2>&1 || true
fi
SCRIPT
chmod 0755 config/includes.chroot/usr/local/bin/igor-qortal-startup-sound

cat > config/includes.chroot/etc/xdg/autostart/igor-qortal-startup-sound.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Igor-Qortal OS startup sound
Exec=/usr/local/bin/igor-qortal-startup-sound
OnlyShowIn=X-Cinnamon;
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP

# ==============================================================================
# DEBIAN DRIVER / FIRMWARE SERVER INTEGRATION
# ==============================================================================
# The installer uses Debian's official package infrastructure. Debian 12+
# provides firmware in the non-free-firmware archive component; this image
# enables main/contrib/non-free/non-free-firmware and detects hardware before
# installing the appropriate kernel modules/firmware.
cat > config/hooks/live/0550-debian-driver-detection.chroot <<'EOF'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=================================================="
echo "  IGOR-QORTAL OS — DEBIAN DRIVER CENTER"
echo "=================================================="

apt-get update

# Core hardware/driver helpers.
apt-get install -y --no-install-recommends \
    pciutils usbutils kmod \
    firmware-linux-free firmware-misc-nonfree \
    firmware-amd-graphics firmware-iwlwifi firmware-realtek \
    firmware-mediatek firmware-atheros firmware-brcm80211 \
    firmware-intel-graphics firmware-nvidia-graphics 2>/dev/null || true

# Graphics stack: use Debian's native kernel/Mesa drivers first.
apt-get install -y --no-install-recommends \
    mesa-vulkan-drivers libgl1-mesa-dri firmware-amd-graphics 2>/dev/null || true

# NVIDIA: install Debian's packaged driver when an NVIDIA GPU is detected.
# This stays inside Debian's official repositories; no third-party installer
# or .run file is downloaded.
if lspci -nn 2>/dev/null | grep -Eiq 'VGA|3D|Display' && \
   lspci -nn 2>/dev/null | grep -Eiq 'NVIDIA'; then
    echo "[+] NVIDIA GPU detected — installing Debian NVIDIA driver."
    apt-get install -y --no-install-recommends nvidia-driver firmware-nvidia-graphics || true
fi

# AMD graphics firmware is safe to include for AMD GPUs.
if lspci -nn 2>/dev/null | grep -Eiq 'VGA|3D|Display' && \
   lspci -nn 2>/dev/null | grep -Eiq 'AMD|ATI'; then
    echo "[+] AMD GPU detected — enabling Debian AMD graphics firmware."
    apt-get install -y --no-install-recommends firmware-amd-graphics mesa-vulkan-drivers || true
fi

# Intel graphics firmware.
if lspci -nn 2>/dev/null | grep -Eiq 'VGA|3D|Display' && \
   lspci -nn 2>/dev/null | grep -Eiq 'Intel'; then
    echo "[+] Intel GPU detected — enabling Debian Intel graphics firmware."
    apt-get install -y --no-install-recommends firmware-intel-graphics mesa-vulkan-drivers || true
fi

# Common Wi-Fi/Ethernet firmware. The kernel driver itself comes from Debian's
# linux-image package; firmware is supplied by Debian's firmware archive.
for pkg in firmware-iwlwifi firmware-realtek firmware-mediatek firmware-atheros firmware-brcm80211; do
    apt-get install -y --no-install-recommends "$pkg" 2>/dev/null || true
done

echo
echo "[+] Debian driver/firmware integration complete."
echo "[+] Repository: https://deb.debian.org/debian"
echo "[+] Components: main contrib non-free non-free-firmware"
EOF
chmod +x config/hooks/live/0550-debian-driver-detection.chroot

cat > config/includes.chroot/usr/local/bin/igor-driver-sync <<'SCRIPT'
#!/bin/bash
set -euo pipefail
echo "Igor-Qortal OS — Debian Driver Center"
echo
echo "Source: Debian official repositories"
echo "Firmware: non-free-firmware"
echo "Transport fallback: Reticulum / QDN"
echo
echo "Detected hardware:"
lspci -nn 2>/dev/null | grep -E 'VGA|3D|Display|Network|Ethernet' || true
echo
echo "Refreshing Debian driver metadata..."
sudo apt-get update
echo
echo "Use 'sudo apt install <package>' for a specific Debian driver."
echo "The installer already includes common AMD/NVIDIA/Intel/Wi-Fi firmware."
SCRIPT
chmod 0755 config/includes.chroot/usr/local/bin/igor-driver-sync

# ==============================================================================
# QORTAL INSTALLER NETWORK CARD — RETICULUM
# ==============================================================================
# Reticulum is a first-class connection choice alongside Ethernet/Wi-Fi.

mkdir -p config/includes.chroot/etc/reticulum

cat > config/includes.chroot/etc/reticulum/installer-network.conf <<'EOF'
[reticulum]
enable_transport = Yes
share_instance = Yes
panic_on_interface_error = No

[interfaces]
  [[Igor-Qortal Local Mesh]]
    type = AutoInterface
    enabled = Yes
    mode = full
    group_id = igor-qortal-os
EOF

cat > config/includes.chroot/usr/local/bin/igor-network-card <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
CONFIG=/etc/reticulum/installer-network.conf

while true; do
    clear 2>/dev/null || true
    echo '=================================================='
    echo '        IGOR-QORTAL OS — VÕRK'
    echo '=================================================='
    echo
    echo 'Vali ühendus:'
    echo
    echo '  1) 🟢 Reticulum — vaikimisi / mesh'
    echo '  2) 🌐 Internet — Ethernet / Wi-Fi'
    echo '  3) 🔗 Reticulum — TCP/Backbone'
    echo '  4) 🛰️  Reticulum + Internet'
    echo '  5) ⏎  Tagasi'
    echo
    read -rp 'Valik [1]: ' choice
    choice="${choice:-1}"
    case "$choice" in
      1)
        echo
        echo '[+] Reticulum on vaikimisi ühendus.'
        echo '    Käivitan kohaliku mesh-võrgu.'
        systemctl restart rnsd 2>/dev/null || systemctl start rnsd 2>/dev/null || true
        read -rp 'Enter jätkamiseks...' _
        ;;
      2)
        echo
        command -v nmcli >/dev/null 2>&1 && nmcli device status || ip -brief link || true
        read -rp 'Enter jätkamiseks...' _
        ;;
      3)
        echo
        echo '[+] Reticulum AutoInterface: ON'
        echo '    Ethernet/Wi-Fi jääb Linuxi võrguks; Reticulum töötab selle kõrval.'
        systemctl restart rnsd 2>/dev/null || systemctl start rnsd 2>/dev/null || true
        read -rp 'Enter jätkamiseks...' _
        ;;
      4)
        echo
        read -rp 'Reticulum TCP/Backbone host: ' host
        read -rp 'Port [4242]: ' port
        port="${port:-4242}"
        if [[ -n "$host" ]]; then
          cat >> "$CONFIG" <<EOF

  [[ Igor-Qortal Backbone ]]
    type = TCPClientInterface
    enabled = Yes
    target_host = $host
    target_port = $port
    mode = boundary
EOF
          systemctl restart rnsd 2>/dev/null || systemctl start rnsd 2>/dev/null || true
          echo '[+] Backbone ühendus lisatud.'
        fi
        read -rp 'Enter jätkamiseks...' _
        ;;
      5) exit 0 ;;
      *) echo '[!] Tundmatu valik.'; sleep 1 ;;

      *) echo '[!] Tundmatu valik.'; sleep 1 ;;
    esac
done
SCRIPT
chmod 0755 config/includes.chroot/usr/local/bin/igor-network-card

cat > config/includes.chroot/usr/share/applications/igor-network-card.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Network — Reticulum
Name[et]=Võrk — Reticulum
Comment=Choose Internet or Reticulum networking
Exec=xterm -e /usr/local/bin/igor-network-card
Terminal=false
Icon=network-workgroup
Categories=Network;Settings;
StartupNotify=true
DESKTOP
BUILD ISO
# ==============================================================================

echo
echo "=================================================="
echo "        EHITAN IGOR-QORTAL OS ISO"
echo "=================================================="
echo

lb build

# ==============================================================================
# FIND ISO
# ==============================================================================

ISO_FILE=""

for file in *.iso *.img; do

    if [[ -f "$file" ]]; then
        ISO_FILE="$file"
        break
    fi

done

if [[ -z "$ISO_FILE" ]]; then

    echo
    echo "[!] ISO ehitamine ebaõnnestus."

    exit 1

fi

# ==============================================================================
# MOVE FINAL ISO
# ==============================================================================

cd ..

rm -f "$OUTPUT_ISO"

mv \
    "$BUILD_DIR/$ISO_FILE" \
    "$OUTPUT_ISO"

# ==============================================================================
# FINAL REPORT
# ==============================================================================

echo
echo "=================================================="
echo "        IGOR-QORTAL OS VALMIS 🚀"
echo "=================================================="
echo

echo "Alglaadur:"
echo "    $BOOTLOADER"
echo
echo "Pildirežiim:"
echo "    $BINARY_IMAGE_MODE"
echo
echo "Väljund:"
echo "    $OUTPUT_ISO"

echo

echo "Suurus:"
du -h "$OUTPUT_ISO"

echo

echo "Reticulum:"
echo
echo "    systemctl status rnsd"
echo "    rnstatus --config /etc/reticulum"
echo "    qortal-rns-status"

echo

echo "OS info:"
echo
echo "    qortal-os"

echo

echo "Qortal:"
echo
echo "    Rakendused → Qortal Installer"

echo

echo "Arch:"
echo
echo "    Rakendused → Arch Linux Terminal"

echo

echo "=================================================="
echo "        BUILD COMPLETE 🚀"
echo "=================================================="
