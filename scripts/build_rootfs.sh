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
    wget -c "https://images.linuxcontainers.org/images/debian/bookworm/arm64/default/20260425_05:24/rootfs.tar.xz" -O downloads/debian_rootfs.tar.xz
fi

echo "Extracting rootfs (Silent & Fast)..."
rm -rf ${ROOTFS_DIR} && mkdir -p ${ROOTFS_DIR}
bsdtar -xf downloads/debian_rootfs.tar.xz -C ${ROOTFS_DIR} --no-same-owner --no-same-permissions 2>/dev/null || true

# 2. Host-side Configuration
echo "Configuring GemOS (Optimized)..."
mkdir -p ${ROOTFS_DIR}/{etc/sudoers.d,home/gemos,usr/local/bin}
echo 'gemos:x:1000:1000:GemOS User,,,:/home/gemos:/bin/bash' >> ${ROOTFS_DIR}/etc/passwd
echo 'gemos:x:1000:' >> ${ROOTFS_DIR}/etc/group
echo 'gemos ALL=(ALL) NOPASSWD: ALL' > ${ROOTFS_DIR}/etc/sudoers.d/gemos
chmod 0440 ${ROOTFS_DIR}/etc/sudoers.d/gemos
echo 'gemos' > ${ROOTFS_DIR}/etc/hostname
echo '127.0.0.1 localhost gemos' > ${ROOTFS_DIR}/etc/hosts

# 3. Build Disk Image
echo "Building gemos.img (Sparse)..."
mke2fs -d ${ROOTFS_DIR} -t ext4 -F ${DISK_IMAGE} 4G

# 4. Build Robust Initrd
echo "Building Lightweight Initrd..."
INITRD_TEMP="initrd_temp"
rm -rf ${INITRD_TEMP} && mkdir -p ${INITRD_TEMP}/{bin,sbin,dev,proc,sys,mnt,run,lib,lib/aarch64-linux-gnu}

# Cache file list once for speed
FILES_CACHE=$(find ${ROOTFS_DIR} -type f,l)

# Recursive library tracer to prevent "shared library not found" errors
copy_lib_recursive() {
    local lib_name=$1
    [ -f "${INITRD_TEMP}/lib/aarch64-linux-gnu/$lib_name" ] && return 0
    
    local lib_path=$(echo "$FILES_CACHE" | grep "/$lib_name$" | head -n 1)
    if [ -n "$lib_path" ]; then
        cp -L "$lib_path" "${INITRD_TEMP}/lib/aarch64-linux-gnu/"
        # Trace sub-dependencies
        local deps=$(strings "$lib_path" | grep -E "\.so\." | grep -v "/" || true)
        for dep in $deps; do
            copy_lib_recursive "$dep"
        done
    fi
}

copy_exe() {
    local name=$1
    local dest=$2
    local found=$(echo "$FILES_CACHE" | grep "/$name$" | head -n 1)
    
    if [ -z "$found" ]; then
        echo "Note: $name not found, skipping..."
        return 0
    fi
    
    cp -L "$found" "$dest"
    
    # Trace and copy libraries recursively
    local libs=$(strings "$found" | grep -E "\.so\." | grep -v "/" || true)
    for lib in $libs; do
        copy_lib_recursive "$lib"
    done
}

# Essential binaries (Required)
copy_exe "dash" "${INITRD_TEMP}/bin/sh"
copy_exe "mount" "${INITRD_TEMP}/bin/mount"
copy_exe "switch_root" "${INITRD_TEMP}/sbin/switch_root"

# Utility binaries
copy_exe "ls" "${INITRD_TEMP}/bin/ls"
copy_exe "sleep" "${INITRD_TEMP}/bin/sleep"
copy_exe "dmesg" "${INITRD_TEMP}/bin/dmesg"

# Critical: Linker
LINKER_PATH=$(echo "$FILES_CACHE" | grep "/ld-linux-aarch64.so.1$" | head -n 1)
if [ -n "$LINKER_PATH" ]; then
    cp -L "$LINKER_PATH" "${INITRD_TEMP}/lib/"
fi
ln -s /lib/aarch64-linux-gnu ${INITRD_TEMP}/lib64 2>/dev/null || true

# Init Script
cat <<EOF > ${INITRD_TEMP}/init
#!/bin/sh
export PATH=/bin:/sbin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo "GemOS Rapid Boot..."
sleep 1

# Wait for disk to appear
if [ ! -b /dev/vda ]; then
    echo "Waiting for disk..."
    sleep 2
fi

# Attempt mount
mount -t ext4 /dev/vda /mnt || mount /dev/vda /mnt

if [ -d /mnt/usr ]; then
    mount --move /sys /mnt/sys
    mount --move /proc /mnt/proc
    mount --move /dev /mnt/dev
    echo "Starting GemOS..."
    exec switch_root /mnt /sbin/init
else
    echo "Mount failed, dropping to rescue shell."
    # Ensure a shell is always available
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
