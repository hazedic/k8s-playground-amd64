#!/usr/bin/env bash

APISERVER_ADVERTISE_ADDRESS="${1:-$(hostname -I | awk '{print $1}')}"
POD_NETWORK_CIDR="10.244.0.0/16"
CRI_SOCKET="unix:///run/containerd/containerd.sock"
FLANNEL_URL=$(curl -s https://api.github.com/repos/flannel-io/flannel/releases/latest | grep "browser_download_url.*kube-flannel.yml" | cut -d '"' -f 4)

sudo kubeadm init --token abcdef.1234567890abcdef --token-ttl 0 \
    --apiserver-advertise-address="${APISERVER_ADVERTISE_ADDRESS}" \
    --pod-network-cidr="${POD_NETWORK_CIDR}" \
    --cri-socket="${CRI_SOCKET}" || { echo "kubeadm init failed"; exit 1; }

setup_kubeconfig() {
    local USER_HOME="$1"
    local USER_NAME="$2"
    
    mkdir -p "${USER_HOME}/.kube"
    sudo cp -i /etc/kubernetes/admin.conf "${USER_HOME}/.kube/config"
    
    if [[ -n "$USER_NAME" ]]; then
        sudo chown "${USER_NAME}:${USER_NAME}" "${USER_HOME}/.kube/config"
    else
        sudo chown "$(id -u):$(id -g)" "${USER_HOME}/.kube/config"
    fi
}

setup_kubeconfig "$HOME"
setup_kubeconfig "/home/vagrant" "vagrant"

if ! dpkg -s bash-completion &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y bash-completion
fi

echo 'source /usr/share/bash-completion/bash_completion' >> "/home/vagrant/.bashrc"
sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null

cat <<EOF >> "/home/vagrant/.bashrc"
alias k=kubectl
complete -o default -F __start_kubectl k
EOF

if [[ -z "$FLANNEL_URL" ]]; then
    echo "Failed to fetch Flannel configuration file URL."
    exit 1
fi

sudo kubectl apply -f "$FLANNEL_URL" || { echo "Failed to apply Flannel configuration"; exit 1; }

echo "Kubernetes cluster initialization completed successfully!"