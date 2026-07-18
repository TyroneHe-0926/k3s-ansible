#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/../configs/pihole"

echo "=== Installing Pi-hole ==="

# Check secret exists
if [[ ! -f "$CONFIGS_DIR/secret.yaml" ]]; then
    echo "Error: $CONFIGS_DIR/secret.yaml not found."
    echo "Create it from the template with your Pi-hole web UI password:"
    echo ""
    echo "  apiVersion: v1"
    echo "  kind: Secret"
    echo "  metadata:"
    echo "    name: pihole-secret"
    echo "    namespace: pihole"
    echo "  type: Opaque"
    echo "  stringData:"
    echo "    password: \"<your-password>\""
    exit 1
fi

CONTROL_PLANE_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
CONTROL_PLANE_HOST=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')

echo "Control plane: $CONTROL_PLANE_HOST ($CONTROL_PLANE_IP)"

# Disable systemd-resolved stub listener on the control plane
echo "Disabling systemd-resolved stub listener on $CONTROL_PLANE_IP..."
ssh "$CONTROL_PLANE_IP" "sudo mkdir -p /etc/systemd/resolved.conf.d && \
    echo -e '[Resolve]\nDNSStubListener=no\nDNS=\$(ip route | grep default | awk '\''{print \$3}'\'')\\nFallbackDNS=8.8.8.8' | \
    sudo tee /etc/systemd/resolved.conf.d/no-stub.conf > /dev/null && \
    sudo systemctl restart systemd-resolved && \
    sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf" 2>/dev/null || echo "Warning: could not configure systemd-resolved (may not be Ubuntu)"

# Apply manifests
echo "Applying Pi-hole manifests..."
kubectl apply -f "$CONFIGS_DIR/namespace.yaml"
kubectl apply -f "$CONFIGS_DIR/secret.yaml" \
              -f "$CONFIGS_DIR/pvc.yaml" \
              -f "$CONFIGS_DIR/deployment.yaml"

echo "Waiting for Pi-hole pod to be ready..."
kubectl wait --for=condition=ready pod -l app=pihole -n pihole --timeout=120s

# Apply web service and Traefik ingress
echo "Setting up Traefik ingress for Pi-hole web UI..."
kubectl apply -f "$CONFIGS_DIR/service-web.yaml" \
              -f "$CONFIGS_DIR/ingress.yaml"

echo ""
echo "Pi-hole is running."
echo "  DNS:      $CONTROL_PLANE_IP:53"
echo "  Web UI:   http://$CONTROL_PLANE_IP:8081/admin"
echo "  Web UI:   http://hahafhaha-pihole.com/admin (add DNS record in Pi-hole)"
echo ""
echo "Set your router's primary DNS to $CONTROL_PLANE_IP"
