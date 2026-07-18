#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs/traefik"

echo "=== Setting up Traefik Dashboard ==="

# Set up basic auth
if ! kubectl get secret traefik-auth -n kube-system &>/dev/null; then
    read -rp "Traefik dashboard username: " TF_USER
    read -rsp "Traefik dashboard password: " TF_PASS
    echo ""
    TMPAUTH=$(mktemp)
    echo "${TF_USER}:$(openssl passwd -stdin -apr1 <<< "${TF_PASS}")" > "$TMPAUTH"
    kubectl -n kube-system create secret generic traefik-auth --from-file=auth="$TMPAUTH"
    rm "$TMPAUTH"
fi

# Apply dashboard config
kubectl apply -f "$CONFIGS_DIR/dashboard.yaml"

echo ""
echo "Traefik dashboard is configured."
echo "  URL: http://hahafhaharpi4.local/dashboard/ (add DNS record in Pi-hole)"
