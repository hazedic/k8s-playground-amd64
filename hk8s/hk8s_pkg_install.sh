#!/usr/bin/env bash

KUBERNETES_VERSION="$1"
CONTAINERD_VERSION="$2"
NODE_IP="$3"

echo "Updating package lists and installing Kubernetes components..."
sudo apt-get update -y
sudo apt-get install -y \
    kubelet="$KUBERNETES_VERSION" \
    kubectl="$KUBERNETES_VERSION" \
    kubeadm="$KUBERNETES_VERSION" \
    containerd.io="$CONTAINERD_VERSION" || { echo "Package installation failed"; exit 1; }

echo "Holding Kubernetes packages..."
sudo apt-mark hold kubelet kubectl kubeadm

echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

echo "Configuring crictl..."
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock \
                   --set image-endpoint=unix:///run/containerd/containerd.sock

echo "Configuring kubelet with node IP address..."
cat <<EOF | sudo tee /etc/default/kubelet > /dev/null
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}
EOF

echo "Reloading and restarting services..."
sudo systemctl daemon-reload

echo "Restarting and enabling containerd..."
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "Restarting and enabling kubelet..."
sudo systemctl restart kubelet
sudo systemctl enable kubelet

echo "Setup completed successfully!"