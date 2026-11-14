#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Docker ISO build failed at line $LINENO" >&2' ERR
ROOT="$(cd "$(dirname "$0")" && pwd)"
command -v docker >/dev/null 2>&1 || { echo "Install docker.io on Linux Mint first." >&2; exit 1; }
docker pull archlinux:base-devel
docker run --rm --privileged --network host --security-opt seccomp=unconfined -v "$ROOT:/work" -w /work archlinux:base-devel bash /work/scripts/container-build.sh
echo "ISO output: $ROOT/out/igorcoin-qortal-os-x86_64.iso"
