---
title: "Disconnected Assisted Installer"
date: 2021-11-17T04:20:47-05:00
draft: true
publiclisting: true
toc: false
hero: /images/posts/heroes/disconnected-ai-svc.png
tags:
  - disconnected
  - assisted installer
  - openshift
  - ocp
  - private
  - self-hosted
  - privacy
  - open source
  - oss
  - homelab
  - containers
  - kubernetes
  - cloud
  - kubernetes
  - automation
authors:
  - Ken Moini
---

> Don't forget to lace up your sneaker(net)s

So today's exercise in the ever popular category of *"Yeah, sure, why not?"* we'll be exploring a popular topic and my favorite way of deploying OpenShift, BU be damned, the Assisted Installer!

But not just the Assisted Installer - how to deploy it as a self-hosted service in a disconnected environment.

## Architecture

So in case you're not familiar with it, the [Red Hat OpenShift Assisted Installer](https://console.redhat.com/openshift/assisted-installer/clusters) *(say that 3x fast...)* is an automated and API-driven approach to infrastructure agnostic OpenShift deployments - all you need is to cut some IPs, set up some DNS, and boot an ISO.  A few clicks later and you'll have a fancy OpenShift cluster in no time.

The primary tech-preview version of the service is hosted online, however we can host this ourselves in our own networks with little effort since it's a pretty standard 3-tier application.

To do so in a disconnected fashion is pretty much the same process as any OpenShift disconnected deployment - you gotta mirror some content and serve it via a container registry and HTTP server.  The only additional components and steps required really are what Assisted Installer imposes already - the back-end API service, front-end Web UI, and a PostgreSQL database.

### Public Replicator Node

The first set of processes we'll need are to mirror a few things - then save them to some sort of portable device and copied to the disconnected environment.

I'm going to assume that this public replicator node is a RHEL 8 system - you may need to adapt some installation steps for a different distribution base.

```bash
## Make copy folders
mkdir -p /opt/disconnected-mirror/{containers,packages}/

## Install needed packages
dnf install -y curl jq skopeo podman

## Download packages
cd /opt/disconnected-mirror/packages

## Download openshift-install
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-install-linux.tar.gz
## Download oc
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
## Download RH CoreOS
curl -O https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-live.x86_64.iso
curl -O https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-live-kernel-x86_64
curl -O https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-live-initramfs.x86_64.img
curl -O https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-live-rootfs.x86_64.img
```