#!/bin/bash
set -e

# GemOS Disk Builder (ARM64)
# This script downloads a base Debian image and prepares it for GemOS.

IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-arm64.tar.xz"
DOWNLOAD_DIR="downloads"
DISK_IMAGE="gemos.img"

mkdir -p ${DOWNLOAD_DIR}

echo "Downloading Debian Cloud Image..."
wget -c ${IMAGE_URL} -O ${DOWNLOAD_DIR}/debian_base.tar.xz

echo "Extracting Disk Image..."
tar -xf ${DOWNLOAD_DIR}/debian_base.tar.xz -C .
# The extracted file is typically 'disk.raw'
if [ -f "disk.raw" ]; then
    mv disk.raw ${DISK_IMAGE}
fi

echo "Resizing Disk to 4GB..."
qemu-img resize ${DISK_IMAGE} 4G

echo "GemOS Disk Preparation Complete: ${DISK_IMAGE}"
