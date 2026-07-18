#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing kube-prometheus-stack ==="

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace

echo "Waiting for Grafana to be ready..."
kubectl wait --for=condition=available deployment/kube-prometheus-stack-grafana -n monitoring --timeout=300s

echo ""
echo "kube-prometheus-stack is running."
echo "  Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "  Default credentials: admin / prom-operator"
