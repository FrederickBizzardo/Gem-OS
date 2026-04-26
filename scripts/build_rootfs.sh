#!/bin/bash
set -e

ROOTFS_DIR="rootfs_temp"
DISK_IMAGE="gemos.img"
INITRD_PATH="kernel/initrd.gz"
mkdir -p downloads kernel

# 1. Download/Verify RootFS
URLS=(
    "https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260425_05:24/rootfs.tar.xz"
    "https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260424_05:24/rootfs.tar.xz"
)

SUCCESS=0
if [ ! -f "downloads/debian_rootfs.tar.xz" ]; then
    for URL in "${URLS[@]}"; do
        echo "Downloading Debian rootfs..."
        if wget -c "${URL}" -O downloads/debian_rootfs.tar.xz; then SUCCESS=1; break; fi
    done
else
    SUCCESS=1
fi
[ $SUCCESS -eq 0 ] && { echo "Download failed"; exit 1; }

# 2. Extract
echo "Extracting rootfs..."
rm -rf ${ROOTFS_DIR} && mkdir -p ${ROOTFS_DIR}
tar -xJf downloads/debian_rootfs.tar.xz -C ${ROOTFS_DIR} --no-same-owner --no-same-permissions || true

# 3. Configure Guest
echo "Configuring GemOS..."
mkdir -p ${ROOTFS_DIR}/{etc/sudoers.d,home/gemos,usr/local/bin}
echo 'gemos:x:1000:1000:GemOS User,,,:/home/gemos:/bin/bash' >> ${ROOTFS_DIR}/etc/passwd
echo 'gemos:x:1000:' >> ${ROOTFS_DIR}/etc/group
echo 'gemos ALL=(ALL) NOPASSWD: ALL' > ${ROOTFS_DIR}/etc/sudoers.d/gemos
chmod 0440 ${ROOTFS_DIR}/etc/sudoers.d/gemos
echo 'gemos' > ${ROOTFS_DIR}/etc/hostname
echo '127.0.0.1 localhost gemos' > ${ROOTFS_DIR}/etc/hosts

# 4. Build Disk Image
echo "Building gemos.img..."
mke2fs -d ${ROOTFS_DIR} -t ext4 -F ${DISK_IMAGE} 4G

# 5. Build Robust Initrd
echo "Building Robust Initrd..."
INITRD_TEMP="initrd_temp"
rm -rf ${INITRD_TEMP} && mkdir -p ${INITRD_TEMP}/{bin,sbin,dev,proc,sys,mnt,run,lib,lib/aarch64-linux-gnu}

# Helper: Copy binary and its libraries (Surgical & Lightweight)
copy_exe() {
    local src_name=$1
    local dest_path=$2
    local found=$(find ${ROOTFS_DIR} -name "$src_name" -type f,l | head -n 1)
    [ -z "$found" ] && { echo "Warning: $src_name not found"; return 1; }
    
    cp -L "$found" "$dest_path"
    
    # Resolving libraries using strings to keep initrd tiny
    local libs=$(strings "$found" | grep -E "\.so\." | grep -v "/" || true)
    for lib in $libs; do
        local lib_found=$(find ${ROOTFS_DIR} -name "$lib" -type f,l 2>/dev/null | head -n 1)
        if [ -n "$lib_found" ]; then
            cp -L "$lib_found" "${INITRD_TEMP}/lib/aarch64-linux-gnu/" 2>/dev/null || true
        fi
    done
}

# Essential Tools for Booting
copy_exe "dash" "${INITRD_TEMP}/bin/sh"
copy_exe "mount" "${INITRD_TEMP}/bin/mount"
copy_exe "switch_root" "${INITRD_TEMP}/sbin/switch_root"
copy_exe "ls" "${INITRD_TEMP}/bin/ls"
copy_exe "sleep" "${INITRD_TEMP}/bin/sleep"
copy_exe "insmod" "${INITRD_TEMP}/bin/insmod"

# Ensure linker is in correct path
cp -L $(find ${ROOTFS_DIR} -name "ld-linux-aarch64.so.1" | head -n 1) "${INITRD_TEMP}/lib/"
ln -s /lib/aarch64-linux-gnu ${INITRD_TEMP}/lib64 2>/dev/null || true

# Include essential kernel modules
if [ -d "modules" ]; then
    KVER=$(ls modules/ | head -n 1)
    mkdir -p ${INITRD_TEMP}/lib/modules/${KVER}
    cp -r modules/${KVER} ${INITRD_TEMP}/lib/modules/
fi

# Init Script
cat <<EOF > ${INITRD_TEMP}/init
#!/bin/sh
export PATH=/bin:/sbin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo "GemOS Ultra-Fast Boot..."

# Load drivers
KVER=\$(ls /lib/modules)
MOD_DIR="/lib/modules/\$KVER/kernel"
load_mod() {
    m_path=\$(find \$MOD_DIR -name "\$1.ko*" | head -n 1)
    [ -n "\$m_path" ] && insmod \$m_path
}

load_mod virtio
load_mod virtio_ring
load_mod virtio_pci
load_mod virtio_blk
load_mod ext4

# Small wait for disk
sleep 1
[ ! -b /dev/vda ] && sleep 2

mount -t ext4 /dev/vda /mnt || mount /dev/vda /mnt

if [ -x /mnt/sbin/init ]; then
    mount --move /sys /mnt/sys
    mount --move /proc /mnt/proc
    mount --move /dev /mnt/dev
    echo "GemOS Started."
    exec switch_root /mnt /sbin/init
else
    echo "Mount failed, dropping to shell."
    exec /bin/sh
fi
EOF
chmod +x ${INITRD_TEMP}/init

# Package
cd ${INITRD_TEMP}
find . | cpio -H newc -o | gzip -1 > ../${INITRD_PATH}
cd ..
rm -rf ${ROOTFS_DIR} ${INITRD_TEMP}
echo "GemOS Ready."
