#!/bin/bash
set -e

BASE_VM_ID=9000
CONTROL_PLANE_ID=9001
WORKER_IDS=(9002 9003)
VM_STORAGE="local"
IMAGE_PATH="/opt/git/automated-k8s-proxmox/assets/jammy-server-cloudimg-amd64.img"
CLOUD_INIT_SNIPPETS_PATH="local:snippets"

# --------- PRE-FLIGHT CLEANUP ---------
echo "### [0/7] Pre-flight: Cleanup leftover VMs and disks"

ALL_IDS=($CONTROL_PLANE_ID ${WORKER_IDS[@]})
for VMID in "${ALL_IDS[@]}"; do
    if qm status $VMID &>/dev/null; then
        echo "→ Purging existing VM $VMID"
        qm destroy $VMID --purge || true
        # Wait for config to disappear
        while [ -e "/etc/pve/qemu-server/$VMID.conf" ]; do
            echo "  ...waiting for config /etc/pve/qemu-server/$VMID.conf"
            sleep 1
        done
    fi
    if [ -d /var/lib/vz/images/$VMID ]; then
        echo "→ Removing image directory for $VMID"
        rm -rf /var/lib/vz/images/$VMID
    fi
    # Double-check for deletion (sometimes Proxmox is slow)
    while [ -d /var/lib/vz/images/$VMID ]; do
        echo "  ...waiting for /var/lib/vz/images/$VMID to disappear"
        sleep 1
        rm -rf /var/lib/vz/images/$VMID
    done
done

echo "### [1/7] Prepare base VM $BASE_VM_ID"
if qm status $BASE_VM_ID &>/dev/null; then
    echo "→ Base VM $BASE_VM_ID already exists"
else
    echo "→ Creating base VM $BASE_VM_ID"
    qm create $BASE_VM_ID \
        --name ubuntu-template \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge=vmbr0 \
        --serial0 socket \
        --vga serial0 \
        --ostype l26 \
        --scsihw virtio-scsi-pci
fi

echo "### [2/7] Importing cloud image to base VM"
DISK_TARGET_PATH="/var/lib/vz/images/$BASE_VM_ID/base-${BASE_VM_ID}-disk-0.raw"
if [[ -f "$DISK_TARGET_PATH" ]]; then
    echo "→ Disk already imported as $DISK_TARGET_PATH"
else
    echo "→ Importing disk as RAW..."
    qm importdisk $BASE_VM_ID "$IMAGE_PATH" $VM_STORAGE --format raw
    qm set $BASE_VM_ID --scsi0 "$VM_STORAGE:$BASE_VM_ID/vm-${BASE_VM_ID}-disk-0.raw"
    # Rename disk for easier tracking
    mv "/var/lib/vz/images/$BASE_VM_ID/vm-${BASE_VM_ID}-disk-0.raw" "$DISK_TARGET_PATH"
    qm set $BASE_VM_ID --scsi0 "$VM_STORAGE:$BASE_VM_ID/base-${BASE_VM_ID}-disk-0.raw"
fi

echo "### [3/7] Attaching cloud-init drive to base VM"
CLOUD_INIT_DISK_PATH="/var/lib/vz/images/$BASE_VM_ID/vm-${BASE_VM_ID}-cloudinit.qcow2"
if [[ -f "$CLOUD_INIT_DISK_PATH" ]]; then
    echo "→ Deleting existing cloud-init disk: $CLOUD_INIT_DISK_PATH"
    rm -f "$CLOUD_INIT_DISK_PATH"
fi
qm set $BASE_VM_ID --ide2 "$VM_STORAGE:cloudinit"

echo "### [4/7] Configuring boot and console for base VM"
qm set $BASE_VM_ID \
    --boot c \
    --bootdisk scsi0 \
    --serial0 socket \
    --vga serial0

echo "### [5/7] Converting base VM to template (if needed)"
if grep -q '^template: 1' /etc/pve/qemu-server/$BASE_VM_ID.conf 2>/dev/null; then
    echo "→ Already marked as template"
else
    qm template $BASE_VM_ID
fi

# --------- CLONE AND CONFIGURE ---------

clone_and_configure() {
    local VMID=$1
    local NAME=$2
    local CLOUD_INIT_FILE=$3

    echo "→ Cloning $NAME as VM $VMID (full clone)"
    qm clone $BASE_VM_ID $VMID --name $NAME --full true
    qm set $VMID \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge=vmbr0 \
        --cicustom "user=$CLOUD_INIT_SNIPPETS_PATH/$CLOUD_INIT_FILE"
    qm start $VMID
}

echo "### [6/7] Cloning control-plane node"
clone_and_configure $CONTROL_PLANE_ID "control-plane" "control-plane.yaml"

echo "### [7/7] Cloning worker nodes"
for i in "${!WORKER_IDS[@]}"; do
    VMID="${WORKER_IDS[$i]}"
    NAME="worker-$VMID"
    clone_and_configure $VMID "$NAME" "worker.yaml"
done

echo "### All VMs created and started successfully!"

