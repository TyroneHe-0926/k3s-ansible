# Cluster Setup Guide

This guide walks through setting up all services on a fresh k3s cluster using the setup scripts.

## Prerequisites

- A running k3s cluster provisioned with the ansible playbook in this repo
- `kubectl` configured and pointing at the cluster
- `helm` installed
- SSH access from the machine running the scripts to all cluster nodes (used by the Pi-hole and Longhorn install scripts)

## Quick start

Install everything in dependency order:

```bash
./cluster-setup/scripts/setup.sh --all
```

Or pick specific services interactively:

```bash
./cluster-setup/scripts/setup.sh
```

Or install specific services by name:

```bash
./cluster-setup/scripts/setup.sh cert-manager rancher pihole
```

## Service install order

Services are listed in dependency order. When using `--all`, they install in this sequence:

| # | Service | Dependencies | Interactive input required |
|---|---------|-------------|--------------------------|
| 1 | cert-manager | None | None |
| 2 | rancher | cert-manager | Bootstrap password (prompted, or set `RANCHER_PASSWORD` env var) |
| 3 | longhorn | None | UI username and password (prompted) |
| 4 | traefik-dashboard | None | Dashboard username and password (prompted) |
| 5 | kube-prometheus-stack | None | None |
| 6 | pihole | None | Secret file must be created beforehand (see below) |

## Manual steps per service

### cert-manager

No manual steps. Fully automated.

### rancher

**During install:** you will be prompted for a bootstrap password, or you can set it ahead of time:

```bash
export RANCHER_PASSWORD="your-password"
./cluster-setup/scripts/setup.sh rancher
```

**After install:** add a DNS record in Pi-hole (Local DNS > DNS Records):
- `hahafhaha-rancher.com` → `<control-plane-ip>`

### longhorn

**During install:** you will be prompted for a username and password for the Longhorn web UI basic auth. The script installs prerequisites (`open-iscsi`, `jq`, `cryptsetup`) on all nodes via SSH automatically.

**After install:** add a DNS record in Pi-hole:
- `hahafhaharpi2.local` → `<any-node-ip>`

### traefik-dashboard

**During install:** you will be prompted for a username and password for the Traefik dashboard basic auth.

**After install:** add a DNS record in Pi-hole:
- `hahafhaharpi4.local` → `<any-node-ip>`

### kube-prometheus-stack

No manual steps during install.

**After install:** access Grafana via port-forward:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

Default Grafana credentials: `admin` / `prom-operator`. Change the password on first login.

### pihole

**Before install:** create the secret file with your Pi-hole web UI password:

```bash
cat > cluster-setup/configs/pihole/secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: pihole-secret
  namespace: pihole
type: Opaque
stringData:
  password: "your-password"
EOF
```

This file is gitignored and will not be committed.

**After install:**
1. Set your router's primary DNS to the control plane IP
2. Optionally set a secondary DNS (e.g., `8.8.8.8`) as a fallback
3. Add a DNS record in Pi-hole (Local DNS > DNS Records):
   - `hahafhaha-pihole.com` → `<control-plane-ip>`

## DNS records summary

After all services are installed, add these local DNS records in Pi-hole (Local DNS > DNS Records):

| Hostname | Points to | Service |
|----------|-----------|---------|
| `hahafhaha-rancher.com` | Control plane IP | Rancher UI |
| `hahafhaha-pihole.com` | Control plane IP | Pi-hole admin |
| `hahafhaharpi2.local` | Any node IP | Longhorn UI |
| `hahafhaharpi4.local` | Any node IP | Traefik dashboard |

## Passwords summary

| Service | How to set | Where it's stored |
|---------|-----------|-------------------|
| Pi-hole web UI | `secret.yaml` file (created manually) | k8s Secret in `pihole` namespace |
| Rancher bootstrap | `RANCHER_PASSWORD` env var or prompted | Rancher internal config |
| Longhorn UI | Prompted during install | k8s Secret `basic-auth` in `longhorn-system` |
| Traefik dashboard | Prompted during install | k8s Secret `traefik-auth` in `kube-system` |
| Grafana | Default `admin`/`prom-operator` | Changed via Grafana UI on first login |
