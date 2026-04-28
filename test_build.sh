#!/bin/bash
# Mocking environment for testing
ROOTFS_DIR="test_rootfs"
RAW_DISK="downloads/disk.raw"
OFFSET=$((262144 * 512))

echo "Test 1: Can we extract the full RootFS from the Cloud Image?"
if [ -f "$RAW_DISK" ]; then
    mkdir -p $ROOTFS_DIR
    debugfs -R "rdump / $ROOTFS_DIR" "$RAW_DISK?offset=$OFFSET" > /dev/null 2>&1
    if [ -f "$ROOTFS_DIR/etc/debian_version" ]; then
        echo "SUCCESS: RootFS extracted from Cloud Image."
    else
        echo "FAILURE: RootFS extraction failed."
    fi
else
    echo "SKIPPED: Raw disk not found."
fi
