#!/usr/bin/env bash
set -euo pipefail

RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-hahafhaha-rancher.com}"
RANCHER_PASSWORD="${RANCHER_PASSWORD:-}"

echo "=== Installing Rancher ==="

# Check cert-manager is installed (required dependency)
if ! kubectl get namespace cert-manager &>/dev/null; then
    echo "Error: cert-manager is not installed. Install it first."
    exit 1
fi

if [[ -z "$RANCHER_PASSWORD" ]]; then
    read -rsp "Enter Rancher bootstrap password: " RANCHER_PASSWORD
    echo ""
fi

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update rancher-latest

helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --create-namespace \
    --set hostname="$RANCHER_HOSTNAME" \
    --set bootstrapPassword="$RANCHER_PASSWORD" \
    --set replicas=1 \
    --set nodeSelector."node-role\.kubernetes\.io/control-plane"="true"

echo "Waiting for Rancher to be ready..."
kubectl wait --for=condition=available deployment/rancher -n cattle-system --timeout=300s

echo ""
echo "Rancher is running."
echo "  URL: https://$RANCHER_HOSTNAME"
