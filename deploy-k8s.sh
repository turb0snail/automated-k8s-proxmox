#!/bin/bash

# --- CONFIG SECTION ---
CONTROL_PLANE=192.168.100.185
WORKER_1=192.168.100.159
WORKER_2=192.168.100.173
USER="kubeadmin"
PASS="Kube@1234"
SSHPASS="sshpass -p $PASS"
K8S_POD_CIDR="10.244.0.0/16"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# --- 1. INSTALL KUBERNETES TOOLS ON ALL NODES ---
echo "[+] Installing kubeadm/kubelet/kubectl/containerd on all nodes..."
for node in $CONTROL_PLANE $WORKER_1 $WORKER_2; do
  $SSHPASS ssh $SSH_OPTS ${USER}@${node} bash <<'EOF'
    set -e
    # Remove all legacy Kubernetes repo files and keyrings
    sudo rm -f /etc/apt/sources.list.d/kubernetes.list
    sudo rm -f /etc/apt/sources.list.d/kubernetes-*.list
    sudo rm -f /usr/share/keyrings/kubernetes-archive-keyring.gpg
    sudo rm -f /etc/apt/keyrings/kubernetes-archive-keyring.gpg
    sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl containerd
    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable containerd
    sudo systemctl start containerd
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
EOF
done

# --- 2. INIT KUBEADM ON CONTROL-PLANE ---
echo "[+] Initializing Kubernetes cluster on control-plane node..."
$SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} "sudo kubeadm init --pod-network-cidr=${K8S_POD_CIDR} --apiserver-advertise-address=${CONTROL_PLANE} --ignore-preflight-errors=NumCPU,Mem"

# --- 3. SET UP KUBECTL FOR kubeadmin USER ON CONTROL-PLANE ---
echo "[+] Setting up kubectl config on control-plane node..."
$SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} bash <<'EOF'
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $USER:$USER $HOME/.kube/config
EOF

# --- 4. INSTALL FLANNEL CNI PLUGIN ---
echo "[+] Installing Flannel CNI on control-plane node..."
$SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} "kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"

# --- 5. GET JOIN COMMAND ---
echo "[+] Retrieving kubeadm join command from control-plane..."
JOIN_CMD=$($SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} "kubeadm token create --print-join-command")

# --- 6. JOIN WORKER NODES ---
echo "[+] Running kubeadm join on worker nodes..."
for node in $WORKER_1 $WORKER_2; do
  $SSHPASS ssh $SSH_OPTS ${USER}@${node} "sudo ${JOIN_CMD} --ignore-preflight-errors=NumCPU,Mem"
done

# --- 7. WAIT FOR NODES TO JOIN ---
echo "[+] Waiting for worker nodes to be Ready..."
sleep 45

# --- 8. DEPLOY TEST NGINX APP ---
echo "[+] Deploying test Nginx deployment and NodePort service..."
$SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} bash <<'EOF'
  kubectl create deployment nginx --image=nginx --replicas=2 || true
  kubectl expose deployment nginx --port=80 --type=NodePort || true
EOF

# --- 9. OUTPUT STATUS ---
echo "[+] Final cluster status:"
$SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} "kubectl get nodes -o wide"
$SSHPASS ssh $SSH_OPTS ${USER}@${CONTROL_PLANE} "kubectl get pods,svc -o wide"

echo -e "\n[+] Kubernetes cluster deployed and test Nginx app running!\n"

