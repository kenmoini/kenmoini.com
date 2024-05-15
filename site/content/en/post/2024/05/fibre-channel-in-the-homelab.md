---
title: "Fibre Channel in the Homelab"
date: 2024-05-15T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/fc-homelab.png
photo_credit:
  title: Pexels
  source: https://www.pexels.com/photo/cables-connected-on-server-2881229/
tags:
  - open source
  - oss
  - homelab
  - red hat
  - rhel
  - fedora
  - fc
  - fibre channel
  - storage
  - qlogic
  - lun
  - targetcli
authors:
  - Ken Moini
---

> r/datahoarders is calling

---

Homelabs can be a fun intersection between enterprise-grade hardware/software and that corner of your den.  For some people like me it helps with learning technology that I normally don't have access to - *especially since I got banned from the last data center I was in.*

I use my homelab to run some basic services that are common like Plex-n-Pals, and otherwise to help do my job more effectively - I need to know how these systems work in order to best guide my clients.  I thought I had a pretty robust environment until recently.

Thanks to all the issues that Broadcom have created for their customer base, I've been having a lot of virtualization conversations lately.  [Broadcom's strategy](https://www.theregister.com/2022/05/30/broadcom_strategy_vmware_customer_impact/) is to basically focus on sapping their top accounts dry, and screw everyone else with a "what are they gonna do, migrate?" sort of attitude.

My lab has serviced these virtualization conversations by and large with the various Dell rack servers and AMD EPYC towers that I have, but recently I've run into a common pattern that I couldn't emulate: lack of available disks for installation of a hypervisor such as OpenShift Virtualization.  This is where currently people boot ESXi off an SD Card in their servers and have the storage backend for VMs provisioned by their SAN over Fibre Channel connections.

The problem in really using Fibre Channel in my lab is that FC switches are LOUD - and HOT - and take a good deal of power that my two 20A circuits don't have the capacity for.  I might still get a couple FC switches to do some proper multipath testing, but for now I've landed with direct attached FC from one server to another.

Which is what this article is all about - **how to turn a server into a FC target and consume storage on a client initiator.**

This is based on some adaptation of [this 2013 blog article](https://acksyn.org/posts/2013/05/building-your-own-san-with-linux/) and guidance from a *homelab homie* [Andrew Austin](https://github.com/marbindrakon).

---

## Needed Hardware

First thing that's needed is are some FC Host Bus Adapters.  Many different kinds will work, I personally just went with some QLogic cards since they're pretty standard and supported in most systems.  I went with a QLogic QLE2694 card for the target server and some QLogic QLE2690 cards in my initator systems, though I'll be upgrading to some QLE2692 cards here soon.  I went with the Dell branded versions since according to their docs they support Target Mode and Bootable LUNs.

With the cards you'll need some transceiver SFP optics on each side of things.  Sticking to the QLogic brand, I grabbed a few QLogic FTLF8529P4BCV-QL transceivers - the key parts of the spec are 16G SFP+, LC, pushing 850nm wavelengths.

All that's left are some fibre cables to connect everything.  Based on the [manual of the QLogic cards](https://www.marvell.com/content/dam/marvell/en/public-collateral/fibre-channel/marvell-fibre-channel-adapters-qlogic-qle2694-qle2694l-product-brief.pdf) it supports a variety of cables and optics.  Since I'm using 16G optics I have the option of OM2, OM3, or OM4 cables depending on what sort of distance I want.  Personally I went with the middle choice and picked up some 3 meter OM3 Multi-Mode LC to LC cables.

Once all the hardware arrived from a couple eBay purchases I simply plugged in the PCIe cards, inserted the transceiver modules, and plugged in the cables - pretty straightforward there.  You may notice that the lights are just pulsing in order, this is because they're not active yet and that is normal.

---

## System Software Setup

Next up was setting up some software needed to run an FC target, or what some would think of as the storage server.

I originally wanted to run this on a system that had RHEL installed, however I found out that the ability to disable initiator mode on these cards [was removed in RHEL 8+](https://bugzilla.redhat.com/show_bug.cgi?id=1666377).  To that end I reinstalled with Fedora Server 39 and had no problems moving forward.

There are only two packages needed to install, and from there you just set some kernel module configuration and make it persistent:

```bash
# Install needed packages
dnf install targetcli sysfsutils

# Disable initiator mode
echo 'options qla2xxx qlini_mode="disabled"' > /usr/lib/modprobe.d/qla2xxx.conf
rmmod qla2xxx
modprobe qla2xxx

# Rebuild initramfs
dracut -f

# Rebuild GRUB config
# On BIOS-based machines:
grub2-mkconfig -o /boot/grub2/grub.cfg
# On UEFI-based machines:
grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg

# Reboot
systemctl reboot
```

You can run `systool -c fc_host -v` to get information about the HBA and the status of the ports - again, at this point you should see "Linkdown" for all the port_state on that card.  The next step is to enable them.

---

## Target Configuration

Now that the host has initiator mode disabled we can configure it to operate as a storage target.  This is done via the `targetcli` tool, which provides its own sub-shell prompt.  First we'll get the information about the detected HBA and enable the ports listed.

```bash
# Start the targetcli shell
targetcli

targetcli shell version 2.1.58
Copyright 2011-2013 by Datera, Inc and others.
For help on commands, type 'help'.

/> qla2xxx/ info
Fabric module name: qla2xxx
ConfigFS path: /sys/kernel/config/target/qla2xxx
Allowed WWN types: naa
Allowed WWNs list: naa.21000024ff8698b3, naa.21000024ff8698b0, naa.21000024ff8698b2, naa.21000024ff8698b1
Fabric module features: acls
Corresponding kernel module: tcm_qla2xxx
```

The "Allowed WWNs list" corresponds to the ports available on the HBA(s) in the system, in this case as a path in the "qla2xxx" tree.  If you're running other HBAs or want to see what is available you can run an `ls` in the targetcli shell to see the various paths.

With the WWNs listed, we'll "create" or enable those ports with the following:

```
/> qla2xxx/ create naa.21000024ff8698b0
Created target naa.21000024ff8698b0.
/> qla2xxx/ create naa.21000024ff8698b1
Created target naa.21000024ff8698b1.
/> qla2xxx/ create naa.21000024ff8698b2
Created target naa.21000024ff8698b2.
/> qla2xxx/ create naa.21000024ff8698b3
Created target naa.21000024ff8698b3.

/> exit
```

At this point you can re-run the `systool -c fc_host -v` command and you should be able to see any connected port port_state change to "Online".

---

## Creating Storage Blocks

Before we connect these ports to defined LUNs we'll need to create some storage devices for them to use.  This could be whole disks directly, but in my case I've used LVM to carve out parts of an NVMe disk for different LUNs on different ports.  In the following example I'm creating a block device for each HBA port to be used as an exposed LUN.

Now, you could go through the whole LVM via the CLI thing and it'd probably look something like this:

```bash
# Create a physical volume
pvcreate /dev/nvme0n1

# Create a volume group
vgcreate vgroup0 /dev/nvme0n1

# Create a logical volume - or few
lvcreate -n p1_lvol0 -L 120G vgroup0
lvcreate -n p2_lvol0 -L 120G vgroup0
lvcreate -n p3_lvol0 -L 120G vgroup0
lvcreate -n p4_lvol0 -L 120G vgroup0
```

Personally I just created it via the Cockpit Storage Web UI - *I'm a big fan of the clicky-clicky stuff.*

---

## Mapping Blocks to LUNs

Now that we have a few LVM blocks create, we can make them available on the different ports and expose them as LUNs to different initiators.  To do this, enter the `targetcli` shell again on the target storage host.  First we'll create some block backstores:

```bash
/> backstores/block create lun0 /dev/vgroup0/p1_lvol0
Created block storage object lun0 using /dev/vgroup0/p1_lvol0.

/> backstores/block create lun1 /dev/vgroup0/p2_lvol0
Created block storage object lun1 using /dev/vgroup0/p2_lvol0.

/> backstores/block create lun2 /dev/vgroup0/p3_lvol0
Created block storage object lun2 using /dev/vgroup0/p3_lvol0.

/> backstores/block create lun3 /dev/vgroup0/p1_lvol0
Created block storage object lun3 using /dev/vgroup0/p4_lvol0.
```

With the backstore blocks defined, we now map them to specific port WWNs:

```bash
/> qla2xxx/naa.21000024ff8698b0/luns create /backstores/block/lun0 
Created LUN 0.
/> qla2xxx/naa.21000024ff8698b1/luns create /backstores/block/lun1
Created LUN 0.
/> qla2xxx/naa.21000024ff8698b2/luns create /backstores/block/lun2
Created LUN 0.
/> qla2xxx/naa.21000024ff8698b3/luns create /backstores/block/lun3
Created LUN 0.
```

---

## WWN ACLs

To ensure the right initiator hosts get the right LUNs exposed, we need to add the initiator WWN to the target WWN allowed Access Control List.  This is more important when doing FC over a switch where different hosts could potentially gain access to LUNs they're not supposed to, but still needed to be defined for direct connected FC.

On the initiator host, run the following command to find the WWN port name:

```bash
# Find the initiator port name - host# may be different
cat /sys/class/fc_host/host7/port_name
0x21000024ff1254e9
```

What we're wanting is that `0x21000024ff1254e9` string without the `0x` prefix.  We can now plug that into the ACL definition in `targetcli`.

Return to the target storage host and run the following in the `targetcli` shell:

```bash
/> qla2xxx/naa.21000024ff8698b0/acls create 21000024ff1254e9
Created Node ACL for naa.21000024ff1254e9
Created mapped LUN 0.
```

Again, your WWNs will be different depending on your card/port.

---

## Using the LUNs

With all that we should be able to now use the exposed LUNs from the target server on our initiator hosts.  You can either reboot that initiator host or run `echo 1 > /sys/class/fc_host/host9/issue_lip` to rescan the SCSI devices exposed to it.  From that point you can also use `lsblk` to get details on the available LUN(s) and what device path they're mounted to:

```bash
# See newly attached disk on the initator (client)
lkblk

# Find WWN and HCTL IDs
lsblk -o NAME,MODEL,SERIAL,WWN,HCTL,MOUNTPOINTS,SIZE
```

You should now be able to consume the available LUN devices as blocks for different things in the filesystem, VMs, or even host OS installation!

---

Again, this doesn't go over multipathing or use of LUNs across multiple hosts which would all need an FC switch or two, but this is a pretty good way to learn the fundamentals of FC storage with minimal hardware requirements.  For that whole bag of tricks I'll probably write up another article to cover more enterprise-y FC stuffs in the future because I'm pretty sure I'll need to learn that as well.