# kube-prometheus-stack on k3s

The kube-prometheus-stack provides Prometheus, Grafana, and Alertmanager for cluster monitoring. It can also be installed through the Rancher UI.

## Installation

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace
```

## Key dashboards

- **Node Exporter** — host-level metrics (CPU, memory, disk, network per node)
- **Kubelet** — pod lifecycle, container operations, volume stats

These are useful for spotting performance warning signs across the cluster.

## Access

Grafana is accessible via port-forward or by creating a Traefik IngressRoute:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

Default Grafana credentials: `admin` / `prom-operator`.
