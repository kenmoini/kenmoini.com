---
title: "Using NVidia GPUs in OpenShift"
date: 2021-03-14T12:02:47-05:00
draft: false
toc: false
aliases:
    - /blog/using-nvidia-gpus-in-openshift/
hero: /images/posts/heroes/nvidia-gpus-openshift.png
tags:
  - openshift
  - containers
  - kubernetes
  - red hat
  - libvirt
  - kvm
  - nvidia
  - drivers
  - gpus
  - machine learning
  - artificial intelligence
  - pixel streaming
authors:
  - Ken Moini
---

> ***Part 4 of what is a small series in me figuring out all this Ray Tracing & Pixel Streaming from containers in OCP stuff...***

Now that I've tested my GPUs on my host system, it's time to pass them onto VMs for OpenShift!  Oddly enough, this makes things easier...

## 1. Provisioning your OpenShift Cluster with PCI Passthrough

Now you could go about this in a number of different ways and your ability or suggestion to do either depends on how you installed your OpenShift cluster - if you installed via traditional IPI or UPI then you can just add some additional Application Nodes to the cluster.  If you're like me and using Libvirt/KVM on a RHEL 8 host, and just spamming the ISO to some VMs via the Assisted Installer, then you'll need to assign the VMs at cluster creation.

This could all depend on your hypervisor as well, so it's outside of the scope of this document - something for Libvirt though would look like this:

```bash
virt-install --name=raza-ocp-app-3-m40 --vcpus ${AN_VCPUS} --memory=${AN_RAM} --cdrom=${OCP_AI_ISO_PATH} --disk size=120,path=${VM_PATH}/raza-ocp-app-3.qcow2 --os-variant=rhel8.3 --autostart --noautoconsole --events on_reboot=restart --host-device=pci_0000_41_00_0
virt-install --name=raza-ocp-app-2-quadro --vcpus ${AN_VCPUS} --memory=${AN_RAM} --cdrom=${OCP_AI_ISO_PATH} --disk size=120,path=${VM_PATH}/raza-ocp-app-2.qcow2 --os-variant=rhel8.3 --autostart --noautoconsole --events on_reboot=restart --host-device=pci_0000_81_00_0 --host-device=pci_0000_81_00_1 --host-device=pci_0000_81_00_2 --host-device=pci_0000_81_00_3
```

Note: This requires [IOMMU enabled in your BIOS and all that fun stuff](https://kenmoini.com/blog/pci-passthrough-with-libvirt/).

## 2. Subscribe Your OpenShift Cluster

By default all OpenShift cluster installs have a 60 day trial subscription and this will not work with the NVidia GPU Operator.

Use the Red Hat Cloud to subscribe your cluster.

## 3. Entitle the Cluster with the Red Hat Registry

Next is a super fucking round-about way of having to do things...but here goes...

1. Log into your Red Hat Customer Portal - navigate to Subscriptions > Systems.  Find a subscribed RHEL system.
2. In that System view, click on its Subscription tab - click "Download Certificates"
3. This will download a ZIP file - extract it.
4. In those extracted bits, you'll find another ZIP called `consumer_exports.zip` - extract that as well.
5. Now you'll find an `exports/entitlement_certificates` directory with a PEM file in there - this is what we want

Now we have to wrap that into a YAML file, assuming that PEM file is located at `123abc_certificates/export/entitlement_certificates/1234567890.pem`:

```bash
cp 123abc_certificates/export/entitlement_certificates/1234567890.pem rhsm.cert.pem

wget https://raw.githubusercontent.com/openshift-psap/blog-artifacts/master/how-to-use-entitled-builds-with-ubi/0003-cluster-wide-machineconfigs.yaml.template
sed  "s/BASE64_ENCODED_PEM_FILE/$(base64 -w 0 rhsm.cert.pem)/g" 0003-cluster-wide-machineconfigs.yaml.template > 0003-cluster-wide-machineconfigs.yaml

oc create -f 0003-cluster-wide-machineconfigs.yaml
```

With this containers on the OpenShift cluster can now use authenticated pull requests to the Red Hat Registry automatically.

## 4. Add the Node Feature Discovery Operator

The Node Feature Discovery Operator will go around and scan your nodes and add all sorts of fun labels to them!  The NVidia GPU Operator needs this to have the appropriate node labels for systems that have GPUs automatically applied to them.

From the Administrator view in OpenShift's Web UI, access **Operators > OperatorHub**.  Search for the **"Node Feature Discovery"** operator and install it.

Access the installed NFD Operator - create a **Node Feature Discovery instance**, the defaults are fine.

## 5. Create a Project for the NVidia GPU Operator

In OpenShift create a Project called `gpu-operator-resources` - you can do this via the Web UI or CLI with `oc new-project gpu-operator-resources`

## 6. Add the NVidia GPU Operator

Now we're ready to actually add the NVidia GPU Operator - you know where it is by now, OCP Web UI, Administrator view, **Operators > OperatorHub**.  Search for **"NVidia GPU"** and install the Operator.

Once the Operator is all installed and ready, access the installed NVidia GPU Operator.

Create a new **Cluster Policy instance** in the NVidia GPU Operator - the defaults are fine.

You can watch the resources spin up in the `gpu-operator-resources` Project.  The pods may fail a few times, but it should launch eventually.

## 7. Testing NVidia GPU Access in a Container

Once the Cluster Policy is Ready you can test the GPUs from within the Driver container.

In the `gpu-operator-resources` project, find one of the `nvidia-driver-daemonset-NNNN` Pods - click into it.

Click into the **Terminal** tab and run the command `nvidia-smi` to test, you should get something like this:

```
sh-4.4# nvidia-smi 
Sun Mar 14 06:44:39 2021       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.32.03    Driver Version: 460.32.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla M40           On   | 00000000:05:00.0 Off |                    0 |
| N/A   28C    P8    14W / 250W |      0MiB / 11448MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
sh-4.4#
```