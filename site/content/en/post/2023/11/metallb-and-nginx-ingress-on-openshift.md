---
title: MetalLB, Nginx Ingress, and Cert-Manager on OpenShift
date: 2023-11-30T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/metallb-nginx-openshift.png
photo_credit:
  title: Pixabay
  source: https://www.pexels.com/photo/balance-ocean-relaxation-rock-balancing-267950/
tags:
  - open source
  - oss
  - openshift
  - kubernetes
  - k8s
  - metallb
  - nginx-ingress
authors:
  - Ken Moini
---

> It's Peanut Butter Jelly Time y'all

Ask anyone and they'll tell you that I love MetalLB - I use it profusely.  Where I can anyway, *it doesn't do too well in the cloud.*

I use it with my Kubernetes clusters to expose services such as DNS so I don't have to use NodePorts and weird firewall forwarding.  I have customers who use it with their OpenShift clusters to expose things like databases and even other Ingresses.

Today I'm going to show you how to do just that - we'll deploy the MetalLB Operator, and then the NGINX Ingress Operator and get them to sing a little song together.  *As an added bonus, we'll even set up Cert-Manager with some automated TLS goodness!*

---

> You can skip all this and just apply the assets in this repository: [ocp-metallb-nginx-ingress](https://github.com/kenmoini/ocp-metallb-nginx-ingress)

---

## Namespaces

First thing's first, we need to make a few Namespace - or Projects when working in OpenShift.  We'll make 4 of them, one for MetalLB, NGINX-Ingress, a test workload, and even as a bonus - Cert-Manager.  What's an Ingress without TLS after all?

#### Via the CLI

```bash
oc create ns metallb-system
oc create ns nginx-ingress
oc create ns cert-manager-operator
oc create ns workload-test
```

#### Via YAML Manifests

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-ingress
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-operator
---
apiVersion: v1
kind: Namespace
metadata:
  name: workload-test
```

---

## Security Controls

Now in order for NGINX Ingress to operate properly in OpenShift, you need to create a SecurityContextConstraint that gives it permission to leverage privileged ports.  Any port in OpenShift below 1024 is considered a privileged port.  Now you could just give it the `privileged` SCC that's built in, but that gives it too much permission - it's pretty easy to create an SCC that only allows what it needs to run:

#### Via the CLI

```bash
# Create the SecurityContextConstraint for NGINX Ingress
oc apply -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/nginx-ingress/operator/base/scc.yml

# Create the ClusteRole that allows use of the SCC
oc apply -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/nginx-ingress/operator/base/clusterrole.yml

# Create the RoleBinding that allows the NGINX Ingress ServiceAccount to use the SCC via the ClusterRole
oc apply -n nginx-ingress -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/nginx-ingress/operator/base/clusterrolebinding.yml
```

#### Via YAML Manifests

```yaml
## Custom SCC for Nginx Ingress
---
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  annotations:
    kubernetes.io/description: Provides all features of the restricted SCC but allows users to run with any UID and any GID, in addition to binding to privileged ports
  name: anyuid-netbind
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: true
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities:
  - NET_BIND_SERVICE
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups:
  - system:cluster-admins
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities:
  - ALL
runAsUser:
  type: RunAsAny
seccompProfiles:    
  - runtime/default
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users: []
volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: 'system:openshift:scc:anyuid-netbind'
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: 'true'
rules:
  - verbs:
      - use
    apiGroups:
      - security.openshift.io
    resources:
      - securitycontextconstraints
    resourceNames:
      - anyuid-netbind
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nginx-ingress
  namespace: nginx-ingress
subjects:
  - kind: ServiceAccount
    name: nginx-ingress
    namespace: nginx-ingress
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: 'system:openshift:scc:anyuid-netbind'
```

---

## Install Operators

Next we'll install the Operators we need. You can easily do this with a few click in the OpenShit Web UI, which is the way I like to do things for one-off deployments or testing - or you can do so still with YAML manifests via the CLI or via GitOps.

There are a few assets that would be needed such as a Subscription and OperatorGroup Custom Resources - to deploy them all we'll leverage Kustomize.  You can create a `kustomization.yml` file that points to all the separate files to actuate, and then use the `-k` flag instead of a `-f` flag when creating/applying the manifests.

#### Via the CLI

```bash
# Install the MetalLB Operator
oc apply -k github.com/kenmoini/ocp-metallb-nginx-ingress/metallb/operator/base/

# Install the NGINX Ingress Operator
oc apply -k github.com/kenmoini/ocp-metallb-nginx-ingress/nginx-ingress/operator/base/

# Install the Cert-Manager Operator
oc apply -k github.com/kenmoini/ocp-metallb-nginx-ingress/cert-manager/operator/overlays/stable-v1/
```

#### Via YAML Manifests - MetalLB

```yaml
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: metallb
  namespace: metallb-system
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: metallb-operator
  namespace: metallb-system
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  channel: stable
  installPlanApproval: Automatic
  name: metallb-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

#### Via YAML Manifests - NGINX-Ingress

```yaml
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nginx-ingress-operator
  namespace: nginx-ingress
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec: {}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nginx-ingress-operator
  namespace: nginx-ingress
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: nginx-ingress-operator
  source: certified-operators
  sourceNamespace: openshift-marketplace
```

#### Via YAML Manifests - Cert-Manager

```yaml
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  targetNamespaces:
    - cert-manager-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  channel: stable-v1
  installPlanApproval: Automatic
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

---

## Operator Instances - MetalLB

Once the Operators are installed, you'll need to create a few assets to instantiate them.  This process deploys the actual controllers that do the work of doing things like deploying the MetalLB Speaker pods, NGINX Ingress workloads, and Cert-Manager webhook controllers.

### Configuring MetalLB

Deploying MetalLB is pretty easy - you can probably just use the base MetalLB CR without any modifications.  If you want to run it only on a specific set of nodes you could do that, along with a series of other advanced modifications such as specifying affinities, node selectors, and runtime classes.  You can read more about that here: https://docs.openshift.com/container-platform/4.14/networking/metallb/metallb-operator-install.html#nw-metallb-operator-deployment-specifications-for-metallb_metallb-operator-install

First off, deploy the MetalLB CR to instantiate the Operator.

#### Via the CLI

```bash
# Instantiate the MetalLB System
oc apply -k github.com/kenmoini/ocp-metallb-nginx-ingress/metallb/instance/overlays/default/
```

#### Via YAML Manifests

```yaml
---
apiVersion: metallb.io/v1beta1
kind: MetalLB
metadata:
  name: metallb
  namespace: metallb-system
spec:
  logLevel: debug
  # Optional Configuration:
  #nodeSelector:
  #  node-role.kubernetes.io/worker: ""
  #speakerTolerations:
  #  - key: "Example"
  #    operator: "Exists"
  #    effect: "NoExecute"
  #controllerConfig:
  #  runtimeClassName: myclass
  #  annotations: 
  #    controller: demo
  #  resources:
  #    limits:
  #      cpu: "200m"
  #  priorityClassName: high-priority
  #  affinity:
  #    podAffinity:
  #      requiredDuringSchedulingIgnoredDuringExecution:
  #      - labelSelector:
  #          matchLabels:
  #            app: metallb
  #        topologyKey: kubernetes.io/hostname
  #
  #speakerConfig:
  #  runtimeClassName: myclass
  #  annotations: 
  #    speaker: demo
  #  resources:
  #    limits:
  #      cpu: "200m"
  #  priorityClassName: high-priority
  #  affinity:
  #    podAffinity:
  #      requiredDuringSchedulingIgnoredDuringExecution:
  #      - labelSelector:
  #          matchLabels:
  #            app: metallb
  #        topologyKey: kubernetes.io/hostname
```

### Configuring MetalLB Address Pools

Once the MetalLB Speaker pods are deployed and ready, you can create some Address Pools to use for Load Balancer Services.  This will look different in everyone's environment so make sure to reference the documentation to see what options are available.  Below you'll find some examples for simple Layer 2 Address Pools, but there are BGP options available as well.

```yaml
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lab-pool
spec:
  addresses:
    - 192.168.42.2-192.168.42.100
    - 192.168.70.0/24
  autoAssign: false
  protocol: layer2
```

```yaml
---
kind: L2Advertisement
apiVersion: metallb.io/v1beta1
metadata:
  name: lab-l2-adv
spec:
  ipAddressPools:
    - lab-pool # Must match the name of the IPAddressPool
```

**Note:** *The IPAddressPool has the `.spec.autoAssign` value set to `false` - this is a good practice otherwise you may find random LoadBalancer type Services on the cluster consuming IPs that you want to use for other things.*

Once you have your IPAddressPools set up, you can start to provision LoadBalancer-type Services - let's do that with our Test Workload.

---

## Workload Test - Service

Now that MetalLB is deployed and configured, we can test an application deployment with a LoadBalancer-type service - such as a simple HTTPd server.

#### Via the CLI

```bash
# Create the Deployment and Service
oc apply -n workload-test -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/test-deployment/deployment.yml
oc apply -n workload-test -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/test-deployment/service.yml

# Edit the Service annotation to match an IP in your IPAddressPool
oc edit -n workload-test service httpd
```

#### Via YAML Manifests

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpd
spec:
  selector:
    matchLabels:
      app: httpd
  replicas: 1
  template:
    metadata:
      labels:
        app: httpd
    spec:
      containers:
        - name: httpd
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 100m
              memory: 128Mi
          image: registry.access.redhat.com/ubi8/httpd-24@sha256:b72f2fd69dbc32d273bebb2da30734c9bc8d9acfd210200e9ad5e69d8b089372
          ports:
            - containerPort: 8080
```

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: httpd
  annotations:
    # Make sure the annotations match the specification fo your IPAddressPool
    metallb.universe.tf/address-pool: lab-pool
    metallb.universe.tf/loadBalancerIPs: 192.168.70.11
spec:
  selector:
    app: httpd
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  type: LoadBalancer
```

Once you have the Deployment and Service created, you can test the LoadBalancer service by going to the assigned IP Address via `curl` or your Web Browser at port 8080, eg `curl http://192.168.70.11:8080/`.  You should see the Apache HTTPd Welcome page

Next we can provision one of these LoadBalancer IPs to be used with NGINX Ingress.

---

## Operator Instances - NGINX Ingress

With the NGINX Ingress Operator installed, next we'll create the NGINXIngress CR that holds the configuration of the IngressController deployment.  This allows entry into the cluster to workloads defined by an Ingress object similarly to how Routes work natively in OpenShift.

**Note:** *You'll need to be able to set some DNS records for your intended workloads' Ingress objects.  These could be one-off records or a Wildcard record similar to the application wildcard used by the default Routes in OpenShift.*

Either way they'll need to point to the IP of the LoadBalancer type Service created by the NGINX Ingress Controller in the next step.

### Configuring NGINX Ingress

Since the specification will likely change for each deployment, I suggest applying it via YAML - see below for guidance on what you may need to edit:

The specification for the configuration are simply based on the Helm Chart which you can find here: https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

```yaml
# Cluster-wide CA Trust
# Read more about it here: https://kenmoini.com/post/2022/02/custom-root-ca-in-openshift/#openshift-cluster-wide-root-cas
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: trusted-ca
  labels:
    config.openshift.io/inject-trusted-cabundle: 'true'
data: {}
```

```yaml
# Adapt when needed from the Helm Chart values
# https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
---
apiVersion: charts.nginx.org/v1alpha1
kind: NginxIngress
metadata:
  annotations:
    operator-sdk/primary-resource: /nginx
    operator-sdk/primary-resource-type: IngressClass.networking.k8s.io
  name: nginx-ingress
spec:
  controller:
    logLevel: 1
    ingressClass:
      name: nginx
    kind: deployment
    #kind: daemonset
    replicaCount: 1
    # Service definition, namely note the annotation to use the metallb load balancer
    service:
      create: true
      type: LoadBalancer
      # EDIT THIS - Match the annotations to your IPAddressPool
      annotations:
        metallb.universe.tf/address-pool: lab-pool
        metallb.universe.tf/loadBalancerIPs: 192.168.70.12
      externalIPs: []
      customPorts: []
      loadBalancerIP: ''
      externalTrafficPolicy: Local
      httpPort:
        enable: true
        port: 80
        targetPort: 80
      httpsPort:
        enable: true
        port: 443
        targetPort: 443
      loadBalancerSourceRanges: []
      extraLabels: {}
    # UBI-based Image
    image:
      pullPolicy: IfNotPresent
      repository: nginx/nginx-ingress
      tag: 3.2.0-ubi
    # Volume mounts for the trusted CA bundle
    volumeMounts: 
    - name: trusted-ca
      mountPath: /etc/pki/tls/certs/cert-manager-tls-ca-bundle.crt
      subPath: ca-bundle.crt
    volumes:
    - name: trusted-ca
      configMap:
        name: trusted-ca
        defaultMode: 420
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
    includeYear: false
    enableCertManager: false
    hostNetwork: false
    enableLatencyMetrics: false
    setAsDefaultIngress: false
    terminationGracePeriodSeconds: 30
    nginxStatus:
      allowCidrs: 127.0.0.1
      enable: true
      port: 8080
    nginxReloadTimeout: 60000
    healthStatus: false
    appprotect:
      enable: false
    minReadySeconds: 1
    disableIPV6: false
    enableCustomResources: true
    globalConfiguration:
      create: false
      spec: {}
    reportIngressStatus:
      annotations: {}
      enable: true
      enableLeaderElection: true
      ingressLink: ''
    enablePreviewPolicies: false
    readyStatus:
      enable: true
      initialDelaySeconds: 0
      port: 8081
    autoscaling:
      annotations: {}
      enabled: false
      maxReplicas: 3
      minReplicas: 1
      targetCPUUtilizationPercentage: 50
      targetMemoryUtilizationPercentage: 50
    enableSnippets: false
    nginxDebug: false
    appprotectdos:
      debug: false
      enable: false
      maxDaemons: 0
      maxWorkers: 0
      memory: 0
    dnsPolicy: ClusterFirst
    enableExternalDNS: false
    enableTLSPassthrough: false
    enableOIDC: false
    healthStatusURI: /nginx-health
  prometheus:
    create: true
    port: 9113
    scheme: http
  rbac:
    create: true
  readOnlyRootFilesystem: false
```

With the NginxIngress configuration created you should see some Pods start in the nginx-ingress Namespace as well as the creation of a LoadBalancer-type Service.

Navigating to that Service LoadBalancer IP should yield the default NGINX Ingress 404 Page.  You can set any sort of DNS A record to here to resolve endpoints to the NGINX Ingress now.

However, in order for those DNS records to be forwarded to the right workload you must create an Ingress resource in the cluster - let's expand on our example test workload with an Ingress pointing to the Service that was previously created.

---

## Workload Test - Ingress

Now that we have the NGINX Ingress controller deployed, we can create an Ingress object that points to our workload and exposes the application.  To do this we'll create a ClusterIP type of Service:

**Note:** *If you did the `oc apply -f` above to create the Workload Test Service from my GitHub repo then this service was already created as well - there are two Services in that file, one LoadBalancer type and one ClusterIP type, the latter of which is used with the Ingress.*

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: httpd-for-ingress
  namespace: workload-test
spec:
  selector:
    app: httpd
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  type: ClusterIP
```

Now that we have a ClusterIP service created, we can create an Ingress that points to it and defines the URI we want to access the application from:

```yaml
# Or: oc apply -n workload-test -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/test-deployment/ingress-no-tls.yml
# Will need to change it after being applied though to point to your DNS Record for the host
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpd-no-tls
  namespace: workload-test
spec:
  rules:
    - host: hello-everyone.test.kemo.labs # Change this to point to a DNS record that points to the LoadBalancer type Service IP created by the NGINX Ingress
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: httpd-for-ingress
                port:
                  number: 8080
  ingressClassName: nginx
```

With that created you should now be able to navigate in your browser (or do a `curl`) to `http://hello-everyone.test.kemo.labs` - or rather, whatever you changed that `host` line to that works in your environment.

---

> Huzzah!  MetalLB with NGINX Ingress!  We're done, right?

Well, we could stop here but where's the fun in that?  Why not take it up a notch by adding some Cert-Manager goodness for automated TLS certificates!

---

## Operator Instances - Cert-Manager

Since we previously installed the Cert-Manager operator, setting it up is pretty easy.  You can most often just create a blank/default CertManager CR which is applied cluster-wide:

#### Via the CLI

```bash
# Deploy a base configuration that should work most everywhere
oc apply -k github.com/kenmoini/ocp-metallb-nginx-ingress/cert-manager/instance/overlays/default/

# or, an example using an Outbound Proxy
oc apply -k github.com/kenmoini/ocp-metallb-nginx-ingress/cert-manager/instance/overlays/outbound-proxy/
```

#### Via YAML Manifests

```yaml
---
apiVersion: operator.openshift.io/v1alpha1
kind: CertManager
metadata:
  name: cluster
spec:
  logLevel: Normal
  operatorLogLevel: Normal
  managementState: Managed
  #controllerConfig:
  #  overrideEnv:
  #    - name: HTTP_PROXY
  #      value: 'http://192.168.42.31:3128'
  #    - name: HTTPS_PROXY
  #      value: 'http://192.168.42.31:3128'
  #    - name: NO_PROXY
  #      value: .cluster.local,.kemo.labs,.kemo.network,.svc,.svc.cluster.local,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.0.0/16,192.168.70.0/24,localhost
```

### Configuring Cert-Manager

With the Cert-Manager instance set up, you still need to create either Namespaced Issuers or cluster-wide ClusterIssuers to use with CertificateRequests.

Below you can find an example of a ClusterIssuer that allows you to create Certificates signed by the Let's Encrypt CA, a widely used and free public CA:

```yaml
# Or: oc apply -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/test-deployment/cluster-issuer-letsencrypt.yml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: hotmailsux@yahoo.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

---

## Using Cert-Manager with an Ingress

Now that we have all our Operators installed and configured, we can use Cert-Manager to give us TLS certificates for our Ingress objects!  Your Ingress object just needs a few annotations and the `.spec.tls` definition:

```yaml
# Or: oc apply -f https://raw.githubusercontent.com/kenmoini/ocp-metallb-nginx-ingress/main/test-deployment/ingress.yml
# Will need to change it after being applied though to point to your DNS Record for the host
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpd
  namespace: workload-test
  annotations:
    # add an annotation indicating the issuer to use.
    cert-manager.io/cluster-issuer: letsencrypt-prod
    acme.cert-manager.io/http01-ingress-class: nginx
spec:
  tls:
    - hosts:
        - hello.test.kemo.labs
      secretName: httpd-ingress-cert
  rules:
    - host: hello.test.kemo.network
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: httpd-for-ingress
                port:
                  number: 8080
  ingressClassName: nginx
```

With that Ingress created, you should now be able to navigate to `https://hello.test.kemo.network` - or whatever you changed that host to - and see a secured Ingress signed by Let's Encrypt publishing that HTTPd container!

---

## Troubleshooting

In case things aren't working as you'd expect them there are a few steps you can take.

First, check out the Pod logs for the MetalLB speaker pods, they'll be able to provide inspection into if the system can reconcile the configuration applied by the Custom Resources.

Next you'll need to check out the extended information on the Services itself.  You won't be able to find the information via the GUI or the YAML output of the Service so run an `oc describe service service-name-here` to see the information emitted by MetalLB about the Service.

If NGINX Ingress fails to deploy properly, check the CR for its `.status.conditions` - and then check the controller logs and Ingress object `.status.conditions` for issues with the Ingress objects.

If Cert-Manger is not issuing Certificate objects, check the `.status` of the CertificateRequests and the Pods in the `cert-manager-operator` namespace.  There may also be issues with the limits imposed by Let's Encrypt so make sure to change your email address in the ClusterIssuer above, and maybe even testing with the [Staging Environment](https://letsencrypt.org/docs/staging-environment/).