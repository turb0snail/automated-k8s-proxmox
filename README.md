# Automated Kubernetes with Proxmox

## Project Overview

This project enables reproducible, isolated environments for development and testing. Using Proxmox VE installed on a cloud server that supports nested virtualization, you can automate the provisioning of a full Kubernetes cluster inside Proxmox-managed VMs.

---

## Cloud Provider Selection: Google Cloud Platform (GCP)

**Chosen Provider**: Google Cloud Platform (GCP)

**Justification**:  
GCP supports nested virtualization on specific VM types (`n2`, `n2d`, `c2`), allows for custom images and boot disk types (SSD recommended), and Proxmox VE runs reliably with proper networking on GCP.

- **Instance Type:** `n2-standard-2` (4 vCPUs, 32 GB RAM)
- **OS Image:** Debian 11
- **Disk:** 150 GB SSD
- **SSH Access** enabled for remote automation

---

## Architecture

- **Host OS**: Debian/Ubuntu
- **Hypervisor**: Proxmox VE (running as a VM in the cloud)
- **Kubernetes Cluster**: 1 control-plane node + 2 worker nodes (all as Proxmox VMs)
- **Automation**: Bash scripts (`install.sh`, `provision-vms.sh`, `deploy-k8s.sh`) and cloud-init templates

---

## Repository Structure

```bash
automated-k8s-proxmox/
├── assets/
│   └── jammy-server-cloudimg-amd64.img       # Ubuntu 22.04 cloud image
├── cloud-init/
│   ├── control-plane.yaml                    # Cloud-init config for control plane
│   └── worker.yaml                           # Cloud-init config for worker nodes
├── install.sh                                # Installs Proxmox VE
├── provision-vms.sh                          # Provisions Proxmox VMs using cloud-init
├── deploy-k8s.sh                             # Deploys Kubernetes cluster in VMs
├── README.md                                 # Project documentation
└── screenshots/                              # Proof of automation and cluster state

