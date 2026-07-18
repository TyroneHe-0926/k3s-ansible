#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs/longhorn"
LONGHORN_VERSION="1.8.1"

echo "=== Installing Longhorn $LONGHORN_VERSION ==="

# Install prerequisites on all nodes
echo "Installing prerequisites on cluster nodes..."
NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
for node in $NODES; do
    echo "  Configuring $node..."
    ssh "$node" "sudo apt install -y open-iscsi jq cryptsetup > /dev/null 2>&1" || echo "  Warning: could not install prerequisites on $node"
done

# Helm install
helm repo add longhorn https://charts.longhorn.io
helm repo update longhorn

helm install longhorn longhorn/longhorn \
    --namespace longhorn-system \
    --create-namespace \
    --version "$LONGHORN_VERSION" \
    --set persistence.defaultClassReplicaCount=2 \
    --set csi.attacherReplicaCount=3 \
    --set csi.provisionerReplicaCount=2 \
    --set csi.resizerReplicaCount=2 \
    --set csi.snapshotterReplicaCount=1 \
    --set defaultSettings.defaultReplicaCount=2 \
    --set longhornUI.replicas=1

echo "Waiting for Longhorn to be ready..."
kubectl wait --for=condition=available deployment/longhorn-ui -n longhorn-system --timeout=300s

# Set up basic auth for the UI
if ! kubectl get secret basic-auth -n longhorn-system &>/dev/null; then
    echo ""
    read -rp "Longhorn UI username: " LH_USER
    read -rsp "Longhorn UI password: " LH_PASS
    echo ""
    TMPAUTH=$(mktemp)
    echo "${LH_USER}:$(openssl passwd -stdin -apr1 <<< "${LH_PASS}")" > "$TMPAUTH"
    kubectl -n longhorn-system create secret generic basic-auth --from-file=auth="$TMPAUTH"
    rm "$TMPAUTH"
fi

# Apply ingress
kubectl apply -f "$CONFIGS_DIR/ingress.yaml"

echo ""
echo "Longhorn $LONGHORN_VERSION is running."
echo "  UI: http://hahafhaharpi2.local (add DNS record in Pi-hole)"
