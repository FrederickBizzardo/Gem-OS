# GemOS

GemOS is a minimal, Debian-based Linux distribution designed to run on non-rooted Android via Termux using QEMU.

## Features
- **Debian Base:** Access to the full Debian repository (`apt`).
- **Sudo:** Pre-configured `sudo` for administrative tasks.
- **Service Management:** Standard `service` command support.
- **Docker Support:** Custom-optimized kernel for running Docker containers.
- **Non-Root:** Runs entirely in user-space on Termux.

## Quick Start

1. **Permissions:** Ensure the scripts are executable.
   ```bash
   chmod +x gemos.sh scripts/*.sh
   ```

2. **Boot GemOS:**
   ```bash
   ./gemos.sh
   ```

3. **Inside GemOS:**
   On first boot, run the setup script to install Docker and other utilities:
   ```bash
   sudo gemos-setup
   ```

4. **Run Docker:**
   ```bash
   sudo service docker start
   sudo docker run hello-world
   ```

## Repository Structure
- `gemos.sh`: Main launcher for Termux.
- `scripts/build_rootfs.sh`: Generates the GemOS filesystem.
- `scripts/build_kernel.sh`: (Optional) Builds the Linux kernel from source.
- `kernel/`: Contains the bootable kernel image.
- `rootfs_temp/`: Temporary directory for rootfs assembly.
