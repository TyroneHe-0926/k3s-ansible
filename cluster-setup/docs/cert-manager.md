# cert-manager on k3s

cert-manager handles TLS certificate management in the cluster. It is a required dependency for Rancher.

## Installation

```bash
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --version v1.20.0 \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true
```

## Verification

```bash
kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager
```

All three deployments (`cert-manager`, `cert-manager-cainjector`, `cert-manager-webhook`) should be running.
