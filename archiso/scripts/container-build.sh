#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Archiso container build failed at line $LINENO" >&2' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
PROFILE="$ROOT/profile"

[[ "$(uname -m)" == "x86_64" ]] || { echo "This ISO build requires x86_64." >&2; exit 1; }

# Prevent concurrent builds from racing over the package database.
if command -v flock >/dev/null 2>&1; then
  exec 9>/tmp/igorcoin-archiso-build.lock
  flock -n 9 || { echo "Another IgorCoin-Qortal ISO build is already running." >&2; exit 1; }
fi

rm -rf "$WORK" "$OUT" "$PROFILE"
mkdir -p "$WORK" "$OUT"

FREE_KB="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
[[ -n "$FREE_KB" && "$FREE_KB" -ge 12582912 ]] || {
  echo "At least 12 GiB free space is required for the build." >&2
  exit 1
}

echo "==> Refreshing official Arch package databases and keyring"
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm archiso curl grub calamares polkit polkit-kde-agent python-yaml

echo "==> Starting from the current official Archiso releng profile"
cp -a /usr/share/archiso/configs/releng "$PROFILE"

# Remove Firefox from upstream releng: this OS ships without a web browser.
sed -i '/^firefox$/d' "$PROFILE/packages.x86_64"
# Add IgorCoin desktop and Qortal Hub dependencies.
cat "$ROOT/packages.x86_64" >> "$PROFILE/packages.x86_64"
awk 'NF && $1 !~ /^#/ {print $1}' "$PROFILE/packages.x86_64" | sort -u > "$PROFILE/packages.x86_64.tmp"
mv "$PROFILE/packages.x86_64.tmp" "$PROFILE/packages.x86_64"

# Override only the upstream ISO identity/metadata and retain official boot defaults.
cp "$ROOT/profiledef.sh" "$PROFILE/profiledef.sh"
cp "$ROOT/pacman.conf" "$PROFILE/pacman.conf"

# Integrate Calamares using the upstream Manjaro configuration as the starting
# point, adapted for the Archiso squashfs layout and IgorCoin-Qortal branding.
# Manjaro's archived profile uses generated image placeholders and Manjaro-only
# modules, so those are deliberately replaced rather than copied verbatim.
CALAMARES_CONFIG="$(mktemp -d)"
git clone --depth 1 https://github.com/calamares/calamares-manjaro.git "$CALAMARES_CONFIG/manjaro"
install -d "$PROFILE/airootfs/etc/calamares/modules"
for module in bootloader.conf initcpio.conf users.conf; do
  if [[ -s "$CALAMARES_CONFIG/manjaro/conf/$module" ]]; then
    install -m644 "$CALAMARES_CONFIG/manjaro/conf/$module" \
      "$PROFILE/airootfs/etc/calamares/modules/$module"
  fi
done

# The live image contains one Archiso root squashfs, not Manjaro's generated
# _root-image_/_desktop-image_ pair.
cat > "$PROFILE/airootfs/etc/calamares/modules/unpackfs.conf" <<'EOF'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
EOF

# Use Estonia as the initial locale/time-zone selection; users can change it.
cat > "$PROFILE/airootfs/etc/calamares/modules/locale.conf" <<'EOF'
---
region: "Europe"
zone: "Tallinn"
localeGenPath: "/etc/locale.gen"
EOF

# Require the installer user to choose credentials; do not enable automatic login
# on the installed system.
cat > "$PROFILE/airootfs/etc/calamares/modules/users.conf" <<'EOF'
---
defaultGroups:
  - users
  - lp
  - video
  - audio
  - network
  - storage
  - wheel
sudoersGroup: wheel
setRootPassword: true
doReusePassword: true
doAutologin: false
EOF

# Arch's kernel package is named linux (not Manjaro's generated _kernel_ token).
cat > "$PROFILE/airootfs/etc/calamares/modules/initcpio.conf" <<'EOF'
---
kernel: linux
EOF

# Keep the installer distro-agnostic: remove Manjaro-only mhwdcfg/postcfg
# steps and retain the standard Calamares partition/mount/unpack/GRUB flow.
cat > "$PROFILE/airootfs/etc/calamares/settings.conf" <<'EOF'
---
modules-search: [ local ]
instances: []
sequence:
  - show:
      - welcome
      - locale
      - keyboard
      - partition
      - users
      - summary
  - exec:
      - partition
      - mount
      - unpackfs
      - machineid
      - fstab
      - locale
      - keyboard
      - localecfg
      - initcpiocfg
      - initcpio
      - users
      - displaymanager
      - hwclock
      - services
      - grubcfg
      - bootloader
      - umount
  - show:
      - finished
branding: default
prompt-install: true
dont-chroot: false
oem-setup: false
disable-cancel: false
EOF

# Manjaro's bootloader configuration already selects GRUB; explicitly ensure
# the installed system uses the standard Arch GRUB commands and path.
cat > "$PROFILE/airootfs/etc/calamares/modules/bootloader.conf" <<'EOF'
---
efiBootLoader: "grub"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
EOF

# Ensure the live image has a visible GUI installer entry.
install -Dm644 /dev/stdin \
  "$PROFILE/airootfs/usr/share/applications/igorcoin-installer.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Install IgorCoin-Qortal OS
GenericName=System Installer
Comment=Install IgorCoin-Qortal OS to this computer
Exec=pkexec /usr/bin/calamares
Icon=calamares
Terminal=false
Categories=System;
EOF

# Remove the temporary Manjaro configuration checkout after staging.
rm -rf "$CALAMARES_CONFIG"

# Keep the existing Qortal installer script unchanged and make it available
# in the standard Arch live shell as: igorcoin-qortal-install
install -Dm755 "$ROOT/../scripts/install-qortal.sh" \
  "$PROFILE/airootfs/usr/local/lib/igorcoin/install-qortal.sh"

# Download the official Qortal Hub Linux AppImage and verify its published SHA256.
QORTAL_HUB_URL="https://github.com/Qortal/Qortal-Hub/releases/download/v3.0.3/Qortal-Hub.AppImage"
QORTAL_HUB_SHA256="a5affb4c438d5c0934e438b5518b6955653420148cf599f1c690bce6e69394b8"
install -d "$PROFILE/airootfs/opt/qortal-hub"
curl -fL --retry 3 "$QORTAL_HUB_URL" -o "$PROFILE/airootfs/opt/qortal-hub/Qortal-Hub.AppImage"
echo "$QORTAL_HUB_SHA256  $PROFILE/airootfs/opt/qortal-hub/Qortal-Hub.AppImage" | sha256sum --check
chmod 755 "$PROFILE/airootfs/opt/qortal-hub/Qortal-Hub.AppImage"

# Enable NetworkManager in the live environment so Wi-Fi works after boot.
install -d "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

# MediaTek MT7921E / MT7922 (including the user's MT7922 PCI ID 14c3:0616).
# Follow ArchWiki: disable ASPM for this driver family to avoid latency/recovery issues.
install -Dm644 "$ROOT/wifi/mt7921e.conf" \
  "$PROFILE/airootfs/etc/modprobe.d/mt7921e.conf"

# Disable NetworkManager Wi-Fi powersave for more reliable MT7922 connectivity.
install -Dm644 "$ROOT/wifi/NetworkManager-wifi-powersave.conf" \
  "$PROFILE/airootfs/etc/NetworkManager/conf.d/10-wifi-powersave.conf"

# Fail the ISO build if the required MediaTek configuration was not staged.
test -s "$PROFILE/airootfs/etc/modprobe.d/mt7921e.conf"
test -s "$PROFILE/airootfs/etc/NetworkManager/conf.d/10-wifi-powersave.conf"

# Enable Bluetooth where supported.
if [[ -f /usr/lib/systemd/system/bluetooth.service ]]; then
  ln -sfn /usr/lib/systemd/system/bluetooth.service \
    "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/bluetooth.service"
fi

# Add the Estonian-flag default wallpaper to the live image.
install -Dm644 "$ROOT/../assets/estonia-default.svg" \
  "$PROFILE/airootfs/usr/share/backgrounds/igorcoin/estonia-default.svg"
install -Dm755 "$ROOT/../scripts/set-wallpaper.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-set-wallpaper"

# Add the Wi-Fi-first installer launchers.
install -Dm755 "$ROOT/../scripts/igorcoin-install.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-install"
install -Dm755 "$ROOT/../scripts/igorcoin-qortal-install.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-qortal-install"

# Native Qortal Hub desktop launcher (not a browser shortcut).
install -Dm644 "$ROOT/../desktop/qortal-hub.desktop" "$PROFILE/airootfs/usr/share/applications/qortal-hub.desktop"

# Start the installed local Qortal Core (if present) and open Qortal Hub
# automatically when the desktop user logs in.
install -Dm755 "$ROOT/../scripts/start-qortal-session.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-qortal-session"
install -Dm644 "$ROOT/../desktop/qortal-hub-autostart.desktop" \
  "$PROFILE/airootfs/etc/xdg/autostart/qortal-hub.desktop"

# KDE menu launchers and default wallpaper application on first Plasma start.
install -Dm644 "$ROOT/../desktop/igorcoin-installer.desktop" \
  "$PROFILE/airootfs/usr/share/applications/igorcoin-installer.desktop"
install -Dm644 "$ROOT/../desktop/igorcoin-qortal.desktop" \
  "$PROFILE/airootfs/usr/share/applications/igorcoin-qortal.desktop"
install -Dm644 "$ROOT/../desktop/arch-terminal.desktop" \
  "$PROFILE/airootfs/usr/share/applications/arch-terminal.desktop"

# Put clickable installer and terminal icons directly on the live user's desktop.
install -d "$PROFILE/airootfs/etc/skel/Desktop"
install -m755 "$ROOT/../desktop/igorcoin-installer.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Install-IgorCoin-Qortal-OS.desktop"
install -m755 "$ROOT/../desktop/arch-terminal.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Arch-Terminal.desktop"
install -m755 "$ROOT/../desktop/igorcoin-qortal.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Install-Qortal.desktop"
install -m755 "$ROOT/../desktop/qortal-hub.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Qortal-Hub.desktop"

install -Dm755 "$ROOT/../scripts/set-wallpaper.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-set-wallpaper"
install -d "$PROFILE/airootfs/etc/xdg/autostart"
cat > "$PROFILE/airootfs/etc/xdg/autostart/igorcoin-wallpaper.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=IgorCoin default wallpaper
Exec=/usr/local/bin/igorcoin-set-wallpaper
OnlyShowIn=KDE;
EOF

# SDDM starts KDE Plasma in the graphical live session.
ln -sfn /usr/lib/systemd/system/sddm.service \
  "$PROFILE/airootfs/etc/systemd/system/display-manager.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

# Validate the staged Calamares configuration before spending time on the ISO build.
echo "==> Validating Calamares configuration and runtime"
test -x /usr/bin/calamares
test -x /usr/bin/pkexec
test -d /usr/lib/calamares/modules
test -s "$PROFILE/airootfs/etc/calamares/settings.conf"
test -s "$PROFILE/airootfs/etc/calamares/modules/bootloader.conf"
test -s "$PROFILE/airootfs/etc/calamares/modules/unpackfs.conf"
test -s "$PROFILE/airootfs/usr/share/applications/igorcoin-installer.desktop"
python - "$PROFILE/airootfs/etc/calamares" <<'PY'
import pathlib, sys, yaml
root = pathlib.Path(sys.argv[1])
for path in sorted(root.rglob("*.conf")):
    with path.open(encoding="utf-8") as stream:
        yaml.safe_load(stream)
    print(f"Valid YAML: {path.relative_to(root)}")
settings = yaml.safe_load((root / "settings.conf").read_text(encoding="utf-8"))
required = {"welcome", "locale", "keyboard", "partition", "users", "summary", "mount", "unpackfs", "machineid", "fstab", "localecfg", "initcpiocfg", "initcpio", "displaymanager", "hwclock", "services", "grubcfg", "bootloader", "umount", "finished"}
used = {name for phase in settings.get("sequence", []) for items in phase.values() for name in items}
missing = sorted(required - used)
if missing:
    raise SystemExit("Calamares sequence is missing required modules: " + ", ".join(missing))
if settings.get("branding") != "default":
    raise SystemExit("Unexpected Calamares branding selection")
PY

echo "==> Building branded image using official Archiso releng"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO="$(find "$OUT" -maxdepth 1 -type f -name 'igorcoin-qortal-os-*.iso' -print -quit)"
if [[ -z "$ISO" ]]; then
  ISO="$(find "$OUT" -maxdepth 1 -type f -name '*.iso' -print -quit)"
fi
[[ -n "$ISO" && -s "$ISO" ]] || { echo "Archiso did not produce a non-empty ISO." >&2; exit 1; }
if [[ "$ISO" != "$OUT/amd.iso" ]]; then
  mv "$ISO" "$OUT/amd.iso"
fi

file "$OUT/amd.iso"
xorriso -indev "$OUT/amd.iso" -pvd_info >/dev/null
(cd "$OUT" && sha256sum amd.iso > amd.iso.sha256 && sha256sum --check amd.iso.sha256)
echo "Branded Archiso image built and checksum verified."
