# IgorCoin-Qortal OS downloads

This folder contains the download helper for the published live image.

## Current release: v0.1.0

[Open the GitHub Release](https://github.com/linuxmint110791/igor-qortal-os/releases/tag/v0.1.0)

The v0.1.0 release currently stores the compressed image in two GitHub assets because the compressed file exceeds the single-asset upload limit. The helper script downloads both pieces, joins them, tests the Zstandard stream, decompresses the image, and verifies the resulting ISO with SHA256.

## Download on Linux

From a terminal:

```bash
curl -fL https://raw.githubusercontent.com/linuxmint110791/igor-qortal-os/main/downloads/get-iso.sh -o get-igorcoin-qortal-os.sh
chmod +x get-igorcoin-qortal-os.sh
./get-igorcoin-qortal-os.sh
```

The script requires `curl`, `zstd`, and `sha256sum`.

The resulting file is `igorcoin-qortal-os-v0.1.0.iso` in the current directory.

**Status:** experimental image. Secure Boot signing and physical-hardware validation are not certified. Always verify the checksum before writing the ISO to USB.
