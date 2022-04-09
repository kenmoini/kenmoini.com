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

So first thing we need are some nodes to deploy this on - since not everyone has a bunch of NUCs or bare metal hosts laying around, we'll do this via VMs on Libvirt.

```bash

```

> If you're asking yourself "Is there a better way to do this?" - to which the answer would be "Yes there is."  Check out the Ansible Automation that handles this for me in my lab at scale.
