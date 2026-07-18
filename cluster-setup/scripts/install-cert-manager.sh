#!/usr/bin/env bash
set -euo pipefail

CERT_MANAGER_VERSION="v1.20.0"

echo "=== Installing cert-manager $CERT_MANAGER_VERSION ==="

helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --version "$CERT_MANAGER_VERSION" \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=available deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo ""
echo "cert-manager $CERT_MANAGER_VERSION is running."
