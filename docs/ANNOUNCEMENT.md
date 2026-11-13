# Igorcoin Qortal OS — project announcement

**Project page:** https://github.com/linuxmint110791/igor-qortal-os

## Short description

Igorcoin Qortal OS is an experimental Debian-based desktop Linux project that brings KDE Plasma, Wayland support, the official Qortal installer, and optional Reticulum networking tools together in one installable system.

The project is under active development. A build is not considered ready to install until the automated GitHub Actions build and ISO verification both pass.

## What the project is working to provide

- Debian 13 Trixie package base and Debian package repositories.
- KDE Plasma desktop with Wayland session support.
- Calamares graphical installer.
- Official Qortal Linux installer included in the image.
- Qortal network status tray utility.
- Reticulum networking service and management tools.
- UFW firewall, AppArmor, and unattended Debian security updates.
- Hourly package-update checks, with no forced automatic reboot.

## Important limitations

- Qortal Core and Hub are installed by the official installer after the first desktop login; blockchain data and personal wallet data are not bundled.
- Reticulum Internet uplinks require Internet connectivity. Off-grid operation requires separately configured compatible hardware, such as an RNode/LoRa device.
- Hourly update checks do not mean instant updates, and major Debian release upgrades are not performed automatically.
- This is an independent community project, not an official Debian or Qortal release. It is not endorsed by either project.
- Until a verified release is published, treat the ISO as a work in progress and do not install it on a machine containing data you have not backed up.

## Current status

Check the [GitHub Actions build status](https://github.com/linuxmint110791/igor-qortal-os/actions/workflows/build-iso.yml) and the [Releases page](https://github.com/linuxmint110791/igor-qortal-os/releases).

A downloadable ISO should be announced only after the build workflow succeeds and the ISO verification step passes.

## Shareable posts

### English

I'm building **Igorcoin Qortal OS** — an independent Debian-based Linux desktop project focused on bringing KDE Plasma, Wayland, Qortal setup, and Reticulum networking tools together.

The project is still in development. I'm working on automated ISO builds and verification before publishing a test image.

Follow the project and its build progress:
https://github.com/linuxmint110791/igor-qortal-os

### Eesti keeles

Ehitan **Igorcoin Qortal OS-i** – sõltumatut Debianil põhinevat Linuxi töölauaoperatsioonisüsteemi, mille eesmärk on ühendada KDE Plasma, Wayland, Qortali paigaldusvahendid ja Reticulumi võrgutööriistad.

Projekt on veel arenduses. Enne test-ISO avaldamist kontrollin automaatse ehituse ja ISO töökindluse üle.

Jälgi projekti ja ehituse edenemist:
https://github.com/linuxmint110791/igor-qortal-os

## Suggested tags

`linux` `debian` `kde-plasma` `wayland` `qortal` `reticulum-network` `live-iso` `calamares`

