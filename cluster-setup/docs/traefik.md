# Traefik Dashboard on k3s

Traefik v3 comes bundled with k3s (v1.32.3+) as the default ingress controller. The dashboard is disabled by default — this config exposes it behind basic auth via an IngressRoute.

## Setup

### 1. Create basic auth credentials

```bash
USER=<USERNAME>; PASSWORD=<PASSWORD>
echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth
kubectl -n kube-system create secret generic traefik-auth --from-file=auth
rm auth
```

### 2. Apply the dashboard config

```bash
kubectl apply -f cluster-setup/configs/traefik/dashboard.yaml
```

### 3. Add a local DNS record

Add a DNS record in Pi-hole (Local DNS > DNS Records) pointing `hahafhaha-traefik.com` to a cluster node IP.

The Traefik dashboard is then accessible at `http://hahafhaha-traefik.com/dashboard/`.

Note: the trailing slash on `/dashboard/` is required.

## Manifest reference

| File | Purpose |
|------|---------|
| `dashboard.yaml` | Middleware for basic auth + IngressRoute exposing the Traefik dashboard |
