#!/usr/bin/env bash
set -Eeuo pipefail

REPO="linuxmint110791/igor-qortal-os"
BASE="$HOME/Downloads/igorcoin-os"
API="https://api.github.com/repos/$REPO/releases/latest"

command -v curl >/dev/null || { echo "curl puudub." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq puudub. Paigalda: sudo apt install jq" >&2; exit 1; }
command -v zstd >/dev/null || { echo "zstd puudub. Paigalda: sudo apt install zstd" >&2; exit 1; }

mkdir -p "$BASE"
cd "$BASE"
echo "==> Otsin IgorCoin-Qortal OS viimast edukat väljalaset..."
curl -fsSL "$API" -o release.json

ISO_SUM_URL="$(jq -r '.assets[] | select(.name=="igorcoin-qortal-os.iso.sha256") | .browser_download_url' release.json)"
ZST_SUM_URL="$(jq -r '.assets[] | select(.name=="igorcoin-qortal-os.iso.zst.sha256") | .browser_download_url' release.json)"
[[ -n "$ISO_SUM_URL" && "$ISO_SUM_URL" != null ]] || { echo "Väljalaskes puudub ISO kontrollsumma." >&2; exit 1; }
[[ -n "$ZST_SUM_URL" && "$ZST_SUM_URL" != null ]] || { echo "Väljalaskes puudub Zstandard-faili kontrollsumma." >&2; exit 1; }

curl -fL --retry 3 "$ISO_SUM_URL" -o igorcoin-qortal-os.iso.sha256
curl -fL --retry 3 "$ZST_SUM_URL" -o igorcoin-qortal-os.iso.zst.sha256

mapfile -t PART_URLS < <(jq -r '.assets[] | select(.name | test("^igorcoin-qortal-os\\.iso\\.zst\\.part-[0-9]+$")) | .browser_download_url' release.json)
SINGLE_URL="$(jq -r '.assets[] | select(.name=="igorcoin-qortal-os.iso.zst") | .browser_download_url' release.json)"

rm -f igorcoin-qortal-os.iso.zst igorcoin-qortal-os.iso.zst.part-*
if (( ${#PART_URLS[@]} > 0 )); then
  echo "==> Laadin alla ${#PART_URLS[@]} kokkupakitud osa..."
  mapfile -t PART_NAMES < <(jq -r '.assets[] | select(.name | test("^igorcoin-qortal-os\\.iso\\.zst\\.part-[0-9]+$")) | .name' release.json | sort)
  for i in "${!PART_URLS[@]}"; do
    curl -fL --retry 3 "${PART_URLS[$i]}" -o "${PART_NAMES[$i]}"
  done
  cat "${PART_NAMES[@]}" > igorcoin-qortal-os.iso.zst
elif [[ -n "$SINGLE_URL" && "$SINGLE_URL" != null ]]; then
  echo "==> Laadin alla ühe kokkupakitud faili..."
  curl -fL --retry 3 "$SINGLE_URL" -o igorcoin-qortal-os.iso.zst
else
  echo "Väljalaskes puudub ISO kokkupakitud fail." >&2
  exit 1
fi

echo "==> Kontrollin kokkupakitud faili SHA256 summat..."
EXPECTED_ZST="$(awk 'NR==1 {print $1}' igorcoin-qortal-os.iso.zst.sha256)"
ACTUAL_ZST="$(sha256sum igorcoin-qortal-os.iso.zst | awk '{print $1}')"
[[ "$EXPECTED_ZST" == "$ACTUAL_ZST" ]] || { echo "Kokkupakitud faili kontrollsumma ei klapi!" >&2; exit 1; }

echo "==> Kontrollin Zstandard-faili terviklikkust..."
zstd -t igorcoin-qortal-os.iso.zst

echo "==> Ühendan ja pakin lahti üheks ISO-failiks..."
rm -f igor-coin.iso
zstd -T0 -d igorcoin-qortal-os.iso.zst -o igor-coin.iso

echo "==> Kontrollin lõpliku ISO SHA256 summat..."
EXPECTED_ISO="$(awk 'NR==1 {print $1}' igorcoin-qortal-os.iso.sha256)"
ACTUAL_ISO="$(sha256sum igor-coin.iso | awk '{print $1}')"
[[ "$EXPECTED_ISO" == "$ACTUAL_ISO" ]] || { rm -f igor-coin.iso; echo "ISO kontrollsumma ei klapi; vigane fail eemaldati." >&2; exit 1; }

printf '%s  %s\\n' "$ACTUAL_ISO" "igor-coin.iso" > igor-coin.iso.sha256
echo
echo "VALMIS: $BASE/igor-coin.iso"
ls -lh igor-coin.iso igor-coin.iso.sha256
