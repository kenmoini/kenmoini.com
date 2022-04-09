---
title: Custom Root CAs in OpenShift
date: 2022-02-18T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/custom-root-pki.png
tags:
  - openshift
  - ocp
  - private
  - pki
  - certificates
  - x509
  - certificate authority
  - root ca
  - security
  - privacy
  - open source
  - red hat
  - oss
  - homelab
  - containers
  - kubernetes
  - cloud
  - automation
  - docker
  - podman
  - registry
  - reflector
  - emberstack
  - podpreset
  - operator
authors:
  - Ken Moini
---

> Future Ken is confused why Past Ken has done so much work with PKI

---

So this is an interesting trip down a number of different technologies - the goal of this solution stack is to provide custom Root Certificate Authorities to containers running on OpenShift and there are of course a dozen different ways to make this sandwich.

*The following assumes you have a custom Root CA in PEM format and are performing the steps on a RHEL-based system.*

---

## Non-Container Example

So on a traditional Linux system, you would take your Root CA, copy it to a path on the file system, and then run a program which would update the system Root CA Trust Bundle and Java Keystore - along the lines of something like this:

```bash
## Copy your Root CA to the sources path
cp root-ca.pem /etc/pki/ca-trust/source/anchors/

## Update the Root CA Trust Bundles
update-ca-trust
```

From this point applications that use Certificates signed by that Root CA can be verified system-wide just as any other root could be such as ones signed by DigiCert, Let's Encrypt, Microsoft, etc - assuming that any other Intermediate CA Certificates are passed along with the client/server/user certificates.

---

## Container-centric Options

So this is great on a normal RHEL-based system, but what about in a container?  And what about on Kubernetes/OpenShift?  There are a few options and each have their own pros and cons:

### 1. Container Builds

This could be the simplest option for most people - just `COPY` the Root CA PEM file over to the container and `RUN` the `update-ca-trust` command during build-time and it would perform the same steps as above.

Now, this has the Root CA and Java Keystore baked into the image, but you'd have to do this either for a base image and maintain it and that lifecycle, or apply these steps to every Containerfile/Dockerfile individually.

This also has lifecycle impacts where you're rebuilding and redeploying images if there were ever a catastrophic Root CA Key compromise, but this shouldn't be an issue with a decently mature DevOps CI/CD pipeline.

Since it's at the container image level it can be with container runtimes such as Docker/Podman, and there are no YAML-edits or extra manifests needed on the Kubernetes/OpenShift platform side of things - ***but what if you don't want to maintain container image modifications for custom Root CAs and would rather leverage Kubernetes-native functions?***

---

### 2. ConfigMaps and Volume Mounts

So instead of embedding the Root CA Bundles inside of the container during the build process, we can attach the bundle files to containers running inside of a Kubernetes/OpenShift context via ConfigMaps.

Say you've run the commands above to add the Root CA to your system Root CA Bundles - you could then create a set of ConfigMaps like so:

```bash
## Create a ConfigMap YAML file for/from the PEM-encoded Root CA bundle
oc create configmap tls-ca-bundle-pem --from-file=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem -o yaml --dry-run=client > cfgmap-tls-ca-bundle-pem.yml

## Create a ConfigMap YAML file for/from the Java Keystore
oc create configmap jks-ca-certs --from-file=/etc/pki/ca-trust/extracted/java/cacerts -o yaml --dry-run=client > cfgmap-jks-ca-certs.yml
```

With that you could then add some Volumes and VolumeMounts to a Deployment similarly to this:

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: pki-toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pki
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: pki
    spec:
      containers:
        - name: pki
          image: 'quay.io/kenmoini/pki-toolbox:latest'
          command:
            - /bin/bash
            - '-c'
            - '--'
          args:
            - while true; do sleep 30; done;
          volumeMounts:
            - mountPath: /etc/pki/ca-trust/extracted/pem
              name: tls-ca-bundle-pem
              readOnly: true
            - mountPath: /etc/pki/ca-trust/extracted/java
              name: jks-ca-certs
              readOnly: true
      volumes:
        - name: tls-ca-bundle-pem
          configMap:
            items:
              - key: tls-ca-bundle.pem
                path: tls-ca-bundle.pem
            name: tls-ca-bundle-pem
        - name: jks-ca-certs
          configMap:
            items:
              - key: cacerts
                path: cacerts
            name: jks-ca-certs
```

This is a pretty simple way to distribute a custom Root CA Bundles and deploy it in a Kubernetes-native way - now, keep in mind this is needed to be done for any Pod-type object, and each Namespace needs to have those same ConfigMaps, Volume, and VolumeMounts defined.

At scale that can be challenging, but mature DevOps/GitOps practices can help alleviate some of those operational challenges for distribution of those ConfigMaps however the Deployments/DaemonSets/StatefulSets/etc objects need to be modified to mount those ConfigMaps.

***What about options that automatically mount those ConfigMaps to Pods on Kubernetes/OpenShift?***

---

### 3. Admission Controllers and MutatingWebhooks

With Kubernetes platforms, when submitting an object to the cluster the API utilizes an [Admission Controller](https://kubernetes.io/blog/2019/03/21/a-guide-to-kubernetes-admission-controllers/) to sort of intercept those objects before applying the manifest - this allows validation of Resource definition specifications, type constraints, and so on.

[Dynamic Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) provide functions such as [MutatingWebhooks](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook) and [ValidatingWebhooks](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook) take it a step further and allow extra modifications or validation logic to be applied when the Admission Controller relays CREATE/UPDATE/DELETE/etc requests.

An example of a ValidationWebhook would be to ensure Namespaces don't have certain phrases when being created or modified - MutatingWebhooks however mutate objects so a MutatingWebhook could certainly automatically apply Volumes and VolumeMounts to Pods as they're applied to the cluster!  ***This is the exact function that the Istio Service Mesh leverages to automatically inject the sidecar containers into labeled Pods.***

Using Dynamic Admission Controllers such MutatingWebhooks and ValidatingWebhooks is a generally advanced pattern for Kubernetes and something you see applied to mature production environments - it requires some configuration applied to the cluster and a custom web server that will respond to admission requests.  You can find a pretty solid starting point on [GitHub at slackhq/simple-kubernetes-webhook](https://github.com/slackhq/simple-kubernetes-webhook).

***What about something that's not so custom, like a MutatingWebhook that already can do this?***

---

### 4. PodPreset Operator

In previous versions of Kubernetes and OpenShift there was a PodPreset resource, an Admission Controller, that could take preset definitions of specifications such a Volumes, VolumeMounts, Env, etc and apply it to Pods - however this was removed because some galaxy brain folk decided there were better ways I guess?

The Red Hat Community of Practice which is comprised of a set of elite architects, consultants, engineers, and other people with super fancy titles have implemented this PodPreset functionality with a MutatingWebhook-based Operator - called the [PodPreset Operator](https://github.com/redhat-cop/podpreset-webhook).

You can apply the PodPreset Operator to a Kubernetes/OpenShift cluster with the following:

```bash
## Authenticate to a Kubernetes/OpenShift cluster, KUBECONFIG sorta stuff yeah?

## Clone down the repo
git clone https://github.com/redhat-cop/podpreset-webhook

## Enter the directory
cd podpreset-webhook

## Deploy the Operator to the cluster
make deploy IMG=quay.io/redhat-cop/podpreset-webhook:latest

## Check to make sure the Operator is applied and the PodPreset CRD is available
oc get crd/podpresets.redhatcop.redhat.io
```

Once that Operator is deployed you can use a PodPreset such as the following:

```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: PodPreset
metadata:
  name: pki-volumes
spec:
  selector:
    matchLabels:
      inject-pki: "yes"
  volumeMounts:
    - mountPath: /etc/pki/ca-trust/extracted/pem
      name: tls-ca-bundle-pem
      readOnly: true
    - mountPath: /etc/pki/ca-trust/extracted/java
      name: jks-ca-certs
      readOnly: true
  volumes:
    - configMap:
        items:
          - key: ca-bundle.crt
            path: tls-ca-bundle.pem
        name: tls-ca-bundle-pem
      name: tls-ca-bundle-pem
    - configMap:
        items:
          - key: cacerts
            path: cacerts
        name: jks-ca-certs
      name: jks-ca-certs
```

With that, your Deployments simply need to have Pods that match the label selector `inject-pki: "yes"` - working off the previous example, it'd look like this:

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: pki-toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pki
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: pki
        inject-pki: "yes"
    spec:
      containers:
      # ...
```

So that's great - at this point you would just need to:

1. Install the PodPreset Operator
2. Create a PodPreset resource in any needed Namespace/Project
3. Deploy the ConfigMaps specified by the PodPreset into the same Namespace/Project
4. Label the Deployments/DaemonSets/StatefulSets/etc with the label selector as specified in the PodPreset

Step 1 is a Day 1/Day 2 operation for cluster configuration, steps 2 and 3 can be added to CI/CD deployments with little effort, step 4 is a needed manual modification.

***What about OpenShift functions that can help reduce the level of effort required?***

---

## OpenShift Cluster-Wide Root CAs

So OpenShift has a few special functions that can provide fewer points of drift and failure in this workflow - one being cluster-wide Root CA bundle distribution.

You can read the full details of how this Root CA bundle is created and distributed here: https://access.redhat.com/documentation/en-us/openshift_container_platform/4.9/html/networking/configuring-a-custom-pki

It breaks down to creating/modifying a ConfigMap called `user-ca-bundle` in the `openshift-config` Namespace with a `.data['ca-bundle.crt']` entry, similar to below if you were adding 3 new Root CAs:

```yaml
apiVersion: v1
data:
  ca-bundle.crt: |
    -----BEGIN CERTIFICATE-----
    MIIGqzCCBJOgAwIBAgIUKMZCYZxHomZOUFLz8j0/ItBY/3cwDQYJKoZIhvcNAQEL
    BQAwgdwxKzApBgkqhkiG9w0BCQEWHGNlcnRtYXN0ZXJAcG9seWdsb3QudmVudHVy
    ...
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIGqzCCBJOgAwIBAgIUKMZCYZxHomZOUFLz8j0/ItBY/3cwDQYJKoZIhvcNAQEL
    BQAwgdwxKzApBgkqhkiG9w0BCQEWHGNlcnRtYXN0ZXJAcG9seWdsb3QudmVudHVy
    ...
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIGqzCCBJOgAwIBAgIUKMZCYZxHomZOUFLz8j0/ItBY/3cwDQYJKoZIhvcNAQEL
    BQAwgdwxKzApBgkqhkiG9w0BCQEWHGNlcnRtYXN0ZXJAcG9seWdsb3QudmVudHVy
    -----END CERTIFICATE-----
kind: ConfigMap
metadata:
  name: user-ca-bundle
  namespace: openshift-config
```

Once that ConfigMap is applied, you would modify the cluster's Proxy configuration and provide the `user-ca-bundle` ConfigMap name:

```yaml
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  name: cluster
spec:
  trustedCA:
    name: user-ca-bundle
```

***Warning!*** Don't apply that Proxy Cluster Config YAML to the cluster all willy nilly - access it with `oc edit proxy/cluster` or via the Web UI in **Administration > Cluster Settings > Configuration > Proxy > YAML**.

Once those two objects are available/modified, the whole cluster will reload as the Root CA bundle is generated with those additional Root CA Certificates.

From here the OpenShift cluster can automatically sync the build Root CA bundle in PEM format to an empty ConfigMap that has been given an annotation as such:

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: trusted-ca
  labels:
    config.openshift.io/inject-trusted-cabundle: 'true'
data: {}
```

Even though this ConfigMap is empty, once applied you'll find the `.data['ca-bundle.crt']` data automatically added and it will be kept synced as Root CAs are updated centrally in the `user-ca-bundle` ConfigMap in the `openshift-config` Namespace!

Keep in mind - this is just for automatic syncing of Root CA Bundles in PEM format.

***What about for automatic syncing of a Java Keystore embedded in a binaryData key in a ConfigMap?***

---

## Reflector

Reflector is a really fantastic project that can automatically sync ConfigMaps and Secrets across Namespaces in a Kubernetes cluster - the easiest way to deploy it is via Helm:

```bash
## Add emberstack repo 
helm repo add emberstack https://emberstack.github.io/helm-charts

## Update Helm repos
helm repo update

## Create a reflector project
oc new-project reflector

## Install the Helm chart
helm upgrade --install reflector emberstack/reflector --namespace reflector

## Add SCC to SA RBAC
oc adm policy add-scc-to-user privileged -z default -n reflector
oc adm policy add-scc-to-user privileged -z reflector -n reflector
```

Now that Reflector is installed, you can create a Namespace, something like `pki-resources` that holds those ConfigMaps centrally:

```bash
## Create a new Project
oc new-project pki-resources

## Create a ConfigMap YAML file for/from the PEM-encoded Root CA bundle
oc create configmap tls-ca-bundle-pem --from-file=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

## Create a ConfigMap YAML file for/from the Java Keystore
oc create configmap jks-ca-certs --from-file=/etc/pki/ca-trust/extracted/java/cacerts
```

With those ConfigMaps created in the `pki-resources` Namespace, all you need to do is annotate them to be mirrored into other Namespaces:

```bash
## Add annotations for enabling reflection
oc annotate configmap tls-ca-bundle-pem reflector.v1.k8s.emberstack.com/reflection-allowed="true"
oc annotate configmap jks-ca-certs reflector.v1.k8s.emberstack.com/reflection-allowed="true"

## Add annotations for allowed Namespaces, allowed Namespaces being all of them
oc annotate configmap tls-ca-bundle-pem reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=".*"
oc annotate configmap jks-ca-certs reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=".*"
  
## Add annotations for enabling auto reflection
oc annotate configmap tls-ca-bundle-pem reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true"
oc annotate configmap jks-ca-certs reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true"
```

You can read more about Reflector and its options here: https://github.com/emberstack/kubernetes-reflector

---

> Wait...what if we combined some of these options to make a MEGA option?!

---

## Fully Automatic Syncing and Injection of Custom Root CAs in OpenShift

---

If we put a few of these options together we can formulate a solution that has little to no impact on applications, container images, pipelines, or much of anything else while gaining automatic syncing of resources across the cluster with auto-injection of those Volumes and VolumeMounts where they are needed...to do so we'll leverage a combination of:

- OpenShift Cluster-wide Root CAs
- Reflector
- PodPreset Operator

Note that Reflector and the PodPreset Operator are community projects and not supported by Red Hat on OpenShift.

***First***, as demonstrated earlier in the [OpenShift Cluster-wide Root CAs](#openshift-cluster-wide-root-cas) section, add your Root CA in PEM format to the cluster which will automatically be baked and distributed to the nodes, consumed by cluster operators, and made available to be synced to an annotated ConfigMap.

***Next***, create a Namespace for the central store of PKI assets and create that annotated ConfigMap:

```bash
## Create a new project for PKI assets
oc new-project pki-resources

## Create a ConfigMap that will have the Root CA Bundle in PEM format synced to it
cat <<EOF | oc apply -f -
kind: ConfigMap
apiVersion: v1
metadata:
  name: trusted-ca
  labels:
    config.openshift.io/inject-trusted-cabundle: 'true'
data: {}
EOF
```

***Add*** the Java Keystore ConfigMap - this will need to be manually managed since the cluster doesn't sync a JKS like it does a PEM bundle:

```bash
## Assuming your Root CAs are part of the system root trust bundle...
oc create configmap jks-ca-certs --from-file=/etc/pki/ca-trust/extracted/java/cacerts
```

***Deploy*** [Reflector](#reflector) and the [PodPreset Operator](#4-podpreset-operator) as shown above - then, label the two ConfigMaps for reflection across all Namespaces:

```bash
## Add annotations for enabling reflection
oc annotate configmap trusted-ca reflector.v1.k8s.emberstack.com/reflection-allowed="true"
oc annotate configmap jks-ca-certs reflector.v1.k8s.emberstack.com/reflection-allowed="true"

## Add annotations for allowed Namespaces, allowed Namespaces being all of them
oc annotate configmap trusted-ca reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=".*"
oc annotate configmap jks-ca-certs reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=".*"
  
## Add annotations for enabling auto reflection
oc annotate configmap trusted-ca reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true"
oc annotate configmap jks-ca-certs reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true"
```

We should now have PEM and JKS ConfigMaps available in every Namespace, and the only thing we have to manage now is labeling workloads and using a PodPreset targeting those labels - the PodPreset needs to be deployed manually or via a pipeline to any Namespace that needs it.  Reflector only works with certain object types like Secrets and ConfigMaps.

To use the ConfigMaps as set above, the PodPreset would look like this:

```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: PodPreset
metadata:
  name: pki-volumes
spec:
  selector:
    matchLabels:
      inject-pki: "yes"
  volumeMounts:
    - mountPath: /etc/pki/ca-trust/extracted/pem
      name: trusted-ca
      readOnly: true
    - mountPath: /etc/pki/ca-trust/extracted/java
      name: jks-ca-certs
      readOnly: true
  volumes:
    - configMap:
        items:
          - key: ca-bundle.crt
            path: tls-ca-bundle.pem
        name: trusted-ca
      name: trusted-ca
    - configMap:
        items:
          - key: cacerts
            path: cacerts
        name: jks-ca-certs
      name: jks-ca-certs
```

Label the workloads you need with that `inject-pki: "yes"` selector and you're off to the races!  Something like this maybe:

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: pki-toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pki-toolbox
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: pki-toolbox
        inject-pki: "yes"
    spec:
      containers:
        - name: pki-toolbox
          image: 'quay.io/kenmoini/pki-toolbox:latest'
          command:
            - /bin/bash
            - '-c'
            - '--'
          args:
            - while true; do sleep 30; done;
```

With that combination we get:

- Root CA PEM Bundled by the Cluster, automatically synced to a ConfigMap in a central Namespace
- A Java Keystore in a central Namespace
- Automatic syncing of those ConfigMaps to other namespaces with Reflector
- Automatic injection of those namespaced ConfigMaps with a PodPreset

And otherwise just need to add or target a label applied to our workloads - few YAML edits if any, centrally distributed resources that are kept in sync, automatic injection of both Root CA PEM and JKS bundles into containers where needed across the cluster!

---

## Extra Notes

- Yes, you could do a lot of this with initContainers but that's super clunky
- If you’re using OpenShift BuildConfigs and Builds then you can inject a set of Root CAs that will be used at build time for pulling containers from remote registries.  More information can be found here: https://docs.openshift.com/container-platform/4.9/cicd/builds/setting-up-trusted-ca.html
- Traditionally you only have your Root CA Certificate stored in the bundle - client/server/user Certificates pass along any additional Intermediate CA Certs needed as a CA Bundle.  An example would be to validate a site’s Server Certificate that is signed by Let’s Encrypt - the ISRG Root X1 CA is provided in standard system root trusts, however if validating a Server Certificate generated by Let’s Encrypt the validation will fail unless the server passes the Let’s Encrypt R3 Intermediate CA as well to validate the entire chain.
- As of this writing there is no "simple" or "fully supported" way to do this since custom Root CAs are, well, custom modifications on what is supplied by the Kubernetes platform.
- If you want to play with the mounted/system Root CA Bundles inside a container on the cluster, you can use this [pki-toolbox-container](https://github.com/kenmoini/pki-toolbox-container) which has a number of tools installed to help you with that.
