#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Shell syntax checks"
bash -n ./build-iso.sh
bash -n ./setup-build-host.sh
bash -n ./scripts/verify-iso.sh

echo "==> Debian source manifest checks"
test -s ./debian-source.env
grep -Fq 'DEBIAN_SUITE="${DEBIAN_SUITE:-trixie}"' ./debian-source.env
grep -Fq 'DEBIAN_POINT_RELEASE="${DEBIAN_POINT_RELEASE:-13.7}"' ./debian-source.env
grep -Fq 'https://cdimage.debian.org/cdimage/archive/13.7.0/amd64/iso-cd/' ./debian-source.env
grep -Fq 'DEBIAN_SNAPSHOT="${DEBIAN_SNAPSHOT:-20260913T000000Z}"' ./debian-source.env
grep -Fq 'https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}/' ./debian-source.env

echo "==> Check known broken package names are absent"
if grep -Eq '^(libfuse2t64|plasma-workspace-wayland|xwayland)$' <(sed -n '/<<\x27PACKAGES\x27/,/^PACKAGES$/p' ./build-iso.sh); then
  echo "A known invalid or disallowed package is still in the package list." >&2
  exit 1
fi

echo "==> Required build components are present"
grep -Fq "live-build" ./build-iso.sh
grep -Fq -- "--initsystem systemd" ./build-iso.sh
grep -Fq "debian-archive-keyring" ./build-iso.sh
grep -Fq "calamares" ./build-iso.sh
grep -Fq "linux-image-amd64" ./build-iso.sh
if grep -Eq "debian-kernel-sid|linux-image-.*deb14" ./build-iso.sh; then
  echo "Debian sid/deb14 kernel source must not be used in a Trixie ISO." >&2
  exit 1
fi
grep -Fq "*+deb13-amd64" ./scripts/verify-iso.sh
grep -Fq "igorcoin-auto-update.timer" ./build-iso.sh
grep -Fq "igorcoin-reticulum.service" ./build-iso.sh
grep -Fq -- "--initsystem systemd" ./build-iso.sh
test -s ./scripts/verify-iso.sh

echo "Project validation passed."
