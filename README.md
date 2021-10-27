# kenmoini.com

My personal site, a Hugo blog

## Target Cluster

- Via DigitalOcean K8s Service
- Deploy Ingress via `kubectl apply -f deploy/supporting/ingress-nginx/daemonset.yaml`
- Deploy Cert-Manager via Helm:

```
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.5.4 --set installCRDs=true

kubectl apply -f deploy/supporting/cert-manager/
```

## Deployment

### Create GHCR Pull Secret

```bash
kubectl create secret docker-registry ghcr-pull-secret --docker-server=ghcr.io --docker-username=kenmoini --docker-password=$(cat ~/.ghPAT) --docker-email=ken@kenmoini.com --dry-run=client -o yaml > ghcr.reg.yaml

kubectl apply -f ghcr.reg.yaml -n kenmoini-com
```

### Create DigitalOcean PAT Secret

This is used for the DNS-01 ACME Solvers

```bash
kubectl create secret generic do-dns-pat -n cert-manager --from-literal=access-token=$(cat ~/.doPAT) --dry-run=client -o yaml > dopat.yaml

kubectl apply -f dopat.yaml
```