#!/bin/bash
KERNEL="kernel/linux"
INITRD="kernel/initrd.gz"
DISK="gemos.img"

echo "Starting GemOS (ARM64)..."
tput smcup
trap 'tput rmcup' EXIT
qemu-system-aarch64 \
    -m 2048 \
    -cpu cortex-a57 \
    -machine virt \
    -kernel $KERNEL \
    -initrd $INITRD \
    -drive file=$DISK,if=virtio,format=raw \
    -nographic \
    -append "root=/dev/vda1 rw console=ttyAMA0 quiet" \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-device,netdev=net0
