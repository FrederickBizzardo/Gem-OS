#!/bin/bash
set -e

KERNEL_VERSION="6.6.21"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"

echo "Downloading Linux Kernel ${KERNEL_VERSION}..."
wget -c ${KERNEL_URL} -P downloads/

echo "Extracting Kernel..."
tar -xf downloads/linux-${KERNEL_VERSION}.tar.xz -C kernel/ --strip-components=1

cd kernel

echo "Configuring Kernel for Docker..."
make defconfig

# Enable Docker requirements
./scripts/config --enable NAMESPACES
./scripts/config --enable NET_NS
./scripts/config --enable PID_NS
./scripts/config --enable IPC_NS
./scripts/config --enable UTS_NS
./scripts/config --enable CGROUPS
./scripts/config --enable CGROUP_CPUACCT
./scripts/config --enable CGROUP_DEVICE
./scripts/config --enable CGROUP_FREEZER
./scripts/config --enable CGROUP_SCHED
./scripts/config --enable CPUSETS
./scripts/config --enable MEMCG
./scripts/config --enable KEYS
./scripts/config --enable VETH
./scripts/config --enable BRIDGE
./scripts/config --enable OVERLAY_FS
./scripts/config --enable IP_NF_FILTER
./scripts/config --enable IP_NF_TARGET_MASQUERADE
./scripts/config --enable NETFILTER_XT_MATCH_ADDRTYPE
./scripts/config --enable NETFILTER_XT_MATCH_CONNTRACK
./scripts/config --enable NF_NAT
./scripts/config --enable SECCOMP
./scripts/config --enable DEVTMPFS
./scripts/config --enable DEVTMPFS_MOUNT

echo "Building Kernel (this may take a while)..."
make -j$(nproc) bzImage
