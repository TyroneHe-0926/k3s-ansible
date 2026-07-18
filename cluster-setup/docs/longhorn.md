# Longhorn on k3s

Longhorn is the CSI volume controller for persistent storage across the cluster.

## Prerequisites

Install required dependencies on **every node**:

```bash
sudo apt install -y open-iscsi jq cryptsetup
```

## Installation

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn \
    --namespace longhorn-system \
    --create-namespace \
    --version 1.8.1 \
    --set persistence.defaultClassReplicaCount=2 \
    --set csi.attacherReplicaCount=3 \
    --set csi.provisionerReplicaCount=2 \
    --set csi.resizerReplicaCount=2 \
    --set csi.snapshotterReplicaCount=1 \
    --set defaultSettings.defaultReplicaCount=2 \
    --set longhornUI.replicas=1
```

Replica counts are tuned down to save resources on a small cluster. The default replica count of 2 means each volume is replicated across 2 nodes.

## Web UI access

### 1. Create basic auth credentials

```bash
USER=<USERNAME>; PASSWORD=<PASSWORD>
echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=auth
rm auth
```

### 2. Apply the ingress

```bash
kubectl apply -f cluster-setup/configs/longhorn/ingress.yaml
```

### 3. Add a local DNS record

Add a DNS record in Pi-hole (Local DNS > DNS Records) pointing `hahafhaharpi2.local` to the cluster node IP.

The Longhorn UI is then accessible at `http://hahafhaharpi2.local`.

## Manifest reference

| File | Purpose |
|------|---------|
| `ingress.yaml` | Traefik Ingress with basic auth middleware for the Longhorn UI |
