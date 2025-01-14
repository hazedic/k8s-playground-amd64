#!/usr/bin/env bash

WORKER_COUNT="$1"
KUBERNETES_VERSION="$2"
MASTER_IP="$3"

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

echo "Adding Kubernetes repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "Adding Docker repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Applying sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "Updating /etc/hosts file..."
{
    echo "${MASTER_IP} k8s-master"
    for ((i=1; i<=WORKER_COUNT; i++)); do
        echo "${MASTER_IP}${i} k8s-worker${i}"
    done
} | sudo tee -a /etc/hosts

echo "Configuration completed successfully!"
