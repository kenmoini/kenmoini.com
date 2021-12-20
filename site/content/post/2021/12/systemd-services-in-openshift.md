---
title: "SystemD Services in OpenShift 4"
date: 2021-12-20T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/systemd-machineconfig.png
tags:
  - open source
  - oss
  - openshift
  - red hat
  - containers
  - kubernetes
  - automation
  - systemd
  - services
  - ignition
  - machineconfig
  - nutanix
  - csi
  - iscsid
  - coreos
  - rhcos
  - fcos
authors:
  - Ken Moini
---

> Configuring SystemD with YAML makes me long for Bash

Evidently, if you deploy the Nutanix CSI Operator on Red Hat's OpenShift Container Platform the StorageClass can ***claim*** PVs and PVCs but when it comes to ***binding*** the storage to a running container you'll run into a very interesting error when viewing the Pod Events stream:

```text
MountVolume.SetUp failed for volume "pvc-a139d12a-036a-490c-bc2d-214e8da078e3" : rpc error: code = Internal desc = iscsi/lvm failure, last err seen: iscsi: failed to sendtargets to portal 192.168.42.58:3260 output: Failed to connect to bus: No data available iscsiadm: can not connect to iSCSI daemon (111)! iscsiadm: Cannot perform discovery. Initiatorname required. iscsiadm: Could not perform SendTargets discovery: could not connect to iscsid , err exit status 20
```

Basically, what that means is that the iSCSId service isn't running on the Red Hat CoreOS hosts.

---

***So what can you do to enable this service?***

You could SSH into each of the OCP Application nodes and do a `system enable --now iscsid.service` but the problem with that is that it is an unsupported anti-pattern and as soon as the system reboots or is reconfigured the service would be reset back to its normal state due to how the read-only composition of CoreOS works.

The best way to enable the needed SystemD service on all of the Application nodes would be with a **MachineConfig**.

---

A **MachineConfig** and the [Machine Config Operator](https://docs.openshift.com/container-platform/4.9/post_installation_configuration/machine-configuration-tasks.html) will allow you to set machine/node/RHCOS configuration as a traditional Kubernetes object.  Upon updating the state of a MachineConfig the operator will compose all the known configuration and apply it to the nodes, executing a rolling reboot to apply the updated configuration.

So this instance, when you need to simply add the MachineConfig to enable the iSCSId SystemD service all you need is something like this:

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-custom-enable-iscsid-worker
spec:
  config:
    ignition:
      version: 2.2.0
    systemd:
      units:
      - enabled: true
        name: iscsid.service
```

You don't need to specify that the service is started/stopped, just enabled - the nodes will reboot with the newly assembled configuration specifications so whatever state they have on start up is what is used.

This can easily be used to enable or disable other SystemD services as well with little effort.

Once the MachineConfig is applied to your OpenShift cluster you'll notice that the nodes will be cordoned off, which is a sort of taint that will disable scheduling of any new workloads on that node - then it will drain the node of any application workloads and reboot.  You can see this by running something like:

```bash
oc get nodes
```

...which would look something like this:

```text
NAME    STATUS                        ROLES    AGE   VERSION
app-1   Ready                         worker   12h   v1.22.3+4dd1b5a
app-2   Ready                         worker   12h   v1.22.3+4dd1b5a
app-3   NotReady,SchedulingDisabled   worker   12h   v1.22.3+4dd1b5a
...
```

The application nodes will transition between Ready/SchedulingDisabled, NotReady/SchedulingDisabled, Ready/SchedulingDisabled, and Ready states as they reboot to apply the new configuration.