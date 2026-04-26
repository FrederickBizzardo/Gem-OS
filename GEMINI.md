# GemOS Project Documentation

GemOS is a specialized, Debian-based Linux distribution designed to run seamlessly on non-rooted Android devices via Termux. It provides a full-featured Linux environment with `apt`, `sudo`, and a custom kernel optimized for Docker.

## Project Evolution & Implementation

### 3. Performance & Optimization (v1.1)
- **Disk-Based Booting:** Migrated from RAM-heavy `initramfs` to a persistent disk-based root filesystem (`/dev/vda`). This reduces RAM usage by over 50%.
- **QEMU Acceleration:** Enabled multi-threaded TCG and optimized device models (`virtio-pci`) for better performance on Android.
- **Lightweight Initrd:** Replaced the full-OS initrd with a tiny, specialized bootloader that handles the switch to the disk rootfs.
- **Responsive GUI:** Removed artificial delays in the launcher and improved installation feedback.

## Prerequisites (Host - Termux)

To build and run GemOS, the following packages must be installed on your Termux host:

```bash
pkg install qemu-utils wget tar xz-utils qemu-system-aarch64-headless e2fsprogs cpio gzip bsdtar
```

## Project Structure

- `gemos.sh`: The primary launcher. Handles dependency checks, downloads missing components, and boots the OS.
- `scripts/build_disk.sh`: Downloads the official Debian Cloud ARM64 image, extracts it, and resizes it to 4GB.
- `scripts/build_kernel.sh`: Reference script for building a Docker-optimized kernel from source (used if pre-builts are not desired).
- `kernel/`: Stores the bootable kernel (`linux`) and `initrd.gz`.
- `downloads/`: Temporary storage for raw image artifacts.
- `gemos.img`: The persistent virtual disk for GemOS.

## Customizations & Environment

- **Branding:** Removed Debian-specific login banners in `/etc/issue` and `/etc/motd`, replacing them with custom GemOS branding.
- **Dashboard:** Added a `/usr/local/bin/gemos-dashboard` script and integrated it into the shell profile for a clean, customized login experience.
- **UI Isolation:** Updated `gemos.sh` to use terminal alternate screen buffers (`tput smcup`/`rmcup`), isolating the VM output from the host terminal and preventing scrolling into host history.
- **Exit:** To exit GemOS and return to Termux, use the QEMU escape sequence: press `Ctrl+a` then `x`. (Note: Typing `exit` inside GemOS only logs you out of the current shell session).

## Core Features
- **Persistence:** All changes made inside GemOS are saved to `gemos.img`.
- **Networking:** Pre-configured with DHCP on `eth0`. Ports are mapped (e.g., SSH on 2222) for Termux-to-GemOS communication.
- **Setup Script:** Includes `/usr/local/bin/gemos-setup` inside the guest to automate Docker installation.

## How to Use

1. **Boot:** Run `./gemos.sh`.
2. **Setup:** On the first boot, log in and execute `sudo gemos-setup`.
3. **Docker:** Use `sudo service docker start` followed by `sudo docker run hello-world`.
4. **Exit:** Press `Ctrl+a` then `x` to terminate the VM and return to the Termux host. Typing `exit` inside the VM will only log you out of your account.

---
*Updated by Gemini CLI - April 2026*
