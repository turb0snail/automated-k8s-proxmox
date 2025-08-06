# test_task_l2_administrator_pe_automated_kubernetes_with_proxmox

## Project Overview

**Automated Kubernetes with Proxmox**:  
Our goal is to build a fully automated solution for deploying a Kubernetes cluster inside virtual machines managed by Proxmox VE, which itself is installed on a cloud server.

This project enables reproducible, isolated environments for development and testing, particularly useful for engineering teams who need to spin up lab environments quickly and consistently.

---

## Cloud Provider Selection: Google Cloud Platform (GCP)

### GCP

We selected **Google Cloud Platform (GCP)** as our cloud provider because:

- GCP supports **nested virtualization** on specific VM types (e.g., `n2`, `n2d`, and `c2` machine series).
- GCP provides **customizable VM images** and **boot disk types** (e.g., SSD for better I/O during virtualization).
- Proxmox VE works reliably on GCP with proper networking configuration.
- GCP offers a stable and scalable infrastructure for automation-based provisioning.

### VM Configuration:

- Instance Type: `n2-standard-2` (4 vCPUs, 32 GB RAM)
- OS Image: Debian 11
- Disk: 150 GB SSD
- SSH Access enabled for remote automation

---

## Repository Structure

```bash
automated-k8s-proxmox/
├── assets/
│   └── jammy-server-cloudimg-amd64.img       # Ubuntu 22.04 cloud image (used for VM templates)
├── cloud-init/
│   ├── control-plane.yaml                    # Cloud-init config for control plane
│   └── worker.yaml                           # Cloud-init config for worker nodes
├── install.sh                                # Installs Proxmox VE on the GCP instance
├── provision-vms.sh                          # Provisions Proxmox VMs and sets them up using cloud-init
├── deploy-k8s.sh                             # Initializes Kubernetes cluster inside the VMs ( 
└── README.md                                 # Project documentation


##File: install.sh

    Automates installation of Proxmox VE on a fresh Debian server.

    Ensures the Proxmox repo is configured correctly and the system is updated.

    Cleans up conflicting packages (e.g., os-prober) and ensures SSH access is preserved.

Note: Make sure to run this script after provisioning the GCP VM and before switching to the Proxmox web interface.


##Phase 2: VM Provisioning in Proxmox

File: provision-vms.sh

    Imports the Ubuntu cloud image (QCOW2) to Proxmox local directory storage.

    Creates a base VM (ID: 9000) with the imported image.

    Attaches cloud-init drive for provisioning during first boot.

    Converts the base VM to a template.

    Clones:

        One Control Plane VM (ID: 9001)

        Two Worker VMs (ID: 9002, 9003)

    Applies proper CPU, memory, network, and cloud-init configurations.

    Starts the created VMs automatically.
Full clones are used to avoid issues with linked raw disks in directory-based storage.
