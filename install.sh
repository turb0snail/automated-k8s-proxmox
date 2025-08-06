#!/bin/bash
# install.sh — GCP-compatible Proxmox VE installer that preserves g8amin_salam SSH

set -e

echo "Starting Proxmox VE installation for Debian 11..."

### 1. Verify OS ###
if ! grep -q "bullseye" /etc/os-release; then
    echo "Only Debian 11 (bullseye) is supported"
    exit 1
fi

### 2. Add Proxmox repository ###
echo "[+] Adding Proxmox VE repository..."
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bullseye pve-no-subscription" | sudo tee /etc/apt/sources.list.d/pve-install-repo.list

### 3. Add Proxmox GPG Key ###
echo "[+] Adding Proxmox GPG key..."
wget -q https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg

### 4. Update system and install kernel ###
echo "[+] Updating and upgrading packages..."
apt update && apt full-upgrade -y

echo "[+] Installing Proxmox VE kernel..."
apt install -y pve-kernel-5.15

### 5. Preserve SSH Access for g8amin_salam ###
echo "[+] Ensuring SSH access for user g8amin_salam..."
USER_HOME="/home/g8amin_salam"
mkdir -p $USER_HOME/.ssh
chmod 700 $USER_HOME/.ssh
chown g8amin_salam:g8amin_salam $USER_HOME/.ssh

# No need to modify authorized_keys — already exists from GCP

### 6. Avoid breaking network on GCP ###
echo "[+] Avoiding GCP network issues: skipping ifupdown2 and reboot delay..."
touch /etc/cloud/cloud-init.disabled

### 7. Install Proxmox VE ###
echo "[+] Installing Proxmox VE core packages..."
apt install -y proxmox-ve postfix open-iscsi

### 8. Remove conflicting kernel and finalize ###
apt remove -y linux-image-amd64 'linux-image-5.10*' || true
apt remove -y os-prober || true
update-grub

### 9. Final Message ###
echo "Proxmox installation completed."
echo "Access Web UI at: https://<your-external-ip>:8006"
echo "You may now reboot the instance manually: sudo reboot"

