

# Vault, Kubernetes, PKI, - and more

```text
### Installing Vault: https://learn.hashicorp.com/tutorials/vault/getting-started-install?in=vault/getting-started
### PKI with Vault: https://www.hashicorp.com/blog/certificate-management-with-vault
### Full PKI Engine Walkthrough: https://learn.hashicorp.com/tutorials/vault/pki-engine
### Vault + OpenShift: https://learn.hashicorp.com/tutorials/vault/kubernetes-openshift?in=vault/kubernetes
### Vault + cert-manager: https://learn.hashicorp.com/tutorials/vault/kubernetes-cert-manager?in=vault/kubernetes
### Production Deployment Notes: https://learn.hashicorp.com/tutorials/vault/getting-started-deploy?in=vault/getting-started
```

## Deploy OpenShift

Some which way, any will do.

## Install Hashicorp Vault

```bash

## Install Helm locally on your bastion/computer: https://github.com/helm/helm#install

## Add the Hashicorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
## or - add OCP helm repo
oc apply -f ocp-hashicorp-helm-repo.yaml

## Update helm
helm repo update

## Create/switch to a new namespace
oc new-project hashicorp-vault

## Deploy the helm repo
helm install vault hashicorp/vault \
  --namespace hashicorp-vault \
  --set "global.openshift=true" \
  --set "server.dev.enabled=false"
```

## Install cert-manager

```bash

## Install Helm: https://github.com/helm/helm#install

## Add Jetstack Helm Repo
helm repo add jetstack https://charts.jetstack.io
## or - add OCP helm repo
oc apply -f ocp-jetstack-helm-repo.yaml

## Update helm
helm repo update

## Create/switch to a cert-manager ns
oc new-project cert-manager

## Install cert-manager via helm
helm install cert-manager \
  --namespace cert-manager \
  --version v1.6.1 \
  --set installCRDs=true \
  jetstack/cert-manager

```

## Initialize Vault

This is done once when freshly deployed

```bash
oc exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1

# Loop through keys
oc exec -it vault-0 -- vault operator unseal "$KEY"

## Log in to the CLI
oc exec -it vault-0 -- vault login "${ROOT_TOKEN}"

## Enable K8s
oc exec -it vault-0 -- vault auth enable kubernetes

## Enable key value secrets
oc exec -it vault-0 -- vault secrets enable -version=2 kv

### Enable Vault PKI Secrets Engine
oc exec -it vault-0 -- vault secrets enable pki

### Configure a 1yr max lease time
oc exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h pki
```

## Basic PKI in Vault

```bash
### Create PKI root
oc exec -it vault-0 -- vault write pki/root/generate/internal common_name=ups-demo.com ttl=87600h

### Set URIs
oc exec -it vault-0 -- vault write pki/config/urls issuing_certificates="http://vault.ups-demo.com/v1/pki/ca" crl_distribution_points="http://vault.ups-demo/v1/pki/crl"

### Set basic roles
oc exec -it vault-0 -- vault write pki/roles/ups-demo-dot-com allowed_domains=ups-demo.com allow_subdomains=true max_ttl=8760h

### Set basic policy
oc exec -it vault-0 -- vault policy write pki - <<EOF
path "pki*"                        { capabilities = ["read", "list"] }
path "pki/roles/ups-demo-dot-com"   { capabilities = ["create", "update"] }
path "pki/sign/ups-demo-dot-com"    { capabilities = ["create", "update"] }
path "pki/issue/ups-demo-dot-com"   { capabilities = ["create"] }
EOF
```

## Integrate Vault and Kubernetes/OpenShift

```bash
## Switch to vault namespace/project
oc project hashicorp-vault

## Exec into Pod
oc exec -it vault-0 -- /bin/sh

## Enable k8s authentication mechanism - this must be done in the vault pod in order to get the right ENV VARs
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  issuer="https://kubernetes.default.svc.cluster.local"

## Set vault issuer role
vault write auth/kubernetes/role/issuer \
  bound_service_account_names="*" \
  bound_service_account_namespaces="*" \
  policies=pki \
  ttl=20m
```

## Integrate Vault as an Issuer for cert-manager

### Configuring cert-manager

```bash
## Switch to cert-manager namespace/project
oc project cert-manager

## Add the Vault ClusterIssuer
oc create serviceaccount vault-clusterissuer

ISSUER_SECRET_REF=$(oc get serviceaccount vault-clusterissuer -o json | jq -r ".secrets[] | select(.name|test(\"token\")) | .name ")

cat > vault-clusterissuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-clusterissuer
spec:
  vault:
    server: http://vault.hashicorp-vault:8200
    path: pki/sign/ups-demo-dot-com
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: issuer
        secretRef:
          name: ${ISSUER_SECRET_REF}
          key: token
EOF

oc apply -f vault-clusterissuer.yaml
```

Now make sure the ClusterIssuer is Ready with `oc describe clusterissuers/vault-clusterissuer | grep -A 10 'Status:'`

```text
...
Status:
  Conditions:
    Last Transition Time:  2021-12-01T01:50:29Z
    Message:               Vault verified
    Observed Generation:   1
    Reason:                VaultVerified
    Status:                True
    Type:                  Ready
Events:                    <none>
```

If the ClusterIssuer cannot communicate with Vault or if the Roles/Policies don't align you may see an error.

## Deploying a Test Certificate

With the cert-manager ClusterIssuer in a Ready state, we can now test a new Certificate being automatically generated by the Vault + cert-manager integration.

```bash
## Create a Certificate
cat > test-ups-demo-dot-com-cert.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-ups-demo-dot-com
spec:
  secretName: test-ups-demo-dot-com-tls
  issuerRef:
    name: vault-clusterissuer
    kind: ClusterIssuer
  commonName: test.ups-demo.com
  dnsNames:
  - test.ups-demo.com
EOF

## Verify the status of the CertificateRequest
CERTREQ=$(oc get certificaterequests -o name)
oc describe $CERTREQ | grep -A 14 'Status:'
```

You should see something like:

```text
Status:
  Ca:           LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS....
  Certificate:  LS0tLS1CRUdJTiBDRVJU...
  Conditions:
    Last Transition Time:  2021-12-01T01:56:26Z
    Message:               Certificate request has been approved by cert-manager.io
    Reason:                cert-manager.io
    Status:                True
    Type:                  Approved
    Last Transition Time:  2021-12-01T01:56:26Z
    Message:               Certificate fetched from issuer successfully
    Reason:                Issued
    Status:                True
    Type:                  Ready
Events:                    <none>
```

You can also get the Certificate with: `oc describe certificate test-ups-demo-dot-com`

> As a bonus, here's how to integrate Service Mesh with this cert-manager/Vault combo [Work in Progress]

## Deploying Service Mesh

```bash
## Deploy Service Mesh

cat > operator-svcmesh.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: servicemeshoperator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: servicemeshoperator.v2.1.0
EOF

oc apply -f operator-svcmesh.yaml

```

## Creating a PKI for Service Mesh

Next we'll create a PKI Chain so that Service Mesh can automatically sign certificates from a trusted chain instead of with self-signed certificates that Istiod creates.

```bash
## Create/switch to a cert-manager ns
oc new-project istio-system

## Switch over to hashicorp-vault ns
oc project hashicorp-vault

## Create new PKI for internal workloads
### Enable Vault PKI Secrets Engine
#oc exec -it vault-0 -- vault secrets enable -path meshworkloads pki
oc exec -it vault-0 -- vault secrets enable -path mesh-root pki
oc exec -it vault-0 -- vault secrets enable -path mesh-ica pki

### Configure a 1yr max lease time
#oc exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h meshworkloads
oc exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h mesh-root
oc exec -it vault-0 -- vault secrets tune -max-lease-ttl=87600h mesh-ica

### Set URIs
#oc exec -it vault-0 -- vault write meshworkloads/config/urls issuing_certificates="http://vault.ups-demo.com/v1/meshworkloads/ca" crl_distribution_points="http://vault.ups-demo/v1/meshworkloads/crl"
oc exec -it vault-0 -- vault write mesh-root/config/urls issuing_certificates="http://vault.ups-demo.com/v1/mesh-root/ca" crl_distribution_points="http://vault.ups-demo/v1/mesh-root/crl"
oc exec -it vault-0 -- vault write mesh-ica/config/urls issuing_certificates="http://vault.ups-demo.com/v1/mesh-ica/ca" crl_distribution_points="http://vault.ups-demo/v1/mesh-ica/crl"

### Set basic roles
#oc exec -it vault-0 -- vault write meshworkloads/roles/ups-demo-dot-com allow_any_name=true max_ttl=8760h
oc exec -it vault-0 -- vault write mesh-root/roles/ups-demo-dot-com allow_any_name=true max_ttl=8760h enforce_hostnames=false allow_ip_sans=true allowed_uri_sans='*' no_store=true key_usage='DigitalSignature,KeyAgreement,KeyEncipherment,ContentCommitment,DataEncipherment,CertSign,CRLSign'
oc exec -it vault-0 -- vault write mesh-ica/roles/ups-mesh allow_any_name=true max_ttl=8760h enforce_hostnames=false allow_ip_sans=true allowed_uri_sans='*' no_store=true key_usage='DigitalSignature,KeyAgreement,KeyEncipherment,ContentCommitment,DataEncipherment,CertSign,CRLSign'

### Set basic policy
oc exec -it vault-0 -- /bin/sh

#### Inside the vault container:
#vault policy write meshworkloads - <<EOF
#path "meshworkloads*"                        { capabilities = ["read", "list"] }
#path "meshworkloads/roles/ups-demo-dot-com"   { capabilities = ["create", "update"] }
#path "meshworkloads/sign/ups-demo-dot-com"    { capabilities = ["create", "update"] }
#path "meshworkloads/issue/ups-demo-dot-com"   { capabilities = ["create"] }
#EOF
vault policy write mesh-root - <<EOF
path "mesh-root*"                        { capabilities = ["read", "list"] }
path "mesh-root/roles/ups-demo-dot-com"   { capabilities = ["create", "update"] }
path "mesh-root/sign/ups-demo-dot-com"    { capabilities = ["create", "update"] }
path "mesh-root/issue/ups-demo-dot-com"   { capabilities = ["create"] }
EOF
vault policy write mesh-ica - <<EOF
path "mesh-ica*"                        { capabilities = ["read", "list"] }
path "mesh-ica/roles/ups-mesh"   { capabilities = ["create", "update"] }
path "mesh-ica/sign/ups-mesh"    { capabilities = ["create", "update"] }
path "mesh-ica/issue/ups-mesh"   { capabilities = ["create"] }
EOF

## Create K8s auth role
vault write auth/kubernetes/role/mesh-root-issuer \
  bound_service_account_names="*" \
  bound_service_account_namespaces="*" \
  policies=mesh-root \
  ttl=20m

vault write auth/kubernetes/role/mesh-ica-issuer \
  bound_service_account_names="*" \
  bound_service_account_namespaces="*" \
  policies=mesh-ica \
  ttl=20m

#### Exit the pod
exit

### Create PKI root
#oc exec -it vault-0 -- vault write meshworkloads/root/generate/internal common_name="UPS Internal Service Mesh Workload Root CA" ttl=87600h
oc exec -it vault-0 -- vault write -field=certificate mesh-root/root/generate/internal common_name="UPS Internal Service Mesh Workload Root CA" ttl=87600h > mesh-root-ca.crt

## Create Intermediate CA CSR
oc exec -it vault-0 -- vault write -format=json mesh-ica/intermediate/generate/internal common_name="UPS Internal Service Mesh Workload Intermediate CA" > mesh-ica-cert.csr.json

cat mesh-ica-cert.csr.json | jq -r '.data.csr' > mesh-ica-cert.csr

## Copy csr to cat into container
cat mesh-ica-cert.csr
oc exec -it vault-0 -- /bin/sh

cat > /tmp/ica.csr << EOF
YOUR_CSR_PASTE_HERE
EOF

## Sign certificate
vault write -format=json mesh-root/root/sign-intermediate csr=@/tmp/ica.csr format=pem_bundle ttl="43800h" > /tmp/intermediate.cert.pem.json

## read it out, copy to clipboard
cat /tmp/intermediate.cert.pem

#### Exit the contianer
exit

cat > /tmp/intermediate.cert.pem.json << EOF
YOUR_CERT_PASTE_HERE
EOF

cat /tmp/intermediate.cert.pem.json | jq -r '.data.certificate' > /tmp/intermediate.cert.pem


## Create a secret from the data


## Switch over to the cert-manager ns lol
oc project cert-manager

## Add the ClusterIssuer ServiceAccount
oc create serviceaccount mesh-ica-vault-clusterissuer
MESH_ICA_ISSUER_SECRET_REF=$(oc get serviceaccount mesh-ica-vault-clusterissuer -o json | jq -r ".secrets[] | select(.name|test(\"token\")) | .name ")

cat > mesh-ica-vault-clusterissuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: mesh-ica-vault-clusterissuer
spec:
  vault:
    server: http://vault.hashicorp-vault:8200
    path: mesh-ica/sign/ups-mesh
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: mesh-ica-issuer
        secretRef:
          name: ${MESH_ICA_ISSUER_SECRET_REF}
          key: token
EOF

cat > mesh-root-vault-clusterissuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: mesh-root-vault-clusterissuer
spec:
  vault:
    server: http://vault.hashicorp-vault:8200
    path: mesh-root/sign/ups-demo-dot-com
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: mesh-root-issuer
        secretRef:
          name: ${MESH_ICA_ISSUER_SECRET_REF}
          key: token
EOF

oc apply -f mesh-ica-vault-clusterissuer.yaml

## Test certificate for SM
cat > sm-cert.yaml << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istio-ca
  # namespace for the Certificate/Secret must be in cert-manager namespace if using istio-csr - istio-system if using as a manually injected Certificate
  # namespace: cert-manager
  namespace: istio-system
spec:
  isCA: true
  duration: 2160h
  secretName: istio-ca
  commonName: istio-ca
  usages:
    - cert sign
  subject:
    organizations:
    - cluster.local
    - cert-manager
  issuerRef:
    name: mesh-root-vault-clusterissuer
    kind: ClusterIssuer
    group: cert-manager.io
EOF


## Map the cert to the needed secret
CERTIFICATE_SECRET_NAME=$(oc get certificate istio-ca -n istio-system -o jsonpath='{.spec.secretName}')
CERT_CA_CERT=$(oc get secret ${CERTIFICATE_SECRET_NAME} -n istio-system -o jsonpath='{.data.ca\.crt}' | base64 -d)
CERT_TLS_CERT=$(oc get secret ${CERTIFICATE_SECRET_NAME} -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 -d)
CERT_TLS_KEY=$(oc get secret ${CERTIFICATE_SECRET_NAME} -n istio-system -o jsonpath='{.data.tls\.key}' | base64 -d)

## Echo to files
echo "${CERT_TLS_CERT}" > ca-cert.pem
echo "${CERT_TLS_KEY}" > ca-key.pem
echo "${CERT_CA_CERT}" > root-cert.pem

## Create Secret
oc create secret generic cacerts -n istio-system --from-file=ca-cert.pem --from-file=ca-key.pem --from-file=root-cert.pem --from-file=cert-chain.pem=root-cert.pem

## Clean up
rm ca-cert.pem ca-key.pem root-cert.pem



## Create serviceMesh

## Install Jaeger
cat > jaeger-operator.yaml << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: jaeger-product
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: jaeger-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: jaeger-operator.v1.28.0
EOF

oc apply -f jaeger-operator.yaml

## Install Kiali
cat > kiali.yaml << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kiali-ossm
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: kiali-ossm
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: kiali-operator.v1.36.6
EOF

oc apply -f kiali.yaml

## Install ServiceMeshCP
cat > servicemesh-controlplane.yaml << EOF
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  addons:
    grafana:
      enabled: true
    jaeger:
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
    prometheus:
      enabled: true
  policy:
    type: Istiod
  telemetry:
    type: Istiod
  version: v2.1
  security:
    dataPlane:
      mtls: true
    certificateAuthority:
      type: Istiod
      istiod:
        type: PrivateKey
        privateKey:
          rootCADir:  /etc/cacerts
EOF

oc apply -f servicemesh-controlplane.yaml

## Create new ns for Bookinfo
oc new-project bookinfo

oc label namespace bookinfo istio-injection=enabled

cat > servicemesh-controlplane-member.yaml << EOF
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  namespace: bookinfo
  name: default
spec:
  controlPlaneRef:
    name: basic
    namespace: istio-system
EOF

oc apply -f servicemesh-controlplane-member.yaml -n bookinfo

cat > servicemesh-controlplane-memberrole.yaml << EOF
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
  - bookinfo
EOF

oc apply -f servicemesh-controlplane-memberrole.yaml -n istio-system

oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/platform/kube/bookinfo.yaml

oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/bookinfo-gateway.yaml

export SM_GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')

oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/destination-rule-all-mtls.yaml

oc get pods -n bookinfo

echo "http://$SM_GATEWAY_URL/productpage"

#### OLLLDDDD



##### IDK

## Switch over to the cert-manager ns lol
oc project cert-manager

## Add the meshworkload Vault ClusterIssuer ServiceAccount
oc create serviceaccount mesh-vault-clusterissuer
MESH_ISSUER_SECRET_REF=$(oc get serviceaccount meshworkloads-vault-clusterissuer -o json | jq -r ".secrets[] | select(.name|test(\"token\")) | .name ")

## Note: It is important to use an issuer type that is able to sign Istio mTLS workload certificates (SPIFFE URI SANs) and istiod serving certificates. ACME issuers will not work.

cat > mesh-vault-clusterissuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: mesh-vault-clusterissuer
spec:
  vault:
    server: http://vault.hashicorp-vault:8200
    path: meshworkloads/sign/ups-demo-dot-com
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: meshissuer
        secretRef:
          name: ${MESH_ISSUER_SECRET_REF}
          key: token
EOF

oc apply -f mesh-vault-clusterissuer.yaml

## Create a ClusterIssuer for istio-csr
## Key Usages: https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.KeyUsage
cat > istio-csr-clusterissuer.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: istio-ca
  # namespace for the Certificate/Secret must be in cert-manager namespace if using istio-csr
  # namespace: cert-manager
spec:
  isCA: true
  duration: 2160h # 90d
  secretName: istio-ca
  commonName: istio-ca
  usages:
    - signing
    - digital signature
    - content commitment
    - key encipherment
    - key agreement
    - data encipherment
    - cert sign
    - crl sign
    - server auth
    - client auth
    - ipsec end system
    - ipsec tunnel
    - ipsec user
    - ocsp signing
    - timestamping
  subject:
    organizations:
    - cluster.local
    - cert-manager
  issuerRef:
    name: mesh-vault-clusterissuer
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: istio-ca
spec:
  ca:
    secretName: istio-ca
EOF

## Install the Helm Chart
helm install -n cert-manager cert-manager-istio-csr jetstack/cert-manager-istio-csr

## Pull PEMs
CERTIFICATE_SECRET_NAME=$(oc get certificate istio-ca -o jsonpath='{.spec.secretName}')
CERT_CA_CERT=$(oc get secret ${CERTIFICATE_SECRET_NAME} -o jsonpath='{.data.ca\.crt}' | base64 -d)
CERT_TLS_CERT=$(oc get secret ${CERTIFICATE_SECRET_NAME} -o jsonpath='{.data.tls\.crt}' | base64 -d)
CERT_TLS_KEY=$(oc get secret ${CERTIFICATE_SECRET_NAME} -o jsonpath='{.data.tls\.key}' | base64 -d)

## Echo to files
echo "${CERT_TLS_CERT}" > ca-cert.pem
echo "${CERT_TLS_KEY}" > ca-key.pem
echo "${CERT_CA_CERT}" > root-cert.pem

## Create Secret
oc create secret generic cacerts -n istio-system --from-file=ca-cert.pem --from-file=ca-key.pem --from-file=root-cert.pem --from-file=cert-chain.pem=root-cert.pem

## Clean up
rm ca-cert.pem ca-key.pem root-cert.pem

## Create serviceMesh

## Install Jaeger
cat > jaeger-operator.yaml << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: jaeger-product
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: jaeger-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: jaeger-operator.v1.28.0
EOF

## Install Kiali
cat > kiali.yaml << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kiali-ossm
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: kiali-ossm
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: kiali-operator.v1.36.6
EOF

## Install ServiceMeshCP
cat > servicemesh-controlplane.yaml << EOF
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  addons:
    grafana:
      enabled: true
    jaeger:
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
    prometheus:
      enabled: true
  policy:
    type: Istiod
  telemetry:
    type: Istiod
  version: v2.1
  security:
    dataPlane:
      mtls: true
    certificateAuthority:
      type: Istiod
      istiod:
        type: PrivateKey
        privateKey:
          rootCADir:  /etc/cacerts
EOF

## Maybe...
## Create Signing CA as above
## Add as follows: https://docs.openshift.com/container-platform/4.9/service_mesh/v2x/ossm-security.html#ossm-cert-manage_ossm-security
## Add ServiceMeshControlPlane
```

# IDK?

## Deploying istio-csr

`istio-csr` is a project by cert-manager (and thus the community around Jetstack) that acts as a bridge from cert-manager to Istiod in a Service Mesh.  This allows it to intercept and broker the certificate requests for workload identity and traffic encryption.

```bash

## Install Helm: https://github.com/helm/helm#install

## Add Jetstack Helm Repo
helm repo add jetstack https://charts.jetstack.io

## Update helm
helm repo update


```

> Extra bonus:  Using Open Policy Agent to enforce standards and annocations to ensure all workloads are secured.

## Using OPA to enforce annotations for secure Ingresses/Gateways/Routes/etc

## Extra cert-manager & Service Mesh Notes

- Traffic into the service mesh must always go through the ingress-gateway for Istio to work properly.