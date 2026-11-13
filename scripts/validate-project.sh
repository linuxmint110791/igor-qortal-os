#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Shell syntax checks"
bash -n ./build-iso.sh
bash -n ./setup-build-host.sh

echo "==> Debian source manifest checks"
test -s ./debian-source.env
grep -Fq 'DEBIAN_SUITE="${DEBIAN_SUITE:-trixie}"' ./debian-source.env
grep -Fq 'DEBIAN_POINT_RELEASE="${DEBIAN_POINT_RELEASE:-13.3}"' ./debian-source.env
grep -Fq 'https://cdimage.debian.org/cdimage/archive/13.3.0/amd64/iso-cd/' ./debian-source.env
grep -Fq 'https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}/' ./debian-source.env

echo "==> Check known broken package names are absent"
if grep -Eq '^(libfuse2t64|plasma-workspace-wayland|xwayland)$' <(sed -n '/<<\x27PACKAGES\x27/,/^PACKAGES$/p' ./build-iso.sh); then
  echo "A known invalid or disallowed package is still in the package list." >&2
  exit 1
fi

echo "==> Required build components are present"
grep -Fq "live-build" ./build-iso.sh
grep -Fq "debian-archive-keyring" ./build-iso.sh
grep -Fq "calamares" ./build-iso.sh
grep -Fq "igorcoin-auto-update.timer" ./build-iso.sh
grep -Fq "igorcoin-reticulum.service" ./build-iso.sh

echo "Project validation passed."
