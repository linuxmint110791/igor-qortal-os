#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Docker ISO build failed at line $LINENO" >&2' ERR

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v docker >/dev/null 2>&1 || { echo "Docker is required. Install docker.io first." >&2; exit 1; }

docker pull archlinux:base-devel
docker run --rm --privileged --network host --security-opt seccomp=unconfined \
  -v "$REPO_ROOT:/repo" -w /repo/archiso archlinux:base-devel \
  bash /repo/archiso/scripts/container-build.sh

echo "ISO output: $REPO_ROOT/archiso/out/amd.iso"
echo "Checksum:   $REPO_ROOT/archiso/out/amd.iso.sha256"
