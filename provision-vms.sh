#!/bin/bash
set -e

BASE_VM_ID=9000
CONTROL_PLANE_ID=9001
WORKER_IDS=(9002 9003)
VM_STORAGE="local"
IMAGE_PATH="/opt/git/automated-k8s-proxmox/assets/jammy-server-cloudimg-amd64.img"
CLOUD_INIT_SNIPPETS_PATH="local:snippets/cloud-init"

echo "### [0/7] Preparing..."

# Step 1: Create base VM if it doesn't exist
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

# Step 2: Import disk if not already imported
echo "### [1/7] Importing disk..."
DISK_TARGET_PATH="/var/lib/vz/images/$BASE_VM_ID/base-${BASE_VM_ID}-disk-0.raw"
if [[ -f "$DISK_TARGET_PATH" ]]; then
    echo "→ Disk already imported as $DISK_TARGET_PATH"
else
    echo "→ Importing disk as RAW..."
    qm importdisk $BASE_VM_ID "$IMAGE_PATH" $VM_STORAGE --format raw
    qm set $BASE_VM_ID --scsi0 "$VM_STORAGE:$BASE_VM_ID/base-${BASE_VM_ID}-disk-0.raw"
fi

# Step 3: Re-create cloud-init drive
echo "### [2/7] Attaching cloud-init drive..."
CLOUD_INIT_DISK_PATH="/var/lib/vz/images/$BASE_VM_ID/vm-${BASE_VM_ID}-cloudinit.qcow2"
if [[ -f "$CLOUD_INIT_DISK_PATH" ]]; then
    echo "→ Deleting existing cloud-init disk: $CLOUD_INIT_DISK_PATH"
    rm -f "$CLOUD_INIT_DISK_PATH"
fi
qm set $BASE_VM_ID --ide2 "$VM_STORAGE:cloudinit"

# Step 4: Configure boot and console
echo "### [3/7] Configuring boot and console..."
qm set $BASE_VM_ID \
    --boot c \
    --bootdisk scsi0 \
    --serial0 socket \
    --vga serial0

# Step 5: Convert to template
echo "### [4/7] Converting to template..."
if qm template $BASE_VM_ID 2>&1 | grep -q "already a template"; then
    echo "→ Already marked as template"
else
    qm template $BASE_VM_ID
fi

# Function to delete old VM if exists
delete_if_exists() {
    local VMID=$1
    if qm status $VMID &>/dev/null; then
        echo "→ VM $VMID already exists, deleting..."
        qm destroy $VMID --purge
    fi
}

# Function to clone and configure VMs
clone_and_configure() {
    local VMID=$1
    local NAME=$2
    local CLOUD_INIT_FILE=$3

    delete_if_exists $VMID
    echo "→ Cloning $NAME as VM $VMID (full clone)"
    qm clone $BASE_VM_ID $VMID --name $NAME --full true
    qm set $VMID \
        --memory 2048 \
        --cores 2 \
        --net0 virtio,bridge=vmbr0 \
        --ide2 "$VM_STORAGE:cloudinit" \
        --cicustom "user=$CLOUD_INIT_SNIPPETS_PATH/$CLOUD_INIT_FILE"

    qm start $VMID
}

# Step 6: Clone control plane
echo "### [5/7] Cloning control-plane..."
clone_and_configure $CONTROL_PLANE_ID "control-plane" "control-plane.yaml"

# Step 7: Clone workers
echo "### [6/7] Cloning worker nodes..."
for i in "${!WORKER_IDS[@]}"; do
    VMID="${WORKER_IDS[$i]}"
    NAME="worker-$VMID"
    clone_and_configure $VMID "$NAME" "worker.yaml"
done

echo "###All VMs created and started successfully."

