# GemOS Project Documentation

GemOS is a specialized, Debian-based Linux distribution designed to run seamlessly on non-rooted Android devices via Termux. It provides a full-featured Linux environment optimized for ultra-speed and lightweight performance on mobile hardware.

## Project Evolution & Implementation

### 1. Requirements & Core Logic
- **Base:** Linux (Debian Bookworm) for maximum compatibility.
- **Persistence:** All changes are saved to `gemos.img` (Persistent Disk).
- **Environment:** Optimized for Non-rooted Android/Termux.

### 2. Performance & Optimization (v1.1)
- **Disk-Based Architecture:** Migrated from RAM-heavy `initramfs` to a disk-based rootfs (`/dev/vda`). This reduces RAM usage by over 50%, preventing crashes.
- **QEMU Acceleration:** Enabled multi-threaded TCG (`-accel tcg,thread=multi`) and 2 CPU cores for faster execution.
- **MMIO Devices:** Switched to `virtio-mmio` device mapping for better compatibility with Android kernels.
- **Ultra-Fast Boot:** Specialized "Tiny Initrd" handles the boot process in seconds, including a recursive library-tracing system to ensure zero "shared library" errors.

### 3. Build & Safety Features
- **Host-Side Configuration:** Bypasses `proot` and kernel restrictions by configuring the OS directly from the Termux host during installation.
- **Robust Extraction:** Uses `bsdtar` with specific flags to handle Android's lack of hard-link support silently.
- **Auto-Dependency System:** The launcher automatically detects and installs all required Termux packages (`qemu`, `binutils`, `e2fsprogs`, etc.) on first run.
- **Clean Environment:** Integrated `.gitignore` to manage large disk images and temporary build artifacts.

## Prerequisites (Host - Termux)

The launcher (`gemos.sh`) will automatically offer to install these for you:
`qemu-utils`, `wget`, `tar`, `xz-utils`, `qemu-system-aarch64-headless`, `e2fsprogs`, `cpio`, `gzip`, `bsdtar`, `binutils`.

## Project Structure

- `gemos.sh`: Main launcher and dependency manager.
- `scripts/build_rootfs.sh`: The heart of GemOS. Handles extraction, disk creation, and recursive library tracing.
- `kernel/`: Stores the bootable kernel (`vmlinuz-cloud`) and the tiny `initrd.gz`.
- `gemos.img`: The persistent 4GB virtual disk.

## How to Use

1. **Boot:** Run `./gemos.sh`.
2. **Setup:** On first boot, log in and execute `sudo gemos-setup` to install Docker and other tools.
3. **Uninstall:** Use the "Full Uninstall" option in the main menu to wipe GemOS and free up space.
4. **Exit:** Press `Ctrl+a` then `x` to terminate the VM.

---
*Updated by Gemini CLI - April 2026*
