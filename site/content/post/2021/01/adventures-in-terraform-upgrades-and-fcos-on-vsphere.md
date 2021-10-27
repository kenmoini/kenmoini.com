---
title: "Adventures in Terraform Upgrades and Deploying Fedora CoreOS to oVirt and VMWare vSphere - 2 / 100 DoC"
date: 2021-01-02T16:20:47-05:00
draft: false
toc: false
listed: true
aliases:
    - /blog/adventures-in-terraform-upgrades-and-fcos-on-vsphere/
hero: /images/posts/heroes/resized/resized-terraform-mars.png
excerpt:
tags:
  - 100 days of code
  - 100doc
  - terraform
  - hashicorp
  - infrastructure as code
  - IaC
  - github
  - vmware
  - vsphere
  - ovirt
  - automation
  - fedora
  - coreos
  - fcos
  - containers
  - kubernetes
authors:
  - Ken Moini
---

> ***Constant learning is required in technology - our current velocity means that you do something one day, come back 3 months later and those exact same steps fail in some spectacular way***

As I mentioned in my previous post, I'm building an automated Kubernetes cluster on Fedora CoreOS.  Now, this is being automated because I like being able to stand up clusters with the push of a button for unusual testing and in the usual case that I FUBAR a cluster.  To automate this, I'm using Terraform to do so but I'm admittedly starting to miss doing this in Ansible, even though there are similar pains there so don't get me started...

My dev/test environment is here at home in my lab, and production will be DigitalOcean, AWS, and GCP - naturally I start with dev/test.

In my lab I have a 3-node ***oVirt/Red Hat Virtualization*** cluster, and a server running ***VMWare vSphere 7*** - both resource pools have plenty of space available.  So naturally, I started with the HA oVirt cluster so I can do some physical-world tests of Kubernetes.

## Terraform: Minor versions, Major headaches

Now, I've written a bit of Terraform over the years, and feel comfortable with it, but it seems that my version 0.11 Terraform scripts would not work out-of-the-box on the version I had installed a few months back, version 0.12.

To make things better, there was a new version 0.14 out so of course I installed that and it's simple since it's just a Golang binary! woot!

If you're used to semantic software versionining, you'd not expect that a few jumps in minor versions to break things drastically, but they did with Terraform!

- Version 0.11 TF scripts aren't compatable with anything after it.
- Version 0.12 introduced some changes in how things were parsed, enjoy the debugging.
- There's a new workflow for Providers in version 0.13+ that involves Hashicorp's cloud registry of providers because, of course there is

{{< center >}}![Cool.  Cool cool cool cool.](/images/posts/legacyUnsorted/abedcool.gif){{</ center >}}

A few other quirks left some extra issues to work around but nothing an extra day or two of work didn't solve!

That is, until I hit a roadblock with the oVirt Terraform Provider - it doesn't work after Terraform v 0.12 due to how the Providers are now included during a `terraform init` :upside-down-face:

***So of course, I added another side-project, maintaining a fork of the terraform-provider-ovirt package that is compatable with the Terraform Provider Registry*** - it's still not done, and I'll come back and talk about that another time when it is.

Anywho, because I want a cluster now and not later, I've skipped deploying to oVirt via Terraform and switched to deploying to vSphere with Terraform which is just as fun as you'd imagine it is!  At least there's an official Hashicorp provider for vSphere...

*I'll come back to this post and update it with a link to a post dedicated to using Terraform + oVirt in the future...hopefully...*

## Deploying Fedora CoreOS to VMWare vSphere with Hashicorp Terraform

***This works with Terraform v0.14 and vSphere 7 using vCenter, loading Fedora CoreOS 33.***

The deployment method of this cluster will be very similar to how Red Hat's OpenShift does things - download the FCOS OVA locally, import the FCOS OVA to vSphere and create a template VM, create a bootstrap VM from that template VM to configure the rest of the cluster, which are also created via Terraform from that template VM.

I won't include the full script below for deploying ***ALL*** the cluster resources, that'd be a lot of scrolling...this is more of a crash-course in how to deploy to vSphere with Terraform.

#### You can find all the resources at this GitHub repository: [k8s-deployer on GitHub by Ken Moini](https://github.com/kenmoini/k8s-deployer/tree/main/infra_terraform/vsphere)

What we'll do is create a few files:

#### ***credentials.tf***

```terraform
variable "vsphere_user" {
  type    = string
  default = "administrator@vmware.example.com"
}
variable "vsphere_password" {
  type    = string
  default = "sup3rS3cr3t"
}
variable "vsphere_server" {
  type    = string
  default = "vcenter1.vmware.example.com"
}
```

Of course, substitute the needed credentials in that file to connect to your own vCenter instance.

#### ***version.tf***

```terraform
terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "1.24.3"
    }
  }
  required_version = ">= 0.12"
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}
```

The `version.tf` file should require no modification unless you want to verify SSL certificates.

#### ***variables.tf***

```terraform
variable "generationDir" {
  type    = string
  default = "./.generated"
}
variable "fcos_version" {
  type    = string
  default = "33.20201201.3.0"
}

#############################################################################
## VMWare Infrastructure Target Configuration

variable "vmware_datacenter" {
  type    = string
  default = "DC1"
}
variable "vmware_datastore" {
  type    = string
  default = "bigNVMe"
}
variable "vmware_cluster" {
  type    = string
  default = "CoreCluster"
}
variable "vmware_network" {
  type    = string
  default = "VM Network"
}
variable "vmware_ova_host" {
  type    = string
  default = "ESXIR620N42"
}

#############################################################################
## Cluster Details

variable "cluster_name" {
  type    = string
  default = "k8s-vmw"
}
variable "domain" {
  type    = string
  default = "example.labs"
}

#############################################################################
## Cluster VM Counts

variable "k8s_orchestrator_node_count" {
  type    = string
  default = "3"
}
variable "k8s_infra_node_count" {
  type    = string
  default = "3"
}
variable "k8s_app_node_count" {
  type    = string
  default = "3"
}

#############################################################################
## Template VM

variable "k8s_template_vm_disk_size" {
  type    = string
  default = "32"
}
variable "k8s_template_vm_memory_size" {
  type    = string
  default = "16384"
}
variable "k8s_template_vm_cpu_count" {
  type    = string
  default = "4"
}

#############################################################################
## Bootstrap VM Configuration

variable "k8s_bootstrap_disk_size" {
  type    = string
  default = "32"
}
variable "k8s_bootstrap_memory_size" {
  type    = string
  default = "16384"
}
variable "k8s_bootstrap_cpu_count" {
  type    = string
  default = "4"
}
#### Bootstrap VM - Network Options
variable "k8s_bootstrap_vm_network_config" {
  type = map(any)
  default = {
    type      = "static"
    ip        = "192.168.42.80"
    subnet    = "255.255.255.0"
    gateway   = "192.168.42.1"
    interface = "ens192"
    server_id = ""
  }
}

#############################################################################
## Orchestrator/Master Nodes Configuration

variable "k8s_orchestrator_cpu_count" {
  type    = string
  default = "4"
}
variable "k8s_orchestrator_memory_size" {
  type    = string
  default = "16384"
}
variable "k8s_orchestrator_disk_size" {
  type    = string
  default = "32"
}
#### Orchestrator/Master Nodes - Network Options
variable "k8s_orchestrator_network_config" {
  type = map(any)
  default = {
    orchestrator_0_type      = "static"
    orchestrator_0_ip        = "192.168.42.81"
    orchestrator_0_subnet    = "255.255.255.0"
    orchestrator_0_gateway   = "192.168.42.1"
    orchestrator_0_interface = "ens192"
    orchestrator_0_server_id = ""

    orchestrator_1_type      = "static"
    orchestrator_1_ip        = "192.168.42.82"
    orchestrator_1_subnet    = "255.255.255.0"
    orchestrator_1_gateway   = "192.168.42.1"
    orchestrator_1_interface = "ens192"
    orchestrator_1_server_id = ""

    orchestrator_2_type      = "static"
    orchestrator_2_ip        = "192.168.42.83"
    orchestrator_2_subnet    = "255.255.255.0"
    orchestrator_2_gateway   = "192.168.42.1"
    orchestrator_2_interface = "ens192"
    orchestrator_2_server_id = ""
  }
}
```

- You'll need to set some variables here in the `variables.tf` file - changing primarily the `vmware_` prefixed variables to match your your environment.
- The `cluster_name` and `domain` variables set things as far as FQDN bases, so your cluster API will be located at `api.cluster_name.domain:6443`
- Variables prefixed with `k8s_` describe Kubernetes cluster node composition, in this example how the Template, Bootstrap, and Orchestrator VMs are sized and configured.
- The `network_config` portion will generate Afterburn configuration to set either DHCP or Static IPs.  `_type` can be set to `dhcp|static`.  Not sure what `server_id` is but it's some `dracut` networking blah blah blah.
- With the `network_config` section for any GROUP of machines (orchestrator/infra/app), make sure to format it as `groupType_count.index_configKey` keeping in mind that the array starts at 0.  So if you were to have 5 Infrastructure nodes, the expected configuration key for the 4th node's IP would be `infra_node_3_ip`

#### ***global_data.tf***

```terraform
#############################################################################
## Gather data, need IDs
data "vsphere_datacenter" "dc" {
  name = var.vmware_datacenter
}
data "vsphere_datastore" "datastore" {
  name          = var.vmware_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_compute_cluster" "cluster" {
  name          = var.vmware_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          = var.vmware_network
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_host" "host" {
  name          = var.vmware_ova_host
  datacenter_id = data.vsphere_datacenter.dc.id
}
```

A cool thing about Terraform is you can chop up and organize your script in anyway you'd like - this file is used to separate global data sources that are expected at initialization.

### ***template/template_ignition.yaml***

```yaml
variant: fcos
version: 1.2.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ${ssh_public_key}
      home_dir: /home/core
      no_create_home: false
      groups:
        - wheel
      shell: /bin/bash
storage:
  files:
    - path: /etc/sysctl.d/20-silence-audit.conf
      contents:
        inline: |
          kernel.printk=4
    - path: /etc/hostname
      mode: 420
      contents:
        inline: "${cluster_name}-template"
```

This is the Ignition YAML template for the Template VM that is generated and passed to `fcct` - I won't paste in the YAML for the others since it pretty just just has a different hostname, or includes a `count` var.  You can find all the other Ignition YAML files on the Git repo linked above/below.

#### ***main.tf***

```terraform
#############################################################################
## Generate new cluster SSH Keys
resource "tls_private_key" "cluster_new_key" {
  algorithm = "RSA"
}
resource "local_file" "cluster_new_priv_file" {
  content         = tls_private_key.cluster_new_key.private_key_pem
  filename        = "${var.generationDir}/.${var.cluster_name}.${var.domain}/priv.pem"
  file_permission = "0600"
}
resource "local_file" "cluster_new_pub_file" {
  content  = tls_private_key.cluster_new_key.public_key_openssh
  filename = "${var.generationDir}/.${var.cluster_name}.${var.domain}/pub.key"
}

#############################################################################
## Setup Folder, Tag Category, and Tag(s)
resource "vsphere_tag_category" "category" {
  name        = "k8s-deployer-${var.cluster_name}"
  description = "Added by k8s-deployer do not remove"
  cardinality = "SINGLE"

  associable_types = [
    "VirtualMachine",
    "ResourcePool",
    "Folder",
    "com.vmware.content.Library",
    "com.vmware.content.library.item"
  ]
}
resource "vsphere_tag" "tag" {
  name        = var.cluster_name
  category_id = vsphere_tag_category.category.id
  description = "Added by k8s-deployer do not remove"
}
resource "vsphere_folder" "vm_folder" {
  path          = "k8s-deployer-${var.cluster_name}-vms"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
  tags          = [vsphere_tag.tag.id]
}

#############################################################################
## Create template VM from OVA

data "template_file" "template_vm_ignition_init" {
  template = file("./templates/template_ignition.yaml")
  vars = {
    cluster_name   = var.cluster_name
    ssh_public_key = tls_private_key.cluster_new_key.public_key_openssh
  }
}
resource "local_file" "template_vm_ignition_file" {
  depends_on = [data.template_file.template_vm_ignition_init]
  content    = data.template_file.template_vm_ignition_init.rendered
  filename   = "${var.generationDir}/.${var.cluster_name}.${var.domain}/template_vm-ignition.yaml"
}
resource "null_resource" "template_vm_ignition_init_fcct" {
  depends_on = [local_file.template_vm_ignition_file]
  provisioner "local-exec" {
    command = "fcct -o ${var.generationDir}/.${var.cluster_name}.${var.domain}/template_vm-ignition.ign ${var.generationDir}/.${var.cluster_name}.${var.domain}/template_vm-ignition.yaml"
  }
}
data "local_file" "template_vm_ignition_init_fcct" {
  filename   = "${var.generationDir}/.${var.cluster_name}.${var.domain}/template_vm-ignition.ign"
  depends_on = [null_resource.template_vm_ignition_init_fcct]
}
resource "vsphere_virtual_machine" "templateVM" {
  depends_on       = [data.local_file.template_vm_ignition_init_fcct]
  tags             = [vsphere_tag.tag.id]
  folder           = vsphere_folder.vm_folder.path
  name             = "${var.cluster_name}-template"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datacenter_id    = data.vsphere_datacenter.dc.id
  datastore_id     = data.vsphere_datastore.datastore.id
  host_system_id   = data.vsphere_host.host.id

  num_cpus         = var.k8s_template_vm_cpu_count
  memory           = var.k8s_template_vm_memory_size
  guest_id         = "coreos64Guest"
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_ip_timeout   = 0
  wait_for_guest_net_routable = false

  ovf_deploy {
    local_ovf_path       = "/tmp/.k8s-deployer/cache/fedora-coreos-${var.fcos_version}-vmware.x86_64.ova"
    disk_provisioning    = "thin"
    ip_protocol          = "IPV4"
    ip_allocation_policy = "STATIC_MANUAL"
    ovf_network_map = {
      "vmxnet3" = data.vsphere_network.network.id
    }
  }

  extra_config = {
    "guestinfo.ignition.config.data"          = base64encode(data.local_file.template_vm_ignition_init_fcct.content)
    "guestinfo.ignition.config.data.encoding" = "base64"
    "guestinfo.hostname"                      = "${var.cluster_name}-template"
  }

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  ## This template VM needs to be shutdown before being cloned to another VM
  provisioner "local-exec" {
    command = "govc vm.power -off=true ${var.cluster_name}-template && sleep 10"

    environment = {
      GOVC_URL      = var.vsphere_server
      GOVC_USERNAME = var.vsphere_user
      GOVC_PASSWORD = var.vsphere_password

      GOVC_INSECURE = "true"
    }
  }
}

#############################################################################
## Create Bootstrap node

data "template_file" "bootstrap_vm_ignition_init" {
  template = file("./templates/bootstrap_ignition.yaml")
  vars = {
    cluster_name   = var.cluster_name
    ssh_public_key = tls_private_key.cluster_new_key.public_key_openssh
  }
}
resource "local_file" "bootstrap_vm_ignition_file" {
  depends_on = [data.template_file.bootstrap_vm_ignition_init]
  content    = data.template_file.bootstrap_vm_ignition_init.rendered
  filename   = "${var.generationDir}/.${var.cluster_name}.${var.domain}/bootstrap_vm-ignition.yaml"
}
resource "null_resource" "bootstrap_vm_ignition_init_fcct" {
  depends_on = [local_file.bootstrap_vm_ignition_file]
  provisioner "local-exec" {
    command = "fcct -o ${var.generationDir}/.${var.cluster_name}.${var.domain}/bootstrap_vm-ignition.ign ${var.generationDir}/.${var.cluster_name}.${var.domain}/bootstrap_vm-ignition.yaml"
  }
}
data "local_file" "bootstrap_vm_ignition_init_fcct" {
  filename   = "${var.generationDir}/.${var.cluster_name}.${var.domain}/bootstrap_vm-ignition.ign"
  depends_on = [null_resource.bootstrap_vm_ignition_init_fcct]
}
data "vsphere_virtual_machine" "templateVM" {
  depends_on    = [vsphere_virtual_machine.templateVM]
  name          = "${var.cluster_name}-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}
resource "vsphere_virtual_machine" "bootstrapVM" {
  depends_on       = [data.vsphere_virtual_machine.templateVM]
  name             = "${var.cluster_name}-bootstrap"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus         = var.k8s_bootstrap_cpu_count
  memory           = var.k8s_bootstrap_memory_size
  guest_id         = "coreos64Guest"
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_net_routable = false

  scsi_type = data.vsphere_virtual_machine.templateVM.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.templateVM.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.k8s_bootstrap_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.templateVM.disks.0.eagerly_scrub
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.templateVM.id
  }

  extra_config = {
    "guestinfo.ignition.config.data"           = base64encode(data.local_file.bootstrap_vm_ignition_init_fcct.content)
    "guestinfo.ignition.config.data.encoding"  = "base64"
    "guestinfo.hostname"                       = "${var.cluster_name}-bootstrap"
    "guestinfo.afterburn.initrd.network-kargs" = lookup(var.k8s_bootstrap_vm_network_config, "type") != "dhcp" ? "ip=${lookup(var.k8s_bootstrap_vm_network_config, "ip")}:${lookup(var.k8s_bootstrap_vm_network_config, "server_id")}:${lookup(var.k8s_bootstrap_vm_network_config, "gateway")}:${lookup(var.k8s_bootstrap_vm_network_config, "subnet")}:${var.cluster_name}-bootstrap:${lookup(var.k8s_bootstrap_vm_network_config, "interface")}:off" : "ip=::::${var.cluster_name}-bootstrap:ens192:on"
  }
  tags   = [vsphere_tag.tag.id]
  folder = vsphere_folder.vm_folder.path
}

#############################################################################
## Create Orchestrator Nodes

data "template_file" "orchestrator_vm_ignition_init" {
  template = file("./templates/orchestrator_ignition.yaml")
  count    = var.k8s_orchestrator_node_count
  vars = {
    count          = count.index
    cluster_name   = var.cluster_name
    ssh_public_key = tls_private_key.cluster_new_key.public_key_openssh
  }
}
resource "local_file" "orchestrator_vm_ignition_file" {
  depends_on = [data.template_file.orchestrator_vm_ignition_init]
  count      = var.k8s_orchestrator_node_count
  content    = element(data.template_file.orchestrator_vm_ignition_init.*.rendered, count.index)
  filename   = "${var.generationDir}/.${var.cluster_name}.${var.domain}/orchestrator_vm_${count.index}-ignition.yaml"
}
resource "null_resource" "orchestrator_vm_ignition_init_fcct" {
  depends_on = [local_file.orchestrator_vm_ignition_file]
  count      = var.k8s_orchestrator_node_count
  provisioner "local-exec" {
    command = "fcct -o ${var.generationDir}/.${var.cluster_name}.${var.domain}/orchestrator_vm_${count.index}-ignition.ign ${var.generationDir}/.${var.cluster_name}.${var.domain}/orchestrator_vm_${count.index}-ignition.yaml"
  }
}
data "local_file" "orchestrator_vm_ignition_init_fcct" {
  count      = var.k8s_orchestrator_node_count
  depends_on = [null_resource.orchestrator_vm_ignition_init_fcct]
  filename   = "${var.generationDir}/.${var.cluster_name}.${var.domain}/orchestrator_vm_${count.index}-ignition.ign"
}
resource "vsphere_virtual_machine" "orchestratorVMs" {
  depends_on = [data.vsphere_virtual_machine.templateVM, data.local_file.orchestrator_vm_ignition_init_fcct]
  count      = var.k8s_orchestrator_node_count

  name             = "${var.cluster_name}-orch-${count.index}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus         = var.k8s_orchestrator_cpu_count
  memory           = var.k8s_orchestrator_memory_size
  guest_id         = "coreos64Guest"
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = 0
  wait_for_guest_net_routable = false

  scsi_type = data.vsphere_virtual_machine.templateVM.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.templateVM.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.k8s_orchestrator_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.templateVM.disks.0.eagerly_scrub
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.templateVM.id
  }

  extra_config = {
    "guestinfo.ignition.config.data"           = base64encode(element(data.local_file.orchestrator_vm_ignition_init_fcct.*.content, count.index))
    "guestinfo.ignition.config.data.encoding"  = "base64"
    "guestinfo.hostname"                       = "${var.cluster_name}-orch-${count.index}"
    "guestinfo.afterburn.initrd.network-kargs" = lookup(var.k8s_orchestrator_network_config, "orchestrator_${count.index}_type") != "dhcp" ? "ip=${lookup(var.k8s_orchestrator_network_config, "orchestrator_${count.index}_ip")}:${lookup(var.k8s_orchestrator_network_config, "orchestrator_${count.index}_server_id")}:${lookup(var.k8s_orchestrator_network_config, "orchestrator_${count.index}_gateway")}:${lookup(var.k8s_orchestrator_network_config, "orchestrator_${count.index}_subnet")}:${var.cluster_name}-orch-${count.index}:${lookup(var.k8s_orchestrator_network_config, "orchestrator_${count.index}_interface")}:off" : "ip=::::${var.cluster_name}-orch-${count.index}:ens192:on"
  }
  tags   = [vsphere_tag.tag.id]
  folder = vsphere_folder.vm_folder.path
}
```

This is where the rubber meets the road, we compose the infrastructure and set up a few things like:

1. Creating a new SSH key for this cluster, stored in the `./.generated` directory - you could optionally switch it out for a function that reads an existing SSH key
2. Creating a VM Folder, Tag Category, and Tag to organize things in vSphere
4. Deploying the FCOS OVA to a new VM Template
    1. Templating out the Ignition Configuration YAML
    2. Creating a local YAML file with that rendered template
    3. Using a `null_resource` object to run the `fcct` command which converts that saved YAML file into an Ignition file
    4. Reads in that converted Ignition file
    5. Deploys the OVA, passing the Ignition file contents as base64 encoded extra_config data - this VM is never really on so we don't really need to provide it with an active network.
5. Deploying the Bootstrap VM from the VM Template just created
    1. Repeat previous steps in generating Ignition configuration
    2. Clone the Bootstrap VM from that VM template - note the additional `guestinfo.afterburn` configuration - this sets the network configuration for the Bootstrap node.
6. Deploy the Control Plane/Orchestrator Nodes, also from the VM Template
    1. In this set of blocks, we add a `count` and change some references to target elements in an object that houses the N number of orchestrator nodes' configuration
    2. Keep in mind that your network configuration in the `variables.tf` file has to align with the count of Orchestrator nodes, this `vsphere_virtual_machine` resource expects those values available in the map.

Now before we go `terraform apply`'ing all over the place, let's tap out a few supplimentary scripts that will help glue things together...

#### ***vars.sh***

```bash
#!/bin/bash

FCOS_VERSION="33.20201201.3.0"

## DO NOT EDIT PAST THIS LINE!

export TF_VAR_fcos_version=$FCOS_VERSION
```

A simple vars file, this sets FCOS version to download that is then passed to the next script which downloads the OVA, and an export set to override the value in the executed Terraform plan.

#### ***scripts/pull-assets.sh***

```bash
#!/bin/bash

FCOS_VERSION=${1}

mkdir -p /tmp/.k8s-deployer/cache/

if [ ! -f /tmp/.k8s-deployer/cache/fedora-coreos-${FCOS_VERSION}-vmware.x86_64.ova ]; then
  curl -L -o /tmp/.k8s-deployer/cache/fedora-coreos-${FCOS_VERSION}-vmware.x86_64.ova https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/${FCOS_VERSION}/x86_64/fedora-coreos-${FCOS_VERSION}-vmware.x86_64.ova
fi
```

All this file does is pull in the FCOS OVA to a local cache so it's not downloaded every time this is run.  It's trigger by this next script...

#### ***deploy.sh***

```bash
#!/bin/bash

## set -x	## Uncomment for debugging

## Include vars if the file exists
FILE=./vars.sh
if [ -f "$FILE" ]; then
    source ./vars.sh
else
    exit "Need to generate variable file first"
fi

## Functions
function checkForProgram() {
    command -v $1
    if [[ $? -eq 0 ]]; then
        printf '%-72s %-7s\n' $1 "PASSED!";
    else
        printf '%-72s %-7s\n' $1 "FAILED!";
    fi
}
function checkForProgramAndExit() {
    command -v $1
    if [[ $? -eq 0 ]]; then
        printf '%-72s %-7s\n' $1 "PASSED!";
    else
        printf '%-72s %-7s\n' $1 "FAILED!";
        exit 1
    fi
}

## Check needed binaries are installed
checkForProgramAndExit curl
checkForProgramAndExit terraform
checkForProgramAndExit govc
checkForProgramAndExit fcct

## Pull assets
. ./scripts/pull-assets.sh $FCOS_VERSION

## Initialize Terraform
terraform init

## Do an initial plan as a test
terraform plan

if [[ $? -eq 0 ]]; then
  echo ""
  echo "============================================================================"
  echo " READY!!!"
  echo "============================================================================"
  echo ""
  echo "Next, just run 'terraform apply' to deploy the cluster"
  echo ""
else
  echo ""
  echo "============================================================================"
  echo " FAILED!!!"
  echo "============================================================================"
  echo ""
  echo "There seem to be issues with planning out the terraform deployment"
  echo ""
fi
```

A simple bootstrapping script, checks to make sure everything we need is there on the host that will be applying the Terraform plans.

1. Pulls in the `vars.sh` file so we can share the FCOS version var
2. Defines a few helper functions
3. Checks for the existence of a few programs and quits if not found - `curl` pulls the OVA, `terraform` is well, you know...since Terraform has no way to handle power state of VMs `govc` is used to shutdown the Template VM so the Bootstrap VM can be cloned from it.  Of course, since these are Fedora CoreOS systems, we need the `fcct` binary available so that we can create the Ignition configuration
4. Executes the `scripts/pull-assets.sh` script to cache the FCOS OVA locally
5. Intializes Terraform so that it can pull in a fresh set of providers, ensure we have everything needed
6. Runs a preflight check with `terraform plan` to ensure we have everything in place and connections process properly
7. Echos the next step for the user

## Putting It All Together

Just a few scripts to have automated deployment of Fedora CoreOS on VMWare with Terraform - what are we going to do with all of them again?

1. Create a directory, stuff those scripts in them (or fork/clone from my repo, navigate to the `infra_terraform/vsphere` directory)
2. Make sure to make the bash scripts executable: `chmod +x deploy.sh && chmod +x scripts/pull-assets.sh`
3. Ensure the `credentials.tf` file matches what you need to connect to your vSphere environment
4. Modify `variables.tf` to suit your needs and environment
5. Download a copy of `fcct` from the GitHub releases: https://github.com/coreos/fcct/releases/latest , eg, `sudo curl -o /usr/local/bin/fcct https://github.com/coreos/fcct/releases/download/v0.8.0/fcct-x86_64-unknown-linux-gnu && sudo chmod +x /usr/loca/bin/fcct`
6. Download a copy of `govc` from their GitHub release: https://github.com/vmware/govmomi/releases , eg, `wget https://github.com/vmware/govmomi/releases/download/v0.24.0/govc_linux_amd64.gz && gunzip govc_linux_amd64.gz && chmod +x govc_linux_amd64 && sudo mv govc_linux_amd64 /usr/local/bin/govc`
7. Run `./deploy.sh`
8. Run `terraform apply` - Answer `yes` and watch it all deploy!

That's about it - Sit back and watch all the action go down in vCenter!

{{< center >}}![abracadabra dude](/images/posts/legacyUnsorted/abracadabra.gif){{</ center >}}

The full source on GitHub has all the other nodes and additional automation available for the deployment of the rest of the Kubernetes cluster, but for the scope of this text this should be plenty to get most anyone up to speed on how to use Terraform to deploy to vSphere.

#### You can find all the resources at this GitHub repository: [k8s-deployer on GitHub by Ken Moini](https://github.com/kenmoini/k8s-deployer/tree/main/infra_terraform/vsphere)

Happy automating!
