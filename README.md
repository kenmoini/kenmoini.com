# kenmoini.com

My personal site, a Hugo blog.

To learn how I built & deploy this site and how you can do so too read this article: https://kenmoini.com/post/2021/11/your-own-blog-with-hugo-on-kubernetes/

# Deployment

This Hugo site is deployed as a container to a Kubernetes cluster - because of course it is, what better use of a scalable platform than a static HTML site...

Being a very light container with no dependencies it'll deploy to pretty much any Kubernetes/OpenShift cluster.

The few considerations to take are around Ingress and TLS - my target K8s cluster on DigitalOcean via their managed service uses [ingress-nginx](https://github.com/kubernetes/ingress-nginx) and [cert-manager](https://cert-manager.io/docs/) via DNS01.

In OpenShift this is all usually handled by the Route.

## Target and Tested Kubernetes Cluster

- Via DigitalOcean K8s Service
- Deploy Ingress via `kubectl apply -f deploy/supporting/ingress-nginx/daemonset.yaml`
- Deploy Cert-Manager via Helm:

```bash
## Add the Jetstack Helm Repo
helm repo add jetstack https://charts.jetstack.io

## Update the helm repos
helm repo update

## Install cert-manager via Helm
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.5.4 --set installCRDs=true

## Deploy the ClusterIssuers
kubectl apply -f deploy/supporting/cert-manager/
```

## Deployment

### Create a Namespace

This is pretty easy really...

```bash
kubectl create namespace kenmoini-com
```

### Create GHCR Image Pull Secret

Since this container image is hosted on the GitHub Container Registry, you need a GHCR Image Pull Secret created and applied to the Namespace where the Deployment will be applied:

```bash
# Create the ImagePullSecret, pull the GitHub Personal Access token from ~./ghPAT
kubectl create secret docker-registry ghcr-pull-secret --docker-server=ghcr.io --docker-username=kenmoini --docker-password=$(cat ~/.ghPAT) --docker-email=ken@kenmoini.com --dry-run=client -o yaml > ghcr.reg.yaml

# Actually apply the ImagePullSecret
kubectl apply -f ghcr.reg.yaml -n kenmoini-com
```

### Create DigitalOcean PAT Secret

This DigitalOcean Personal Access Token is used for the DNS-01 ACME Solvers in cert-manager to automatically set verification TXT records.

```bash
## Create a Secret with the DigitalOcean Personal Access token
kubectl create secret generic do-dns-pat -n cert-manager --from-literal=access-token=$(cat ~/.doPAT) --dry-run=client -o yaml > dopat-secret.yaml

## Apply the secret to the cert-manager namespace
kubectl apply -f dopat-secret.yaml -n cert-manager
```

### Apply Deployment

With the needed Secrets, Ingress, and TLS set up we can deploy the actual site:

```bash
kubectl apply -f deploy/k8s/ -n kenmoini-com
```

## Deploying Plausible Analytics

This Hugo site uses [Plausible Analytics](https://plausible.io/self-hosted-web-analytics) as an alternative to Google Analytics - this is also deployed to Kubernetes in a different namespace at a different ingress - deployment instructions are here: https://github.com/kenmoini/kenmoini.com/tree/main/deploy/supporting#deploy-plausible-analytics

The supporting part of the site that loads the JavaScript is located at `site/layouts/partials/analytics/plausible-analytics.html` via `site/layouts/partials/head/head.html`

Read more about Plausible Analytics here: https://kenmoini.com/post/2021/11/goodbye-google-hello-plausible/