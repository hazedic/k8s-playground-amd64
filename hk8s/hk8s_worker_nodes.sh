#!/usr/bin/env bash

MASTER_IP="$1" 

echo "Joining the Kubernetes cluster..."
sudo kubeadm join --token abcdef.1234567890abcdef "${MASTER_IP}:6443" \
    --discovery-token-unsafe-skip-ca-verification || { echo "Failed to join the cluster"; exit 1; }

echo "Successfully joined the Kubernetes cluster!"