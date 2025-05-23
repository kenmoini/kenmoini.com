---
title: "Kyverno Policies for Outbound HTTP Proxies"
date: 2025-05-22T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/kyverno.png
photo_credit:
  title: Some asshole on Pexels
  source: Pexels
tags:
  - openshift
  - red hat
  - kubernetes
  - containers
  - gitops
  - argocd
  - acm
  - rhacm
  - kyverno
  - proxy
authors:
  - Ken Moini
---

> Sitting here sick AF and felt the need to do SOMETHING while I'm coughing up a lung on the couch

Figured I'd toss out a quick article to get the juices flowing again - so as I went through my patchwork collection of HackMD docs, I found this one that's actually pretty handy.

**Situation**:  Customer is deploying a workload on OpenShift, it needs to talk to services via an Outbound HTTP Proxy.

**Background:**

- OpenShift has configuration available to configure an Outbound HTTP Proxy - [this cluster-wide Proxy configuration is only used for system components, not user workloads](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html/networking/enable-cluster-wide-proxy#prerequisites_cluster-wide-proxy).
- This workload is deployed via Helm and the chart currently has no method of adding additional environmental variables to define `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` (!?!?!?!)
- The workload is comprised of 100s of Pods so manually configuring things is not realistic

So with the understanding that OpenShift's cluster-wide proxy configuration is only used for things like image pulls, Insights, Updates, etc - and that manually configuring things works but does not scale - we need some sort of solution that can easily inject the environmental variables for the Pods to use an Outbound HTTP Proxy.

---

## Enter: Kyverno

Kubernetes has things called Admission Controllers, and these Admission Controllers can do things such as mutate requests, validate requests, etc - and those functions allow these Admission Controllers to do different function as objects are created, updated, deleted, etc in the cluster.

Kyverno is one example of an ensemble of Admission Controllers.  It can block things from being created entirely or in parts of configuration, it can enforce configuration states, generate related objects, and change specific objects.  This combination solves our need to apply Environmental Variables for the Outbound HTTP Proxy to pods without having to do so individually.

In fact, this is one of those out-of-the-box examples Kyverno comes with: https://kyverno.io/policies/other/add-pod-proxies/add-pod-proxies/

---

## Installing Kyverno

Getting started with Kyverno is super easy - it's just a Helm chart.  Deploy with your favorite method:

```bash
# Install Chart Repo and update local stores
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Deploy via Helm with "production" replica counts
helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
--set admissionController.replicas=3 \
--set backgroundController.replicas=2 \
--set cleanupController.replicas=2 \
--set reportsController.replicas=2
```

Or maybe with an [ArgoCD ApplicationSet](https://github.com/kenmoini/lab-ocp/blob/main/rhacm/gitops/appset-install-kyverno.yaml).

---

## Kyverno Policy

So adding a bit to that example, we can make something more useful to where any Pod in a namespace that has a label of `outbound-proxy: enabled` will have the Environmental Variables automatically injected into the running Pods that are scheduled.

Additionally, this same ClusterPolicy will apply a different Outbound HTTP Proxy if the namespace has a label of `outbound-proxy: secondary` - this configuration assumes the use of SSL Re-encryption, which needs a Root CA mounted to validate the certificate chain.  To support that there are additional rules in this ClusterPolicy around this secondary outbound proxy that will create and configure the needed bits for mounting a Root CA from a ConfigMap to the Pods as well:

```yaml
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-pod-proxies
  annotations:
    policies.kyverno.io/title: Add Pod Proxies
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/category: Sample
    policies.kyverno.io/minversion: 1.6.0
    policies.kyverno.io/description: >-
      In restricted environments, Pods may not be allowed to egress directly to all destinations
      and some overrides to specific addresses may need to go through a corporate proxy.
      This policy adds proxy information to Pods in the form of environment variables.
      It will add the `env` array if not present. If any Pods have any of these
      env vars, they will be overwritten with the value(s) in this policy.
spec:
  rules:
  # This rule adds an Outbound HTTP Proxy to Pods in namespaces with a label matching:
  # outbound-proxy: enabled
  # or
  # outbound-proxy: primary
  - name: add-pod-primary-proxies
    match:
      any:
        - resources:
            kinds:
              - Pod # Pod will apply to its owners as well
              #- Deployment # Just for Deployments instead of all Pod controllers
            operations:
            # Don't need to match on DELETE eh?
              - CREATE
              - UPDATE
            # Only match Namespaces with the label "outbound-proxy=enabled"
            # This is a good way to scope the policy to only certain namespaces
            # and not all namespaces in the cluster.
            namespaceSelector:
              matchExpressions:
                - key: outbound-proxy
                  operator: In
                  values:
                  - enabled
                  - primary
    mutate:
      patchStrategicMerge:
        spec:
          containers:
            - (name): "*"
              env:
              - name: HTTP_PROXY
                value: http://proxy.kemo.labs:3129
              - name: HTTPS_PROXY
                value: http://proxy.kemo.labs:3129
              - name: NO_PROXY
                value: '.kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local'

  # This rule adds an Outbound HTTP Proxy to Pods in namespaces with a label matching:
  # outbound-proxy: secondary
  # The following rules after this one support this rule with the assumption that
  # the secondary outbound proxy does SSL MitM'ing
  - name: add-pod-secondary-proxies
    match:
      any:
        - resources:
            kinds:
              - Pod # Pod will apply to its owners as well
              #- Deployment # Just for Deployments instead of all Pod controllers
            operations:
            # Don't need to match on DELETE eh?
              - CREATE
              - UPDATE
            # Only match Namespaces with the label "outbound-proxy=enabled"
            # This is a good way to scope the policy to only certain namespaces
            # and not all namespaces in the cluster.
            namespaceSelector:
              matchExpressions:
                - key: outbound-proxy
                  operator: In
                  values:
                  - secondary
            # Only match Pods with the label "app=critical"
            # This is a good way to scope the policy to only certain Pods
            # and not all Pods in the namespace/cluster.
            selector:
              matchLabels:
                flag.proxy: enabled
    mutate:
      patchStrategicMerge:
        spec:
          containers:
            - (name): "*"
              env:
                - name: HTTP_PROXY
                  value: http://proxy.kemo.labs:3128
                - name: HTTPS_PROXY
                  value: http://proxy.kemo.labs:3128
                - name: NO_PROXY
                  value: '.kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local'

  - name: add-pod-secondary-proxies-ca-mnt
    match:
      any:
        - resources:
            kinds:
              - Pod
            operations:
              - CREATE
              - UPDATE
            namespaceSelector:
              matchExpressions:
                - key: outbound-proxy
                  operator: In
                  values:
                  - secondary
            selector:
              matchLabels:
                attachProxyRootCA: enabled
    mutate:
      patchStrategicMerge:
        spec:
          volumes:
            - name: out-prxy-root-ca
              configMap:
                name: out-prxy-root-ca
                items:
                  - key: ca-bundle.crt
                    path: tls-ca-bundle.pem
          containers:
            - (name): "*"
              volumeMounts:
                - mountPath: /etc/pki/ca-trust/extracted/pem
                  name: out-prxy-root-ca
                  readOnly: true

  - name: add-pod-secondary-proxies-ca
    match:
      any:
        - resources:
            kinds:
              - Pod
            operations:
              - CREATE
              - UPDATE
            namespaceSelector:
              matchExpressions:
                - key: outbound-proxy
                  operator: In
                  values:
                  - secondary
            selector:
              matchLabels:
                attachProxyRootCA: enabled
    generate:
      synchronize: false
      apiVersion: v1
      kind: ConfigMap
      name: out-prxy-root-ca
      namespace: '{{ "{{ request.object.metadata.namespace }}" }}'
      data:
        kind: ConfigMap
        metadata:
          labels:
            config.openshift.io/inject-trusted-cabundle: 'true'
          data: {}
```

Now, once a Namespace is labeled with `outbound-proxy: enabled|primary|secondary` and Pods are scheduled, they'll automatically have the needed Environmental Variables injected into them!

Note that if the Pods are already scheduled you'll need to delete/reschedule them so the mutating admission controller that Kyverno provides is actually applied.

---

## Policy Inception with RHACM

That's great and all for one cluster - but what about multiple clusters?

Of course you could just drop this into ArgoCD and GitOps it around - or if you're using something like Red Hat Advanced Cluster Management, you could wrap the Kyverno Policy in an ACM Policy and distribute it as a function of Governance instead of GitOps:

```yaml
---
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: kyverno-outbound-proxy
  annotations:
    policy.open-cluster-management.io/description: Configures certain workloads to automatically work with a proxy.
    policy.open-cluster-management.io/standards: Kemo Labs 2025
    policy.open-cluster-management.io/categories: OCPKG - OpenShift Kyverno Governance
    policy.open-cluster-management.io/controls: CP-CFG - ClusterPolicy - Configuration
spec:
  disabled: false
  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: kyverno-outbound-proxy
        spec:
          remediationAction: enforce
          severity: critical
          object-templates:
            - complianceType: musthave
              objectDefinition:
                apiVersion: kyverno.io/v1
                kind: ClusterPolicy
                metadata:
                  name: add-pod-proxies
                  annotations:
                    policies.kyverno.io/title: Add Pod Proxies
                    policies.kyverno.io/subject: Pod
                    policies.kyverno.io/category: Sample
                    policies.kyverno.io/minversion: 1.6.0
                    policies.kyverno.io/description: >-
                      In restricted environments, Pods may not be allowed to egress directly to all destinations
                      and some overrides to specific addresses may need to go through a corporate proxy.
                      This policy adds proxy information to Pods in the form of environment variables.
                      It will add the `env` array if not present. If any Pods have any of these
                      env vars, they will be overwritten with the value(s) in this policy.
                spec:
                  rules:
                  - name: add-pod-primary-proxies
                    match:
                      any:
                        - resources:
                            kinds:
                              - Pod # Pod will apply to its owners as well
                              #- Deployment # Just for Deployments instead of all Pod controllers
                            operations:
                            # Don't need to match on DELETE eh?
                              - CREATE
                              - UPDATE
                            # Only match Namespaces with the label "outbound-proxy=enabled"
                            # This is a good way to scope the policy to only certain namespaces
                            # and not all namespaces in the cluster.
                            namespaceSelector:
                              matchExpressions:
                                - key: outbound-proxy
                                  operator: In
                                  values:
                                  - enabled
                                  - primary
                            # Only match Pods with the label "app=critical"
                            # This is a good way to scope the policy to only certain Pods
                            # and not all Pods in the namespace/cluster.
                            selector:
                              matchLabels:
                                flag.proxy: enabled
                    mutate:
                      patchStrategicMerge:
                        spec:
                          containers:
                            - (name): "*"
                              env:
                              - name: HTTP_PROXY
                                value: http://proxy.kemo.labs:3129
                              - name: HTTPS_PROXY
                                value: http://proxy.kemo.labs:3129
                              - name: NO_PROXY
                                value: '.kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local'

                  - name: add-pod-secondary-proxies
                    match:
                      any:
                        - resources:
                            kinds:
                              - Pod # Pod will apply to its owners as well
                              #- Deployment # Just for Deployments instead of all Pod controllers
                            operations:
                            # Don't need to match on DELETE eh?
                              - CREATE
                              - UPDATE
                            # Only match Namespaces with the label "outbound-proxy=enabled"
                            # This is a good way to scope the policy to only certain namespaces
                            # and not all namespaces in the cluster.
                            namespaceSelector:
                              matchExpressions:
                                - key: outbound-proxy
                                  operator: In
                                  values:
                                  - secondary
                            # Only match Pods with the label "app=critical"
                            # This is a good way to scope the policy to only certain Pods
                            # and not all Pods in the namespace/cluster.
                            selector:
                              matchLabels:
                                flag.proxy: enabled
                    mutate:
                      patchStrategicMerge:
                        spec:
                          containers:
                            - (name): "*"
                              env:
                                - name: HTTP_PROXY
                                  value: http://proxy.kemo.labs:3128
                                - name: HTTPS_PROXY
                                  value: http://proxy.kemo.labs:3128
                                - name: NO_PROXY
                                  value: '.kemo.labs,.kemo.network,192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,localhost,127.0.0.1,.svc,.local'

                  - name: add-pod-secondary-proxies-ca-mnt
                    match:
                      any:
                        - resources:
                            kinds:
                              - Pod
                            operations:
                              - CREATE
                              - UPDATE
                            namespaceSelector:
                              matchExpressions:
                                - key: outbound-proxy
                                  operator: In
                                  values:
                                  - secondary
                            selector:
                              matchLabels:
                                attachProxyRootCA: enabled
                    mutate:
                      patchStrategicMerge:
                        spec:
                          volumes:
                            - name: out-prxy-root-ca
                              configMap:
                                name: out-prxy-root-ca
                                items:
                                  - key: ca-bundle.crt
                                    path: tls-ca-bundle.pem
                          containers:
                            - (name): "*"
                              volumeMounts:
                                - mountPath: /etc/pki/ca-trust/extracted/pem
                                  name: out-prxy-root-ca
                                  readOnly: true

                  - name: add-pod-secondary-proxies-ca
                    match:
                      any:
                        - resources:
                            kinds:
                              - Pod
                            operations:
                              - CREATE
                              - UPDATE
                            namespaceSelector:
                              matchExpressions:
                                - key: outbound-proxy
                                  operator: In
                                  values:
                                  - secondary
                            selector:
                              matchLabels:
                                attachProxyRootCA: enabled
                    generate:
                      synchronize: false
                      apiVersion: v1
                      kind: ConfigMap
                      name: out-prxy-root-ca
                      namespace: '{{ "{{ request.object.metadata.namespace }}" }}'
                      data:
                        kind: ConfigMap
                        metadata:
                          labels:
                            config.openshift.io/inject-trusted-cabundle: 'true'
                          data: {}
```

Pair that with the ApplicationSet linked above, and you've got ACM pushing Kyverno and its Policies out to all your various clusters under its management!