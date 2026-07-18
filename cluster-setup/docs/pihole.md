# Pi-hole on k3s

Pi-hole runs as a single-replica Deployment on the control plane node using `hostNetwork: true`, so it binds directly to the host's network interface. This preserves real client source IPs in the query log and avoids SNAT issues inherent to k3s ServiceLB and kube-proxy.

## Prerequisites

### Disable systemd-resolved stub listener (Ubuntu)

On Ubuntu, `systemd-resolved` binds a stub DNS listener on `127.0.0.53:53`. With `hostNetwork: true`, Pi-hole also binds port 53 on the host — the CNI hostport iptables rules intercept all port 53 traffic (including to `127.0.0.53`) and DNAT it, breaking the stub listener. Disable it before deploying:

```bash
ssh <control-plane-ip> "sudo mkdir -p /etc/systemd/resolved.conf.d && \
  echo -e '[Resolve]\nDNSStubListener=no\nDNS=192.168.0.1\nFallbackDNS=8.8.8.8' | \
  sudo tee /etc/systemd/resolved.conf.d/no-stub.conf && \
  sudo systemctl restart systemd-resolved"
```

Then switch `/etc/resolv.conf` to use the upstream resolvers directly instead of the stub:

```bash
ssh <control-plane-ip> "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
```

This ensures the control plane node can still resolve hostnames (for image pulls, etc.) even though the stub listener is disabled.

### Port 80/443 conflict with Traefik

k3s deploys Traefik with ServiceLB (`svclb-traefik`) pods that claim `hostPort` 80 and 443 on every node. Pi-hole's web UI defaults to port 80/443, which would conflict. The deployment uses `FTLCONF_webserver_port=8081,8443s` to avoid this. The web UI is accessible at `http://<control-plane-ip>:8081/admin`.

## Architecture decisions

### Why `hostNetwork: true`

k3s ServiceLB uses CNI hostport with a `CNI-HOSTPORT-MASQ` iptables chain that always masquerades (SNATs) the source IP — regardless of `externalTrafficPolicy` setting. This means Pi-hole only sees cluster-internal IPs (`10.42.x.x`) instead of real client IPs.

Using `hostNetwork: true` bypasses ServiceLB and CNI entirely. Pi-hole binds directly to the host interface and sees the original client source IPs.

### Why `Recreate` strategy

With `hostNetwork`, only one pod can hold port 53 on the host at a time. `RollingUpdate` with `maxUnavailable: 0` would deadlock — the new pod can't start while the old pod holds the port. `Recreate` tears down the old pod first, causing a brief DNS outage during updates (~15-30 seconds).

### Why no LoadBalancer Service for DNS

Since Pi-hole binds directly to the host network, no Kubernetes Service is needed for DNS. Clients query the control plane IP directly on port 53. A LoadBalancer service would reintroduce the SNAT problem.

## Deployment

### 1. Create the secret

Copy the template and set your Pi-hole web UI password:

```yaml
# cluster-setup/configs/pihole/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: pihole-secret
  namespace: pihole
type: Opaque
stringData:
  password: "<your-password>"
```

This file is gitignored.

### 2. Apply the manifests

```bash
kubectl apply -f cluster-setup/configs/pihole/namespace.yaml
kubectl apply -f cluster-setup/configs/pihole/secret.yaml \
              -f cluster-setup/configs/pihole/pvc.yaml \
              -f cluster-setup/configs/pihole/deployment.yaml
```

### 3. Verify

```bash
# Check pod is running with host IP
kubectl get pods -n pihole -o wide

# Test DNS resolution
dig @<control-plane-ip> google.com +short

# Check client IPs are real (not 10.42.x.x)
kubectl exec -n pihole deployment/pihole -- tail -5 /var/log/pihole/pihole.log
```

### 4. Router configuration

Set the router's primary DNS server to the control plane node IP (`192.168.0.22`). Optionally set a secondary DNS (e.g., `8.8.8.8`) as a fallback in case the control plane goes down.

Devices will pick up the new DNS on their next DHCP lease renewal. To apply immediately, flush DNS or reconnect on individual devices.

### 5. Set up Traefik ingress for the web UI

Apply the ClusterIP service and IngressRoute so the dashboard is accessible via hostname on port 80 without specifying a port:

```bash
kubectl apply -f cluster-setup/configs/pihole/service-web.yaml \
              -f cluster-setup/configs/pihole/ingress.yaml
```

Then add a local DNS record in Pi-hole (Local DNS > DNS Records): `hahafhaha-pihole.com → <control-plane-ip>`.

This works because the ClusterIP service routes to the hostNetwork pod via kube-proxy — it doesn't bind any host port, so there's no conflict with Pi-hole's own port 8081.

## Access

| Service | URL |
|---------|-----|
| DNS | `<control-plane-ip>:53` (UDP/TCP) |
| Web UI (via Traefik) | `http://hahafhaha-pihole.com/admin` |
| Web UI (direct) | `http://<control-plane-ip>:8081/admin` |

## Manifest reference

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates the `pihole` namespace |
| `secret.yaml` | Pi-hole web UI password (gitignored) |
| `pvc.yaml` | 5Gi PersistentVolumeClaim for `/etc/pihole` (gravity.db, config, query logs) |
| `deployment.yaml` | Pi-hole Deployment — pinned to control plane, `hostNetwork: true`, `Recreate` strategy |
| `service-web.yaml` | ClusterIP service for Traefik to route to the web UI |
| `ingress.yaml` | Traefik IngressRoute for `hahafhaha-pihole.com` |
