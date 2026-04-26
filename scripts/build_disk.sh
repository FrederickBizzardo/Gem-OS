#!/bin/bash
set -e

# GemOS Disk Builder (ARM64) - Lightweight Version
# This script prepares the disk image file.
# The actual content is populated by build_rootfs.sh for better efficiency.

DISK_IMAGE="gemos.img"

echo "Creating 4GB sparse disk image..."
# Use truncate to create a sparse file (takes 0 bytes initially)
truncate -s 4G ${DISK_IMAGE}

echo "GemOS Disk Placeholder Created: ${DISK_IMAGE}"
