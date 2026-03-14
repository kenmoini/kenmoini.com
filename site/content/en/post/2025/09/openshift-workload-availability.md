---
title: "OpenShift Virtualization Workload Availability"
date: 2025-09-22T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/workload-availability.png
photo_credit:
  title: Marin Tulard
  source: Pexels
tags:
  - openshift
  - red hat
  - kubernetes
  - containers
  - fence
  - fencing
  - agent
  - machine
  - node
  - nhc
  - far
  - snc
  - nho
  - nmo
  - medik8s
  - maintenance
  - healthcheck
  - operator
  - high availability
  - workload availability
  - virtualization
  - virtual machine
  - vm
  - live migration
  - failure
  - ha
authors:
  - Ken Moini
---

> Look at me, I am the documentation now

Kubernetes is know for magically floating your workloads around your nodes - it schedules things pretty well, with a lot of controls to do it.  Node goes bye bye?  No problem, your pods will *(hopefully)* be rescheduled.

When you run VMs in Kubernetes, there are a few tricks that are used that start to compete with the way Kubernetes does its scheduling thing.

So if you're running a VM in Kubernetes, and then the node it's running on happens upon a blown motherboard - the VM will just cease to function.

This applies for Kubernetes and KubeVirt, but also for OpenShift Virtualization - except OpenShift has a few tricks up its sleeve to make things not only easier but work really well for a variety of failure patterns.

## OpenShift Virtualization

In case you haven't heard, OpenShift is a container platform - that can also run Virtual Machines.  Crazy, I know.

To be fair - OpenShift Virtualization has been a thing since OpenShift 3.10, but it's come a long way in a short amount of time in terms of capabilities, integrations, and user friendliness.  The tech underneath is all KVM based so it works rather well - in use at some pretty big and important places with a lot of VMs.

OpenShift is built upon Kubernetes (and a billion other things), and so it has all the same controls for workload availability and placement you'd expect.  Replicas of course, {anti-}affinity rules, node selection, etc.  For VMs though, you don't get replicas - not really, VMs don't really work like Pods in that sense.

So while I won't get into all the controls you have for workload placement - I'll be focusing more on workload availability, in the context of OpenShift Virtualization.

## What is Workload Availability?

It's a big mux of Clustering and Consensus Mechanisms, Disaster Recovery, Fault Tolerance, High Availability, In and Out of Band Instrumentation, Maintenance, and Topology Management.  You know, all the really sexy things people like talking about.

So to that, I'll touch on a couple of scenarios that target (some of) those concerns:

- I need to put a node in maintenance mode and evict all the running workloads
- I need to automatically distribute my VMs around more evenly across nodes
- I need a node to recover in the case of a crash

In OpenShift, we solve this with a set of Operators:

- Node Maintenance Operator
- Kube Descheduler Operator
- Fence Agents Remediation Operator
- Node Healthcheck Operator
- Self Node Remediation Operator

There are a few other Workload Availability operators and [more details here](https://docs.redhat.com/en/documentation/workload_availability_for_red_hat_openshift/26.1/html/remediation_fencing_and_maintenance/about-remediation-fencing-maintenance).  These Operators build upon each other a lot, so we'll kind of progress through them in a (sorta) logical order.

---

## Node Maintenance Operator

Node Maintenance Operator is something that should be installed on pretty much every cluster - it gives you a nice way to click a button (or make some YAML) to put a Node in Maintenance Mode.  Then it will drain all the Pods and VMs.

To get started using the Node Maintenance Operator, just install it from the OperatorHub.  If you like to install Operators via Advanced Cluster Management, [here's a sample Policy to do so](https://github.com/kenmoini/lab-ocp/blob/main/rhacm/policies/operators-nmo.yaml).

That's it - pretty easy.  Once it's installed, you'll find "Start/Stop Maintenance" in the Actions menu of a Node.  It creates/deletes the NodeMaintenance CustomResource object and handles the cordoning/draining process.

While it may just give a simple interface - I'd say that's nice.  Easy button.  With NMO, we can also use it to lend capabilities combined with other WA Operators.

---

## Kube Descheduler Operator

The Kube Descheduler Operator is what people think of "Where's my DRS?" - except it's not really DRS in all the things DRS/SRM can do.

This Operator will take a look at your cluster every N seconds and capture the metrics of the running workloads distributed on the nodes.  When you have a node that's more subscribed than another, KDO will try to distribute the workloads to other nodes, rescheduling pods and live migrating VMs.

Before using the Descheduler, you need to enable Pressure Stall Information (PSI) metrics in the Linux Kernel - on OpenShift this is done with a MachineConfig that looks like this:

```yaml
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-kargs-psi
spec:
  kernelArguments:
  - psi=1
```

With that applied (and the nodes all having rebooted) we can move on to installing the Kube Descheduler Operator from the OperatorHub.

Once it's installed, we create a cluster-wide KubeDescheduler CR - mine looks like this and it works pretty well for OpenShift Virtualization clusters (but probably won't come this time next year...):

```yaml
---
apiVersion: operator.openshift.io/v1
kind: KubeDescheduler
metadata:
  name: cluster
  namespace: openshift-kube-descheduler-operator
spec:
  logLevel: Normal
  mode: Automatic
  operatorLogLevel: Normal
  managementState: Managed
  deschedulingIntervalSeconds: 30
  profiles:
    - KubeVirtRelieveAndMigrate
    - TopologyAndDuplicates
  profileCustomizations:
    devEnableSoftTainter: true
    devDeviationThresholds: AsymmetricLow
    devActualUtilizationProfile: PrometheusCPUCombined
    namespaces:
      excluded:
        - cpuload
        - multicluster-engine
        - open-cluster-management
        - open-cluster-management-agent
        - open-cluster-management-agent-addon
        - open-cluster-management-global-set
        - open-cluster-management-hub
        - open-cluster-management-policies
        - dedicated-admin
        - default
        - cert-manager
        - cert-manager-operator
        - default-broker
        - hive
        - kube-node-lease
        - local-cluster
        - hub-cluster
        - stackrox
        - rhacs-operator
```

Note the excluded namespace list - this is handy for things that you don't want the Descheduler to touch, like that `cpuload` Namespace.  Let's make it and another one:

```yaml
---
# Where we put some pods to make the CPUs go brrrrr
apiVersion: v1
kind: Namespace
metadata:
  name: cpuload
---
# Where we want to put a VM or two
apiVersion: v1
kind: Namespace
metadata:
  name: cpuload-vm
```

With that, make a VM in the `cpuload-vm` Namespace - give it some decent specs, start it up.

Once it's running, take note of the Node that it's running on - we're gonna need the name of the node it's on.

In the `cpuload` Namespace, we'll make a Deployment, scaled up a couple replicas, changing the nodeSelector so the Pods are running on that same node the VM is on:

```yaml
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: cpuload
  namespace: cpuload
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cpuload
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: cpuload
    spec:
      nodeSelector:
        # CHANGE ME TO THE NODE THE VM IS ON
        kubernetes.io/hostname: suki
      containers:
        - name: container
          image: 'quay.io/simonkrenger/cpuload:latest'
          resources:
            limits:
              cpu: '32'
              memory: 8Gi
            requests:
              cpu: '16'
              memory: 1Gi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
```

Might need to adjust the resource limits on that one for your node size.  With that Deployment running on the same node as your VM, you should see the VM migrate once that node sees enough pressure.

*Don't forget to scale it down when you're done testing!*

---

## Node Health Check Operator

The Node Health Check Operator should probably be installed before you get too far with FAR *(hehe)* or SNR.  The following operators rely on NHC to remediate the states of nodes in the cluster.

NHC implements a failure detection system that monitors node conditions. It does not have a built-in fencing or remediation system and so must be configured with an external system that provides these features. By default, it is configured to utilize the Self Node Remediation Operator but can also be used with the Fencing Agents Remediation Operator.

NHC takes a remediation Template, and when bad states are reported by the remediation Operator, it manages the actions for those nodes.

There's also something called the **Machine Health Check Operator** and the **Machine Deletion Remediation Operator**, but those are more so used for cloud-based clusters where Machines can be deleted and automatically replaced by the infrastructure provider.

---

## Fence Agents Remediation Operator

The Fence Agents Remediation Operator (FAR) uses fencing agents to check the status of a node with out-of-band interface and control the state of it in the cluster and physically.  I mean this to say, if your server crashes it can automatically boot it back up over Redfish.

There are a access.redhat.com/documentation/en-us/workload_availability_for_red_hat_openshift/25.8/html/remediation_fencing_and_maintenance/fence-agents-remediation-operator-remediate-nodes#supported-agents-fence-agents-remediation-operator_fence-agents-remediation-operator-remediate-nodes, since they were basically imported from the OpenStack world, from the classic `fence_redfish` to vendor specific ones, other mechanisms for integrating into private cloud platforms, etc.

Of course, install the FAR Operator - next we make some Credentials and Templates.

FAR will connect to something like Redfish, so you need network access and credentials.  If the credentials are the same then great, if not you can make per-node Secrets for authentication.

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: fence-agents-credentials-shared-sm-bmc
  namespace: openshift-workload-availability
type: Opaque
stringData:
  '--password': n0tPassword
  #'--username': ansible
  #'--ip': "{{.NodeName}}.mgmt.kemo.labs"
  #'--systems-uri': "/redfish/v1/Systems/1"
```

You can use the `{{.NodeName}}` as a template variable for the fencing agent config in the Secret too!

The keys coorespond to the parameters sent to the agent - so for Redfish you can find them here: https://manpages.debian.org/trixie/fence-agents-redfish/fence_redfish.8.en.html

These parameters can also be specified in the FenceAgentsRemediationTemplate CR:

```yaml
---
kind: FenceAgentsRemediationTemplate
apiVersion: fence-agents-remediation.medik8s.io/v1alpha1
metadata:
  name: famt-3node
  namespace: openshift-workload-availability
spec:
  template:
    spec:
      agent: fence_redfish
      remediationStrategy: OutOfServiceTaint
      retrycount: 5
      retryinterval: 5s
      sharedSecretName: fence-agents-credentials-shared-sm-bmc
      sharedparameters:
        '--systems-uri': "/redfish/v1/Systems/1"
        '--hostname': "{{.NodeName}}.mgmt.kemo.labs"
        '--action': reboot
        '--username': ansible
      timeout: 60s
```

Take note: this is just a `*RemediationTemplate`.  We still need a `*HealhCheck` controller to use it.  Since we're dealing with bare metal nodes that aren't comprised of an ACM/IPI NodePool/MachineSet, we'll use the **Node HealthCheck Operator**.

---

## Node Health Check Operator

With `*RemediationTemplate` CRs are used by some HealthCheck controller - there's the MachineHealthCheck and NodeHealthCheck.  MachineHealthCheck only works with MachineSets so think IPI/UPI.  We want NodeHealthCheck CRs so go ahead and install the Node HealthCheck Operator.

With it installed, we can create a NodeHealthCheck CR that uses our FenceAgentsRemediationTemplate:

```yaml
---
apiVersion: remediation.medik8s.io/v1alpha1
kind: NodeHealthCheck
metadata:
  name: nhc-far-3node
  namespace: openshift-workload-availability
spec:
  selector:
    matchExpressions:
      - key: node-role.kubernetes.io/master
        operator: Exists
  remediationTemplate: # Note: mutually exclusive with escalatingRemediations
    apiVersion: fence-agents-remediation.medik8s.io/v1alpha1
    kind: FenceAgentsRemediationTemplate
    namespace: openshift-workload-availability
    name: famt-3node
  minHealthy: 51%
  unhealthyConditions:
    - duration: 10s
      status: 'False'
      type: Ready
    - duration: 10s
      status: Unknown
      type: Ready
```

That configuration works well for a 3-node cluster.  With this now I can kill a node remotely over the BMC and in about a minute the workloads will be migrated and the node will be started back up over Redfish.  NHC will make a FenceAgentRemediation CR to track the process of the remediation actions.

Cool trick is to chain these things together - so you can put a node in Maintenance Mode with NMO, shut it down, then do some serving work, remove from Maintenance Mode, and FAR+NHC will boot the server up immediately.  *No need to push a button.*

---

## Self-Node Remediation Operator

The Self Node Remediation Operator runs on the cluster nodes and reboots nodes that are identified as unhealthy. The Operator uses the MachineHealthCheck or NodeHealthCheck controller to detect the health of a node in the cluster. When a node is identified as unhealthy, the MachineHealthCheck or the NodeHealthCheck resource creates the SelfNodeRemediation custom resource (CR), which triggers the Self Node Remediation Operator.

There's a great diagram on the upstream Medik8s site showing how SNR works: https://www.medik8s.io/remediation/self-node-remediation/how-it-works/

Essentially the nodes check themselves and each other - it's helpful for instances where BMCs aren't available, however it's not quite as responsive as FAR.

Not much to do to use SNR outside of installing the Operator and creating a NodeHealthCheck CR:

```yaml
---
apiVersion: remediation.medik8s.io/v1alpha1
kind: NodeHealthCheck
metadata:
  name: nhc-snr-3node
  namespace: openshift-workload-availability
spec:
  selector:
    matchExpressions:
      - key: node-role.kubernetes.io/master
        operator: Exists
  remediationTemplate: # Note: mutually exclusive with escalatingRemediations
    apiVersion: self-node-remediation.medik8s.io/v1alpha1
    kind: SelfNodeRemediationTemplate
    namespace: openshift-workload-availability
    name: self-node-remediation-automatic-strategy-template
  minHealthy: 51%
  unhealthyConditions:
    - duration: 10s
      status: 'False'
      type: Ready
    - duration: 10s
      status: Unknown
      type: Ready
```

You can optionally modify the `SelfNodeRemediationConfig` CR to dial in intervals and watchdog configuration, but the defaults usually work pretty well and changing them needs a guided hand.

---

That's about that - deploy a few Operators, set some configuration and apply some Secrets to talk to your BMCs, and you'll be able to float VMs and Pods over to healthy nodes when one fails!