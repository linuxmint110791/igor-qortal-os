#!/usr/bin/env bash
set -Eeuo pipefail

TAG="v0.1.0"
BASE="https://github.com/linuxmint110791/igor-qortal-os/releases/download/${TAG}"
OUT="${PWD}/igorcoin-qortal-os-${TAG}.iso"
WORK="${PWD}/.igorcoin-qortal-os-${TAG}-download"

for cmd in curl zstd sha256sum cat; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
done

mkdir -p "$WORK"
cd "$WORK"

echo "==> Downloading IgorCoin-Qortal OS ${TAG}"
curl -fL --retry 3 -o amd.iso.zst.part-00 "$BASE/amd.iso.zst.part-00"
curl -fL --retry 3 -o amd.iso.zst.part-01 "$BASE/amd.iso.zst.part-01"
curl -fL --retry 3 -o amd.iso.sha256 "$BASE/amd.iso.sha256"

echo "==> Reassembling compressed image"
cat amd.iso.zst.part-00 amd.iso.zst.part-01 > amd.iso.zst

echo "==> Testing compressed stream"
zstd -t amd.iso.zst

echo "==> Decompressing ISO"
zstd -d -f amd.iso.zst -o amd.iso

echo "==> Verifying ISO SHA256"
sha256sum --check amd.iso.sha256

echo "==> Moving verified ISO into place"
mv -f amd.iso "$OUT"
echo "==> Finished"
ls -lh "$OUT"
echo "ISO saved to: $OUT"
