#!/bin/bash

# GemOS Launcher Script - Enhanced Version
# Automatically handles installation, setup, and booting.

KERNEL="kernel/linux"
INITRD="kernel/initrd.gz"
DISK_IMAGE="gemos.img"
ROOTFS_SCRIPT="scripts/build_rootfs.sh"
DISK_BUILD_SCRIPT="scripts/build_disk.sh"

PROJECT_ROOT="/data/data/com.termux/files/home/projects/os"
cd "$PROJECT_ROOT" || exit 1

# --- Visuals ---

display_logo() {
    clear
    echo -e "\e[1;36m"
    echo "       . . . . . . . . . . . . . ."
    echo "       .-------------------------. "
    echo "      /                         /| "
    echo "     /         GemOS           / | "
    echo "    /                         /  | "
    echo "   .-------------------------.   | "
    echo "   |                         |   | "
    echo "   |   ###################   |   | "
    echo "   |   ##               ##   |   / "
    echo "   |   ##      3D       ##   |  /  "
    echo "   |   ##    Virtual    ##   | /   "
    echo "   |   ###################   |/    "
    echo "   '-------------------------'     "
    echo -e "\e[0m"
}

# --- Logic ---

check_dependencies() {
    local pkgs=("qemu-utils" "wget" "tar" "xz-utils" "qemu-system-aarch64-headless" "e2fsprogs" "cpio" "gzip" "bsdtar" "binutils")
    local missing=()

    for pkg in "${pkgs[@]}"; do
        if ! pkg list-installed "$pkg" > /dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "\e[1;33m[!] Missing required Termux packages: ${missing[*]}\e[0m"
        read -p "Would you like to install them now? (y/n): " fix
        if [[ "$fix" == "y" ]]; then
            pkg install "${missing[@]}" -y
        else
            echo "Cannot continue without dependencies."
            exit 1
        fi
    fi
}

check_installed() {
    [ -f "$DISK_IMAGE" ]
}

install_all() {
    clear
    display_logo
    echo -e "\e[1;33m[*] Starting GemOS Optimized Installation...\e[0m"
    chmod +x scripts/*.sh
    
    echo -e "\e[1;32m[1/2]\e[0m Preparing Virtual Disk..."
    ./"$DISK_BUILD_SCRIPT" > /dev/null 2>&1 || { echo -e "\e[1;31m[!] Disk build failed\e[0m"; exit 1; }
    
    echo -e "\e[1;32m[2/2]\e[0m Building RootFS and Tiny Initrd (this may take a few minutes)..."
    ./"$ROOTFS_SCRIPT" || { echo -e "\e[1;31m[!] RootFS build failed\e[0m"; exit 1; }
    
    echo -e "\e[1;36m[✓] GemOS Installation Finished Successfully!\e[0m"
    sleep 1
}

boot_vm() {
    # Extract kernel from cloud image if not done
    if [ ! -f "kernel/vmlinuz-cloud" ]; then
        echo "Extracting cloud kernel..."
        # The cloud image has vmlinuz in /boot/ inside partition 1
        # We already have it extracted in downloads/disk.raw
        debugfs -R "dump /boot/vmlinuz-6.1.0-44-arm64 kernel/vmlinuz-cloud" downloads/disk.raw?offset=$((262144*512)) > /dev/null 2>&1
    fi

    echo "Booting GemOS..."
    qemu-system-aarch64 \
        -m 1024 \
        -smp 2 \
        -cpu cortex-a57 \
        -machine virt \
        -accel tcg,thread=multi \
        -kernel "${KERNEL_CLOUD:-kernel/vmlinuz-cloud}" \
        -initrd "$INITRD" \
        -drive file="$DISK_IMAGE",if=none,id=drive0,format=raw \
        -device virtio-blk-pci,drive=drive0 \
        -nographic \
        -append "root=/dev/vda rw console=ttyAMA0 quiet" \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0
}

uninstall_gemos() {
    echo -e "\e[1;31m"
    read -p "ARE YOU SURE? This will delete the OS, ALL your data, and all downloads. (y/n): " confirm
    echo -e "\e[0m"
    if [[ "$confirm" == "y" ]]; then
        echo "Cleaning up GemOS files..."
        rm -f "$DISK_IMAGE"
        rm -rf kernel/
        rm -rf downloads/
        rm -rf rootfs_temp/
        rm -f initramfs.cpio.gz
        echo -e "\e[1;32m[✓] GemOS has been fully uninstalled.\e[0m"
        sleep 1
    else
        echo "Uninstall cancelled."
    fi
}

# --- Execution ---

display_logo
check_dependencies

if ! check_installed; then
    echo "GemOS not detected."
    read -p "Would you like to install GemOS now? (y/n): " inst
    if [[ "$inst" == "y" ]]; then
        install_all
    else
        echo "Installation cancelled."
        exit 0
    fi
fi

echo "--------------------------------"
echo " 1) Start GemOS"
echo " 2) Reinstall (Clean Setup)"
echo " 3) Run setup script inside"
echo " 4) Full Uninstall"
echo " 5) Exit"
echo "--------------------------------"
read -p "Selection: " choice

case $choice in
    1) boot_vm ;;
    2) 
        read -p "Are you sure? This deletes ALL data. (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            rm -f "$DISK_IMAGE"
            install_all
            boot_vm
        fi
        ;;
    3)
        echo "Please boot GemOS and run 'sudo gemos-setup' inside the VM."
        sleep 2
        boot_vm
        ;;
    4) uninstall_gemos ;;
    *) exit 0 ;;
esac
