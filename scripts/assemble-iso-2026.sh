#!/usr/bin/env bash
set -Eeuo pipefail

# Reassembles a single ISO from exactly two temporary chunks on the GitHub runner.
# Usage: assemble-iso-2026.sh SOURCE_ISO OUTPUT_DIRECTORY

SOURCE="${1:?Usage: assemble-iso-2026.sh SOURCE_ISO OUTPUT_DIRECTORY}"
DEST="${2:?Usage: assemble-iso-2026.sh SOURCE_ISO OUTPUT_DIRECTORY}"

[[ -s "$SOURCE" ]] || { echo "Source ISO is missing or empty: $SOURCE" >&2; exit 1; }
mkdir -p "$DEST"

FINAL="$DEST/igorcoin-qortal-os.iso"
PART_PREFIX="$DEST/igorcoin-qortal-os.iso.part-"
EXPECTED="$(sha256sum "$SOURCE" | awk '{print $1}')"

echo "==> Creating exactly two ISO parts"
split --number=2 --numeric-suffixes=0 --suffix-length=2 -- "$SOURCE" "$PART_PREFIX"

PARTS=( "$PART_PREFIX"* )
[[ ${#PARTS[@]} -eq 2 ]] || {
  echo "Expected exactly two ISO parts; found ${#PARTS[@]}." >&2
  exit 1
}

echo "==> Joining the two parts into one ISO"
cat "${PARTS[0]}" "${PARTS[1]}" > "$FINAL"

ACTUAL="$(sha256sum "$FINAL" | awk '{print $1}')"
[[ "$EXPECTED" == "$ACTUAL" ]] || {
  echo "ISO reassembly checksum mismatch." >&2
  exit 1
}

printf '%s  %s\n' "$ACTUAL" "igorcoin-qortal-os.iso" > "$DEST/igorcoin-qortal-os.iso.sha256"
rm -f "${PARTS[@]}"

echo "==> Verified single ISO created"
ls -lh "$FINAL" "$DEST/igorcoin-qortal-os.iso.sha256"
sha256sum --check "$DEST/igorcoin-qortal-os.iso.sha256"
