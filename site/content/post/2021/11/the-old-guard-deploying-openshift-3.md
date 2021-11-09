---
title: "The Old Guard - Deploying OpenShift 3.11"
date: 2021-11-08T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/sno-at-the-edge.png
tags:
  - homelab
  - red hat
  - openshift
  - ocp
  - containers
  - kubernetes
  - hybrid
  - multi
  - cloud
  - libvirt
  - kvm
  - qemu
  - dns
  - advanced cluster security
  - stackrox
authors:
  - Ken Moini
---

> Do you ever ask yourself "Do I still got 'it'?"

It's been at least 2 blissful years since I've had to deploy OpenShift 3.11 - OpenShift 4 has been what most people have worked with but OpenShift 3.11 is technically still supported until Q2 of 2022, which means I still have customers using it of course...

OpenShift 4 has a lot of capabilities that are simply missing or not available in OpenShift 3.11 - the underlying platform, Kubernetes, has also gone through a number of changes between the versions used in both offerings.  This presents a challenge in some cases, such as service mapping - in OpenShift 4 this is pretty easy with a Service Mesh or Red Hat Advanced Cluster Security but in OpenShift 3.11 how do you find out how Services and their associated Deployments/Routes are composed?  This is where our journey begins as I build a Service Mapper for OpenShift 3.11.

The first thing needed is, well, an OpenShift 3.11 cluster, so let's start there...

## Planning the Installation

In case you're lucky enough to have never deployed OpenShift 3.11 before, there are a few things to consider:

- It runs on RHEL 7 or RHEL Atomic, not the RH CoreOS you may be used to in OCP 4
- It is deployed via a collection of fragile Ansible Playbooks that will most certainly break at some point in execution
- You need an active OpenShift subscription to deploy OCP 3.11 or else you won't be able to pull the RPMs/Containers

There are a league of other things to plan for which you can find in the [Planning Your Installation](https://docs.openshift.com/container-platform/3.11/install/index.html) and [System and Environment Requirements](https://docs.openshift.com/container-platform/3.11/install/prerequisites.html) section of the OpenShift documentation.

For the purposes of this deployment, we'll setup 3 HA Control Planes nodes and 3 Application nodes by doing the following:

- [Download RHEL 7.9](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.9/x86_64/product-software), perform a "Minimal" server installation
- Set DNS A Records for each node, the API endpoint, and Application Routes
- Prepare the hosts with basic subscriptions and packages

## Preparing the Installation

So first thing we need are some nodes to deploy this on - since not everyone has a bunch of NUCs or bare metal hosts laying around, we'll do this via VMs on Libvirt - here's the XML template I use for the nodes:

```bash
## Set some variables
CLUSTER_NAME="ocp3"
NODE_NAME="cp-1"
NODE_RAM="32768"
NODE_CPU_SOCKETS="1"
NODE_CPU_CORES="6"
NODE_DISK_SPACE="120"
NODE_DISK_PATH="/opt/vms/${CLUSTER_NAME}-${NODE_NAME}.qcow2"
RHEL_ISO_PATH="/opt/iso/rhel7.iso"
IFACE_MAC_ADDRESS="54:52:00:42:69:90"
IFACE_SOURCE_TYPE="bridge"
IFACE_SOURCE_NAME="containerLANbr0"
IFACE_SOURCE_MODEL="virtio"
IFACE_NAME="eth0"

## Template the XML
cat << EOF > ${CLUSTER_NAME}-${NODE_NAME}.xml
<domain type='kvm'>
  <name>${CLUSTER_NAME}-${NODE_NAME}</name>
  <genid/>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://fedoraproject.org/coreos/stable"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit='MiB'>${NODE_RAM}</memory>
  <currentMemory unit='MiB'>${NODE_RAM}</currentMemory>
  <vcpu placement='static'>$(expr $NODE_CPU_SOCKETS \* $NODE_CPU_CORES)</vcpu>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='x86_64' machine='pc-q35-rhel8.4.0'>hvm</type>
    <boot dev='hd'/>
    <boot dev='cdrom'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <kvm>
      <hidden state='on'/>
    </kvm>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='${NODE_CPU_SOCKETS}' dies='1' cores='${NODE_CPU_CORES}' threads='1'/>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>preserve</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none'/>
      <source file='${NODE_DISK_PATH}' index='2'/>
      <backingStore/>
      <target dev='vda' bus='virtio'/>
      <alias name='virtio-disk0'/>
      <address type='pci' domain='0x0000' bus='0x05' slot='0x00' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${RHEL_ISO_PATH}' index='1'/>
      <backingStore/>
      <target dev='sda' bus='sata'/>
      <readonly/>
      <alias name='sata0-0-0'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='scsi' index='0' model='virtio-scsi'>
      <alias name='scsi0'/>
      <address type='pci' domain='0x0000' bus='0x02' slot='0x00' function='0x0'/>
    </controller>
    <controller type='usb' index='0' model='qemu-xhci' ports='15'>
      <alias name='usb'/>
      <address type='pci' domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
    </controller>
    <controller type='sata' index='0'>
      <alias name='ide'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x1f' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pcie-root'>
      <alias name='pcie.0'/>
    </controller>
    <controller type='pci' index='1' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='1' port='0x10'/>
      <alias name='pci.1'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0' multifunction='on'/>
    </controller>
    <controller type='pci' index='2' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='2' port='0x11'/>
      <alias name='pci.2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x1'/>
    </controller>
    <controller type='pci' index='3' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='3' port='0x12'/>
      <alias name='pci.3'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x2'/>
    </controller>
    <controller type='pci' index='4' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='4' port='0x13'/>
      <alias name='pci.4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x3'/>
    </controller>
    <controller type='pci' index='5' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='5' port='0x14'/>
      <alias name='pci.5'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x4'/>
    </controller>
    <controller type='pci' index='6' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='6' port='0x15'/>
      <alias name='pci.6'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x5'/>
    </controller>
    <controller type='pci' index='7' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='7' port='0x16'/>
      <alias name='pci.7'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x6'/>
    </controller>
    <controller type='virtio-serial' index='0'>
      <alias name='virtio-serial0'/>
      <address type='pci' domain='0x0000' bus='0x04' slot='0x00' function='0x0'/>
    </controller>
    <interface type='bridge'>
      <mac address='${IFACE_MAC_ADDRESS}'/>
      <source ${IFACE_SOURCE_TYPE}='${IFACE_SOURCE_NAME}'/>
      <model type='${IFACE_SOURCE_MODEL}'/>
      <alias name='${IFACE_NAME}'/>
    </interface>
    <serial type='pty'>
      <target type='isa-serial' port='0'>
        <model name='isa-serial'/>
      </target>
      <alias name='serial0'/>
    </serial>
    <console type='pty' tty='/dev/pts/1'>
      <target type='serial' port='0'/>
      <alias name='serial0'/>
    </console>
    <input type='tablet' bus='usb'>
      <alias name='input0'/>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='ps2'>
      <alias name='input1'/>
    </input>
    <input type='keyboard' bus='ps2'>
      <alias name='input2'/>
    </input>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'/>
    <video>
      <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
      <alias name='video0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </video>
    <memballoon model='none'/>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
      <alias name='rng0'/>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </rng>
  </devices>
  <seclabel type='none'/>
</domain>
EOF
```

> If you're asking yourself "Is there a better way to do this?" - to which the answer would be "Yes there is."  Check out the Ansible Automation that handles this for me in my lab at scale: 

