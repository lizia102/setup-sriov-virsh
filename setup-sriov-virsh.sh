#!/bin/bash
# Script: setup-sriov-virsh.sh
# Scriptwriter: lizia102
# Description: Correctly attach SR-IOV VF to VM using virsh attach-interface
# Usage: sudo ./setup-sriov-virsh.sh <PF_DEVICE> <NUM_VFS> <VM_NAME> [VF_INDEX]

set -euo pipefail

# Check parameters
if [ $# -lt 3 ]; then
    echo "Usage: $0 <PF_DEVICE> <NUM_VFS> <VM_NAME> [VF_INDEX]"
    echo "Example: $0 ens9f3np3 2 rhel9.2 0"
    echo "Example (Mellanox): $0 mlx5_0 2 rhel9.2 0"
    exit 1
fi

PF_DEVICE="$1"        # Physical Function device (e.g., ens9f3np3 or mlx5_0)
NUM_VFS="$2"          # Number of Virtual Functions to create
VM_NAME="$3"          # Target VM name
VF_INDEX="${4:-0}"    # Optional: VF index to attach (default: 0)

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Determine device class (Ethernet/Infiniband)
if [ -d "/sys/class/net/${PF_DEVICE}" ]; then
    SYSFS_CLASS="net"
elif [ -d "/sys/class/infiniband/${PF_DEVICE}" ]; then
    SYSFS_CLASS="infiniband"
else
    echo "Error: Device ${PF_DEVICE} not found in /sys/class/net or /sys/class/infiniband."
    exit 1
fi

# 1. Check SR-IOV kernel support
echo "1. Checking SR-IOV kernel support..."
if ! grep -q "sr_iov" /proc/cpuinfo && ! lsmod | grep -q "vfio_pci"; then
    echo "Loading VFIO PCI module..."
    modprobe vfio_pci
fi

# 2. Enable SR-IOV and create VFs
echo "2. Enabling SR-IOV on ${PF_DEVICE} (${SYSFS_CLASS}) with ${NUM_VFS} VFs..."
sriov_path="/sys/class/${SYSFS_CLASS}/${PF_DEVICE}/device/sriov_numvfs"
echo "${NUM_VFS}" > "${sriov_path}" || {
    echo "Error: Failed to create VFs. Check NIC/driver support."
    exit 1
}

# 3. Get VF PCI address in correct format (0000:XX:YY.Z)
VF_PCI_PATH="/sys/class/${SYSFS_CLASS}/${PF_DEVICE}/device/virtfn${VF_INDEX}"
if [ ! -d "${VF_PCI_PATH}" ]; then
    echo "Error: VF ${VF_INDEX} not found under ${PF_DEVICE}."
    exit 1
fi

# Extract full PCI address (e.g., 0000:1c:00.0)
VF_PCI=$(basename "$(readlink -f "${VF_PCI_PATH}")" | awk -F'/' '{print $1}')
if [[ ! "${VF_PCI}" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]{1}$ ]]; then
    echo "Error: Invalid PCI address format '${VF_PCI}'. Expected '0000:XX:YY.Z'."
    exit 1
fi

# 4. Attach VF to VM using virsh attach-interface
echo "4. Attaching VF ${VF_INDEX} (${VF_PCI}) to VM ${VM_NAME}..."
virsh attach-interface "${VM_NAME}" hostdev "${VF_PCI}" --managed --live --config || {
    echo "Error: Failed to attach VF. Check VM state and PCI address."
    exit 1
}

# 5. Verify attachment
echo "5. Verifying VM ${VM_NAME} devices..."
virsh dumpxml "${VM_NAME}" | grep -A5 "${VF_PCI}"

echo "Success! SR-IOV VF ${VF_PCI} attached to ${VM_NAME}."
