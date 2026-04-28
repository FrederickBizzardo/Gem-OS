#!/bin/bash
set -e

# GemOS Ultra-Fast Build Script
ROOTFS_DIR="rootfs_temp"
DISK_IMAGE="gemos.img"
INITRD_PATH="kernel/initrd.gz"
mkdir -p downloads kernel

# 1. RootFS Handling
if [ ! -f "downloads/debian_rootfs.tar.xz" ]; then
    echo "Downloading Debian rootfs..."
    wget -c "https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260427_05:24/rootfs.tar.xz" -O downloads/debian_rootfs.tar.xz
fi

echo "Extracting rootfs (Silent & Fast)..."
rm -rf ${ROOTFS_DIR} && mkdir -p ${ROOTFS_DIR}
bsdtar -xf downloads/debian_rootfs.tar.xz -C ${ROOTFS_DIR} --no-same-owner --no-same-permissions 2>/dev/null || true

# 2. Host-side Configuration
echo "Configuring GemOS (Optimized)..."
mkdir -p ${ROOTFS_DIR}/{etc/sudoers.d,home/gemos,usr/local/bin,etc/systemd/system}
echo 'gemos:x:1000:1000:GemOS User,,,:/home/gemos:/bin/bash' >> ${ROOTFS_DIR}/etc/passwd
echo 'gemos:x:1000:' >> ${ROOTFS_DIR}/etc/group
echo 'gemos ALL=(ALL) NOPASSWD: ALL' > ${ROOTFS_DIR}/etc/sudoers.d/gemos
chmod 0440 ${ROOTFS_DIR}/etc/sudoers.d/gemos
echo 'gemos' > ${ROOTFS_DIR}/etc/hostname
echo '127.0.0.1 localhost gemos' > ${ROOTFS_DIR}/etc/hosts

# Disable problematic services for fast boot
ln -sf /dev/null ${ROOTFS_DIR}/etc/systemd/system/systemd-update-utmp.service
ln -sf /dev/null ${ROOTFS_DIR}/etc/systemd/system/systemd-update-utmp-runlevel.service
ln -sf /dev/null ${ROOTFS_DIR}/etc/systemd/system/systemd-journal-flush.service
ln -sf /dev/null ${ROOTFS_DIR}/etc/systemd/system/e2scrub_reap.service

# 3. Build Disk Image
echo "Building gemos.img (Sparse)..."
mke2fs -d ${ROOTFS_DIR} -t ext4 -F ${DISK_IMAGE} 4G

# 4. Use Full Initrd (has virtio drivers)
echo "Using full initrd with virtio drivers..."
INITRD_PATH="kernel/initrd.gz"
if [ -f "test_rootfs/boot/initrd.img-6.1.0-44-arm64" ]; then
    cp test_rootfs/boot/initrd.img-6.1.0-44-arm64 ${INITRD_PATH}
    echo "GemOS Ready (with full initrd)."
else
    echo "ERROR: Full initrd not found!"
    exit 1
fi
