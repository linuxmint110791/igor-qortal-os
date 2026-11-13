#!/usr/bin/env bash
set -Eeuo pipefail

# Prepare an Ubuntu/Debian workstation to build Igorcoin Qortal OS.
# Run as the normal desktop user: bash setup-build-host.sh
# This installs build tools and checks the Debian archive access.
# It does not repartition disks or modify the running desktop environment.

if [[ ${EUID} -eq 0 ]]; then
  echo "Run this script as your normal user, not with sudo." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This setup script requires an Ubuntu/Debian apt-based host." >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" != "amd64" ]]; then
  echo "The current ISO build targets amd64; host architecture is $ARCH." >&2
  exit 1
fi

FREE_GIB="$(df -BG "$HOME" | awk 'NR==2 {gsub(/G/,"",$4); print $4}')"
if [[ -z "$FREE_GIB" || "$FREE_GIB" -lt 30 ]]; then
  echo "At least 30 GiB free space is recommended in $HOME; available: ${FREE_GIB:-unknown} GiB." >&2
  exit 1
fi

echo "==> Installing official repository build prerequisites"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  live-build debootstrap \
  curl wget ca-certificates git jq \
  xorriso squashfs-tools dosfstools mtools \
  grub-pc-bin grub-efi-amd64-bin \
  isolinux syslinux-common syslinux-utils \
  gpgv debian-archive-keyring debian-keyring \
  python3 python3-venv age \
  qemu-system-x86 ovmf

WORKDIR="$HOME/igorcoin-os-build"
REPO="https://github.com/linuxmint110791/igor-qortal-os.git"

if [[ -d "$WORKDIR/.git" ]]; then
  echo "==> Updating existing project checkout"
  git -C "$WORKDIR" pull --ff-only
elif [[ -e "$WORKDIR" ]]; then
  echo "Refusing to overwrite non-Git directory: $WORKDIR" >&2
  exit 1
else
  echo "==> Cloning Igorcoin Qortal OS"
  git clone "$REPO" "$WORKDIR"
fi

echo
echo "==> Build host prepared"
echo "Project: $WORKDIR"
echo "Build script: $WORKDIR/build-iso.sh"
echo "Debian package source: official Debian Snapshot archive (configured in build-iso.sh)"
echo
echo "Next command to start the ISO build:"
printf '  cd %q && sudo bash ./build-iso.sh\n' "$WORKDIR"
echo
echo "The build creates an ISO in the project directory. It does not install the ISO onto this computer."
