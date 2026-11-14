# Igorcoin Qortal OS project

This repository currently distributes the **unmodified official Arch Linux x86_64 installation ISO**. It does not build or modify an Arch ISO.

The GitHub Actions workflow downloads the current ISO from the official Arch mirror network and verifies it against Arch Linux's published `sha256sums.txt` before uploading it as the artifact:

**`ArchLinux-Official-ISO-amd64`**
- `archlinux-x86_64.iso`
- `archlinux-x86_64.iso.sha256`
- `SOURCE.txt`

## Download

1. Open [GitHub Actions](https://github.com/linuxmint110791/igor-qortal-os/actions/workflows/build-iso.yml).
2. Open the latest successful **Download Official Arch Linux ISO** run.
3. Under **Artifacts**, download `ArchLinux-Official-ISO-amd64`.
4. Extract the ZIP. Verify the ISO in the extracted directory:

```bash
sha256sum -c archlinux-x86_64.iso.sha256
```

The result must say `archlinux-x86_64.iso: OK`.

## Important distinction

This download is the standard Arch Linux installer supplied by Arch Linux. It is **not** a preconfigured Igorcoin/Qortal desktop, and it does not contain Qortal, KDE customizations, or this project's branding. Those would require a separate installation/configuration step after installing Arch.

Official upstream source: [Arch Linux downloads](https://archlinux.org/download/).
