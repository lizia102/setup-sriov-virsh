# SR-IOV VF Attachment Script README

## 1. Overview
This script, named `sriov_setup.sh`, is designed to correctly attach a Single Root I/O Virtualization (SR-IOV) Virtual Function (VF) to a virtual machine (VM) using the `virsh attach-interface` command. It automates several steps including checking SR-IOV kernel support, enabling SR-IOV, creating VFs, getting the VF PCI address, checking if the VF is already attached, and finally attaching the VF to the specified VM.

## 2. Prerequisites
- **Root Privileges**: The script must be run as the root user because it modifies system-level settings such as creating VFs and attaching them to VMs.
- **SR-IOV Support**: The system's CPU and network interface card (NIC) should support SR-IOV. The script will attempt to load the `vfio_pci` module if SR-IOV support is not detected.
- **`virsh` Utility**: The `virsh` command-line tool should be installed and properly configured to manage virtual machines.
- **Target VM**: The target virtual machine should be created and in a state where network interfaces can be attached.

## 3. Usage

### 3.1 Command Syntax
```
sudo ./setup-sriov-virsh.sh <PF_DEVICE> <NUM_VFS> <VM_NAME> [VF_INDEX]
```

### 3.2 Parameter Explanation
- `<PF_DEVICE>`: The name of the Physical Function device, such as `ens9f3np3` for Ethernet or `mlx5_0` for Mellanox devices.
- `<NUM_VFS>`: The number of Virtual Functions to create on the specified Physical Function.
- `<VM_NAME>`: The name of the target virtual machine to which the VF will be attached.
- `[VF_INDEX]` (Optional): The index of the VF to attach. The default value is `0`.

### 3.3 Examples
```bash
sudo ./setup-sriov-virsh.sh ens9f3np3 2 rhel9.2 0
sudo ./setup-sriov-virsh.sh mlx5_0 2 rhel9.2 0
```

## 4. Script Execution Steps
1. **Parameter and Privilege Checks**:
    - The script first checks if the required number of parameters are provided. If not, it displays the correct usage and exits.
    - It then verifies that the script is being run as the root user. If not, an error message is displayed, and the script exits.
2. **Determine Device Class**:
    - The script checks if the specified `PF_DEVICE` exists in either `/sys/class/net` or `/sys/class/infiniband` and sets the appropriate device class (`net` or `infiniband`).
3. **Check SR-IOV Kernel Support**:
    - It checks if the `sr_iov` flag is present in `/proc/cpuinfo` and if the `vfio_pci` module is loaded. If not, it attempts to load the `vfio_pci` module.
4. **Enable SR-IOV and Create VFs**:
    - The script enables SR-IOV on the specified `PF_DEVICE` and creates the specified number of VFs. If the current number of VFs is already greater than or equal to the requested number, no changes are made.
5. **Get VF PCI Address**:
    - It retrieves the PCI address of the specified VF in the correct format (`0000:XX:YY.Z`).
6. **Check VF Attachment**:
    - The script checks if the VF is already attached to the target VM. If it is, a warning message is displayed, and the script exits. Otherwise, it attaches the VF to the VM.
7. **Verify Attachment**:
    - Finally, the script verifies the attachment by displaying relevant information from the VM's XML configuration.

## 5. Error Handling
The script includes comprehensive error handling. If any step fails, an appropriate error message is displayed, and the script exits with a non-zero status code.

## 6. Notes
- If the VF is already attached to the VM, the script will not attempt to attach it again. You can specify a different `VF_INDEX` to attach another VF.
- Make sure the target VM is in a state where network interfaces can be attached. Otherwise, the attachment may fail.
- If you encounter issues with creating VFs, check the NIC and driver support.