# Rancher on k3s

Rancher provides a web-based Kubernetes management UI. It runs on the control plane node and is accessed via its configured hostname.

## Prerequisites

cert-manager must be installed first.

## Installation

```bash
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --create-namespace \
    --set hostname=hahafhaha-rancher.com \
    --set bootstrapPassword="<your-password>" \
    --set replicas=1 \
    --set nodeSelector."node-role\.kubernetes\.io/control-plane"="true"
```

Replica count is set to 1 to save resources. The `nodeSelector` pins Rancher to the control plane node.

## Access

Add a DNS record in Pi-hole (Local DNS > DNS Records) pointing `hahafhaha-rancher.com` to the control plane IP.

Rancher is then accessible at `https://hahafhaha-rancher.com`.

## Verification

```bash
kubectl get pods -n cattle-system
kubectl get ingress -n cattle-system
```
