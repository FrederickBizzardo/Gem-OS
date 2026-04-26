#!/bin/bash
set -e

ROOTFS_DIR="rootfs_temp"
mkdir -p downloads

# Try multiple URLs for reliability (ARM64)
URLS=(
    "https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260425_05:24/rootfs.tar.xz"
    "https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260424_05:24/rootfs.tar.xz"
)

SUCCESS=0
for URL in "${URLS[@]}"; do
    echo "Attempting to download Debian rootfs from: ${URL}"
    if wget -c "${URL}" -O downloads/debian_rootfs.tar.xz; then
        SUCCESS=1
        break
    fi
done

if [ $SUCCESS -eq 0 ]; then
    echo "Error: Failed to download Debian rootfs from all sources."
    exit 1
fi

echo "Preparing rootfs directory..."
rm -rf ${ROOTFS_DIR}
mkdir -p ${ROOTFS_DIR}

echo "Extracting rootfs..."
# Use --no-same-owner and --no-same-permissions to avoid Android FS issues
bsdtar -xf downloads/debian_rootfs.tar.xz -C ${ROOTFS_DIR} --no-same-owner --no-same-permissions || echo "Extraction had some issues, continuing..."

echo "Configuring GemOS..."
# Directly write to files
echo 'gemos:x:1000:1000:GemOS User,,,:/home/gemos:/bin/bash' >> ${ROOTFS_DIR}/etc/passwd
echo 'gemos:x:1000:' >> ${ROOTFS_DIR}/etc/group
mkdir -p ${ROOTFS_DIR}/etc/sudoers.d
echo 'gemos ALL=(ALL) NOPASSWD: ALL' > ${ROOTFS_DIR}/etc/sudoers.d/gemos
chmod 0440 ${ROOTFS_DIR}/etc/sudoers.d/gemos
mkdir -p ${ROOTFS_DIR}/home/gemos

echo 'gemos' > ${ROOTFS_DIR}/etc/hostname
echo '127.0.0.1 localhost gemos' > ${ROOTFS_DIR}/etc/hosts

mkdir -p ${ROOTFS_DIR}/etc/network
cat <<EOF > ${ROOTFS_DIR}/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

mkdir -p ${ROOTFS_DIR}/usr/local/sbin
cat <<EOF > ${ROOTFS_DIR}/usr/local/sbin/service
#!/bin/bash
ACTION=\$2
SERVICE=\$1
if [ -x "/etc/init.d/\$SERVICE" ]; then
    /etc/init.d/\$SERVICE \$ACTION
else
    echo "Service \$SERVICE not found."
fi
EOF
chmod +x ${ROOTFS_DIR}/usr/local/sbin/service

mkdir -p ${ROOTFS_DIR}/usr/local/bin
cat <<EOF > ${ROOTFS_DIR}/usr/local/bin/gemos-setup
#!/bin/bash
set -e
echo "GemOS Initial Setup..."
apt update
apt install -y sudo curl iptables kmod docker.io ca-certificates iproute2
echo "Adding gemos to docker group..."
groupadd -f docker
usermod -aG docker gemos
echo "GemOS setup complete! You can now run 'sudo service docker start'."
EOF
chmod +x ${ROOTFS_DIR}/usr/local/bin/gemos-setup

# 7. Create the 'init' script for initramfs
cat <<EOF > ${ROOTFS_DIR}/init
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run

echo "Welcome to GemOS (Debian-based)!"
echo "Starting GemOS services..."

# Fix permissions
chmod 1777 /tmp
chmod 1777 /run

# Try to start networking if possible
ip link set lo up

exec /bin/bash
EOF
chmod +x ${ROOTFS_DIR}/init

echo "Packaging into initramfs.cpio.gz..."
cd ${ROOTFS_DIR}
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs.cpio.gz
cd ..

echo "Rootfs preparation complete. Created initramfs.cpio.gz"
