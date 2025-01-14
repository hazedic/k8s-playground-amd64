#!/usr/bin/env bash

METALLB_VERSION=${1:-"0.14.5"}
SUBNET=$(echo ${2} | cut -d. -f1-3)

sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VERSION}/config/manifests/metallb-native.yaml

sudo kubectl get configmap kube-proxy -n kube-system -o yaml | \
    sed -e "s/mode: \"\"/mode: \"ipvs\"/" | \
    sudo kubectl apply -f - -n kube-system

sudo kubectl get configmap kube-proxy -n kube-system -o yaml | \
    sed -e "s/strictARP: false/strictARP: true/" | \
    sudo kubectl apply -f - -n kube-system

if kubectl get validatingwebhookconfigurations metallb-webhook-configuration >/dev/null 2>&1; then
    sudo kubectl delete validatingwebhookconfigurations metallb-webhook-configuration
fi

echo "Patching MetalLB controller Deployment to allow scheduling on control-plane node..."
kubectl -n metallb-system patch deployment controller --type='json' -p='[
    {
        "op": "add",
        "path": "/spec/template/spec/tolerations",
        "value": [
            {
                "key": "node-role.kubernetes.io/control-plane",
                "operator": "Exists",
                "effect": "NoSchedule"
            }
        ]
    }
]' || echo "Failed to patch MetalLB controller tolerations"

echo "Waiting for MetalLB pods to be ready..."
RETRY_COUNT=0
MAX_RETRIES=30
while true; do
    READY_COUNT=$(kubectl -n metallb-system get pods -o 'jsonpath={.items[*].status.containerStatuses[*].ready}' | grep -o true | wc -l)
    TOTAL_COUNT=$(kubectl -n metallb-system get pods --no-headers | wc -l)

    if [[ $READY_COUNT -eq $TOTAL_COUNT ]] && [[ $TOTAL_COUNT -gt 0 ]]; then
        echo "All MetalLB pods are ready!"
        break
    fi

    if [[ $RETRY_COUNT -ge $MAX_RETRIES ]]; then
        echo "MetalLB pods are not ready after $(($MAX_RETRIES * 10)) seconds. Exiting."
        kubectl -n metallb-system get pods
        exit 1
    fi

    echo "MetalLB is not ready yet. Retrying in 10 seconds..."
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 10
done

echo "Applying IPAddressPool..."
cat <<EOF | sudo kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: first-pool
    namespace: metallb-system
spec:
    addresses:
    - ${SUBNET}.11-${SUBNET}.31
    autoAssign: true
EOF

echo "Applying L2Advertisement..."
cat <<EOF | sudo kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: layer2-mode
    namespace: metallb-system
spec:
    ipAddressPools:
    - first-pool
EOF

echo "==== MetalLB Pod Status ===="
kubectl -n metallb-system get pods -o wide

echo "==== MetalLB Events ===="
kubectl -n metallb-system get events --sort-by='.lastTimestamp'

echo "==== MetalLB Logs (controller) ===="
kubectl -n metallb-system logs deployment/controller || echo "Failed to fetch controller logs"