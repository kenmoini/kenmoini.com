---
title: "Modify Disk Images with guestfish - 3 / 100 DoC"
date: 2021-01-05T21:02:47-05:00
draft: false
toc: false
aliases:
    - /blog/modify_disk_images_with_guestfish/
    - /blog/modify-disk-images-with-guestfish/
hero: /images/posts/heroes/modify-disk-guestfish.png
tags:
  - 100 days of code
  - 100doc
  - vmdk
  - qcow
  - iso
  - guestfish
  - guestfs
  - ibm cloud
authors:
  - Ken Moini
---


I swear I've been pumping out code, just cHeK mA gItHuB cOmMiTz!!!!1

The problem is writing about it - a lot of what I'm doing isn't so atomically reported...but when I find a nugget of goodness by golly I'll write about it!

> ***This such little nugget of goodness is called guestfish***

## The Problem & Why

I'm deploying OpenShift 4 to the IBM Cloud and that requires deploying *Red Hat CoreOS*, which uses a mechanism called *Ignition* for booting and configuration.  Cool, except you can't supply the Ignition file to the RHCOS instance because IBM Cloud has no way to pass custom machine data outside of cloud-init.

The solution?  Over-archtecting the deployment of course!

It's not too bad really...

1. Plan cluster, map VPC Address Prefix Space to Static IPs for nodes and Hostnames
2. Deploy VPC and base network resources
3. Deploy DNS Nodes (BIND), serve forward and reverse zones
4. Take the RHCOS Qcow image, bake it with some Grub boot kernel parameters to point to those DNS Nodes and have it look for Ignition files from an HTTP server located at `http://DNS_NODE_1/ignition_generator` 
5. Upload that customized Qcow to the IBM Cloud's Cloud Object Storage service for importing into a Custom Image for a Virtual Server Instance.
6. "Create a simple web application" to map IPs from booting RHCOS machines who request Ignition files, to a reverse DNS look up for the matching hostname and serve the required Ignition file.
7. ??????
8. PROFIT!!!!!1

***We're at step 4 in this story*** - the goal is to configure the RHCOS QEMU Qcow2 file with a bit of a first-boot config.  I already tested the vanilla Qcow2 image to boot in IBM Cloud as a Custom VSI so we just need to feed it a bit of an Ignition to get it going.

## Ignition Sources

There are a few ways to provide RHCOS an Ignition file:

1. As extra configuration via the Hypervisor, but this is not supported on every platform
2. Via an APPEND'd kernel argument during PXE boot
3. Supplying via CLI when booted off the live ISO

The actual Ignition file can be streamed to the machine or supplied via HTTP, FTP, or TFTP.

In this case, we're going to do something in between option 2 and 3 with a little tool called [guestfish](https://libguestfs.org/guestfish.1.html)

## Bake A Tasty Image

***Guestfish***, or guestfs, allows you to easily mount a VM image or disk image and modify it on the fly!  ***Note***: I needed to do these steps on my physical Fedora laptop, was not able to mount in a VM even with nested virtualization.

We'll take the [RHCOS QEMU QCow2 file](https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/) and configure the Grub boot kernel options, which will be used to pull the Ignition file from an HTTP source.

To do so, install Guestfish via your distribution's packaging manager something like `dnf install libguestfs-tools`

With that installed we can probably run the next set of commands:

```bash
wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-qemu.x86_64.qcow2.gz
gunzip rhcos-qemu.x86_64.qcow2.gz
guestfish -a rhcos-qemu.x64_64.qcow2
```

Now you should be presented with the `><fs>` shell prompt.  In the background guestfish uses libvirt to create a temporary machine domain in order to manipulate the image - don't worry, it's not booted or anything and and doesn't take much on the resource front.

At the `><fs>` shell run the following commands to start libvirt, display the available filesystems, and mount our target:

```text
><fs> launch
><fs> list-filesystems
/dev/sda1: ext4
/dev/sda2: vfat
/dev/sda3: unknown
><fs> mount /dev/sda1 /
><fs> ls /
boot
efi
grub2
ignition.firstboot
loader
loader.1
lost+found
ostree
><fs> vi /ignition.firstboot
```

So with that we:

1. Launched the libvirt engine
2. Listed the file systems, 3 were returned - we're interested in the first one
3. Mount `/dev/sda1` to `/` - this is in the scope of the image, not your host system
4. List the directory contents of the mounted `/`
5. Load `vi` and edit the `/ignition.firstboot` file

Now we need to load that file up with the desired arguements - my environment is multi-zoned with 3 DNS servers, with the first server also providing the Ignition Generation web app.  I set the Instances to have Static IPs in IBM Cloud and have RHCOS pull that assigned IP via DHCP.  With that, my `/ignition.firstboot` file looks like this:

```text
set ignition_network_kcmdline='rd.neednet=1 ip=dhcp nameserver=10.128.10.10 nameserver=10.128.20.10 nameserver=10.128.30.10 coreos.inst.ignition_url=http://10.128.10.10/ignition_generator'
```

This being `vi`, use the `i` key on your keyboard to enter `--INSERT--` mode, add those modifications, press `ESC` on your keyboard to exit `--INSERT--` mode, type `:wq` to write the file and quit.

You can now also run a `><fs> cat /ignition.firstboot` at the guestfish terminal to see your changes.

Next run `><fs> shutdown` and `><fs> exit` to save your changes to the image.

## Next steps

That's it!  Pretty easy to slipstream in extra files, configuration, all sorts of things to an image and now I can pass my Ignition files to the RHCOS nodes to deploy OpenShift in the IBM Cloud via custom pre-alpha UPI!  Guestfish to the rescue!