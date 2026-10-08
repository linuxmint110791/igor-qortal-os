# Igorcoin Qortal OS

**Qortal on kaasas.** 🚀

Igorcoin Qortal OS is a Debian-based Linux operating-system project built around the Qortal ecosystem. The goal is a ready-to-install desktop system where Qortal is easy to install, configure and use.

> **Status:** Development / ISO testing

## 🖥️ What is included

The project is intended to provide:

- Linux desktop environment
- Wayland-first desktop setup
- Qortal Core
- Qortal Hub
- Qortal-oriented configuration and tools
- Igorcoin Qortal OS branding and wallpapers
- Installer and update helpers
- Open-source build scripts

Qortal Hub is the current primary desktop interface for Qortal. For the full node-backed experience, running a local Qortal Core is recommended. citeturn0search2turn0search5

## 💿 Install Igorcoin Qortal OS

### 1. Download the ISO

Download the latest **Igorcoin Qortal OS ISO** from the project's GitHub Actions artifacts or Releases.

Before installing on a real computer, verify the SHA256 checksum when one is provided.

### 2. Write the ISO to a USB stick

Use a USB drive with enough free capacity for the ISO.

On Linux, you can use **GNOME Disks / Disk Image Writer**, Linux Mint's image writer, or another trusted ISO-writing program.

⚠️ **Writing an ISO to a USB drive erases the contents of the selected USB drive. Check the target device carefully.**

### 3. Boot from USB

1. Insert the USB drive.
2. Restart the computer.
3. Open the computer's boot menu (commonly **F12, F11, Esc or F8**, depending on the manufacturer).
4. Select the USB drive.
5. Start Igorcoin Qortal OS.

The exact boot-menu key depends on the computer.

### 4. Install Linux

Start the installer from the live desktop.

During installation:

1. Select your language and keyboard layout.
2. Connect to the internet if available.
3. Choose the installation disk.
4. Select the appropriate disk/partitioning option.
5. Create your Linux user and password.
6. Confirm the installation.
7. Wait for the installation to finish.
8. Restart the computer and remove the USB drive when asked.

⚠️ **Disk partitioning can erase an existing operating system and personal files. Back up important data before installing.**

## 🔄 After the first boot

After installation:

1. Connect to the internet.
2. Run system updates.
3. Open **Qortal Hub**.
4. Set up or connect your Qortal Core.
5. Allow the node to synchronize.
6. Create/import your Qortal account.
7. Securely back up your Qortal seed/backup information.

Qortal's current onboarding documentation says Qortal Hub has a built-in Core Setup tool that can install the required components and configure the Core. citeturn0search2

### Recommended Qortal setup

For a full node:

**Qortal Hub → Qortal Core → synchronize → Qortal account → use Qortal**

Qortal Core requires Java 11 or newer, and Qortal's current documentation recommends running a local Core for the full node-backed experience. citeturn0search1

## 🌐 Getting started with Qortal

Once Core is synchronized, Qortal Hub provides access to the Qortal ecosystem, including wallet functions, chat, publishing and other network features. Qortal Hub also contains newer Reticulum-based communication features. citeturn0search3

For new users, Qortal provides an onboarding wizard that can help with initial setup and QORT needed for name registration. citeturn0search2

## 🏷️ Register a Qortal name

After your wallet is ready and you have the required QORT:

1. Open Qortal Hub.
2. Open the name-registration function.
3. Enter the name you want.
4. Follow the transaction confirmation steps.
5. Wait for the registration to complete.

Keep your wallet backup information safe. Losing access to your wallet can mean losing access to your Qortal account and assets.

## ⛏️ Running a Qortal node / becoming a minter

After your node is synchronized, you can learn about Qortal's minting system and requirements.

Do **not** assume that simply installing the OS automatically makes the computer a minter. Minting has its own Qortal requirements and account/security considerations.

## 🔧 Updating the system

Keep both the operating system and Qortal software updated.

For the Linux system:

```bash
sudo apt update
sudo apt upgrade
```

For Qortal, use the current release supplied through the official Qortal project rather than downloading random copies from third-party sites. Qortal Core releases are published in the official Qortal repository. citeturn0search1

## 🆘 Troubleshooting

### Qortal Hub does not start

First check whether the system is up to date and launch Qortal Hub again.

If you are using a local node, check whether Qortal Core is running and synchronized.

### Qortal Core is not synchronized

Give the node time to synchronize and make sure the computer has a working internet connection.

Do not manually download old bootstrap files unless current Qortal documentation specifically tells you to. Qortal states that automatic bootstrapping has been available since Core 2.0. citeturn0search7

### Qortal works but the node is not reachable from outside

Check the Qortal networking and port-forwarding documentation for your router/network configuration. A local node can work without being publicly reachable, but correct networking can improve node participation.

## 📦 Project structure

```text
igor-qortal-os/
├── .github/
│   └── workflows/
│       └── build-iso.yml
├── igor-qortal-os-v2-with-logo-embedded.sh
├── README.md
└── ...
```

The GitHub Actions workflow builds and verifies the ISO automatically.

## 🧪 Development status

This is an open-source development project.

The ISO should be considered **testing software** until a stable release has been explicitly announced.

Test it in a virtual machine first when possible. Do not install a development ISO on a machine containing important data without a backup.

## 🤝 Contributing

Contributions, bug reports, testing and improvements are welcome.

If you find a problem:

1. Reproduce it if possible.
2. Record the exact error.
3. Include your hardware and OS information.
4. Open a GitHub issue or submit a pull request.

## 📚 Official Qortal resources

- Qortal Wiki: https://wiki.qortal.org/
- Qortal onboarding: https://qortal.dev/onboarding
- Qortal Core: https://github.com/Qortal/qortal
- Qortal Hub: https://github.com/Qortal/Qortal-Hub
- Qortal Hub releases: https://github.com/Qortal/Qortal-Hub/releases

The old **Qortal UI** should not be used as the basis for new installations; Qortal's repository marks it as deprecated and directs users toward Qortal Hub. citeturn0search4

## 📜 License

See the license files in this repository and the licenses of the upstream projects included by the build.

---

**Igorcoin Qortal OS — Qortal on kaasas.** 🚀
