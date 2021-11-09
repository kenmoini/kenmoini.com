# Supporting Kubernetes Services

This directory has a few quick deployments to slap onto a fresh Kubernetes cluster to:

- [Create Let's Encrypt ClusterIssuers for cert-manager]
- [Deploy ingress-nginx]
- [Deploy Plausible Analytics]


## Create Let's Encrypt ClusterIssuers for cert-manager

These files assume you already have cert-manager deployed and just need to create some ClusterIssuers for Let's Encrypt Production and Staging ACME solvers via HTTP01 and DNS01 responses.

DNS01 responses are configured to use DigitalOcean and a Secret with a DO Personal Access Token:

```bash
## Create a Secret with the DigitalOcean Personal Access token
kubectl create secret generic do-dns-pat -n cert-manager --from-literal=access-token=$(cat ~/.doPAT) --dry-run=client -o yaml > dopat-secret.yaml

## Apply the secret to the cert-manager namespace
kubectl apply -f dopat-secret.yaml -n cert-manager

## Apply the ClusterIssuers
kubectl apply -f cert-manager/
```

## Deploy ingress-nginx

This is just a DaemonSet that will run natively on a DigitalOcean Kubernetes cluster - different from the default Deployment which only runs on a single node, failing the DigitalOcean Load Balancer health checks.

```bash
## Deploy the ingress-nginx on DO k8s
kubectl apply -f ingress-nginx/
```

## Deploy Plausible Analytics

Plausible Analytics is an open-source alternative to Google Analytics, which is often blocked by people who run [Pi-hole](https://pi-hole.net/), like I do, and like you should do too probably.

The deployment requires a ConfigMap set that is ideally not the default:

```bash
## Create the plausible namespace
kubectl create namespace plausible-analytics

## Create a random secret key
SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n' ; echo)

## Create the plausible-conf.env Secret file
cat << EOF > plausible-conf.env.secret.yaml
apiVersion: v1
stringData:
  ADMIN_USER_EMAIL: replace-me@example.com
  ADMIN_USER_NAME: replace_me
  ADMIN_USER_PWD: replace_me
  BASE_URL: https://replace_me
  SECRET_KEY_BASE: ${SECRET_KEY}
kind: Secret
metadata:
  creationTimestamp: null
  name: plausible-config
EOF

## Apply the secret
kubectl apply -f plausible-conf.env.secret.yaml -n plausible-analytics

# Please change the Postgres and Clickhouse passwords to something more secure here!
# Create the Postgres user
kubectl -n plausible-analytics create secret generic plausible-db-user --from-literal='username=postgres' --from-literal='password=postgres'

## Create the Clickhouse user
kubectl -n plausible-analytics create secret generic plausible-events-db-user --from-literal='username=clickhouse' --from-literal='password=clickhouse'

## Deploy the Postgres DB
kubectl apply -f plausible-analytics/02-db.yaml -n plausible-analytics

## Deploy Clickhouse
kubectl apply -f plausible-analytics/02-clickhouse.yaml -n plausible-analytics

## Deploy Mail
kubectl apply -f plausible-analytics/02-smtp.yaml -n plausible-analytics

## Deploy Plausible
kubectl apply -f plausible-analytics/03-plausible.yaml -n plausible-analytics

## Expose the Plausible Dashboard
cat << EOF > plausible-ingress.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: plausible-analytics
  labels:
    app: plausible-analytics
    app.kubernetes.io/name: plausible-analytics
    app.kubernetes.io/part-of: plausible-analytics
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-dns-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Forwarded-For: $proxy_add_x_forwarded_for";
spec:
  tls:
    - hosts:
        - analytics.example.com
      secretName: analytics-example-com-tls
  rules:
    - host: analytics.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: plausible
                port:
                  number: 8000
EOF

kubectl apply -f plausible-ingress.yaml -n plausible-analytics
```