---
title: "Disabling Nouveau Drivers in RHEL 8"
date: 2021-03-13T21:02:47-05:00
draft: false
toc: false
hero: /images/posts/heroes/disable-nouveau-drivers-rhel8.png
tags:
  - rhel
  - rhel 8
  - red hat enterprise linux
  - red hat
  - nvidia
  - drivers
  - grub
  - nouveau
authors:
  - Ken Moini
---

> ***Part 1 of what is likely to be a small series in me figuring out all this Ray Tracing & Pixel Streaming from containers in OCP shit...***

Somehow I've stumbled into needing a few GPUs to do some data computation and pixel streaming workloads.  So I slapped a few nVidia GPUs in my EPYC system, even though as an AMD/Radeon fan it felt like sacrilege...

This EPYC system runs RHEL 8.3 and now has a Quadro RTX 4000 and M40 card - the system sees them via `lspci | grep -i nvidia` but before I can use them, evidently EVEN with containers, I need to install some drivers...might be able to containerize the driver and do some funny stuff, that's probably how the OpenShift operator works...anywho...let's do this all the hard way!

## DISCLAIMER!

***This will hella void your RHEL system's supportability.  If that's something you care about then probably don't do this, and open a support ticket with Red Hat for guidance to drive more interest around supporting this sort of thing directly.***

## Get rid of the Nouveau fangled stuff

Because nVidia is a toxic company and doesn't want to support Linux properly, the open-source community has created a set of drivers called ***Nouveau*** that can do most things outside of 3D rendering and advanced GPU stuffs, and the nVidia Drivers don't like sitting next to the Nouveau drivers so one of them has to go.

### 1. Modify GRUB parameters

Edit the `/etc/default/grub` file and append the following to the `GRUB_CMDLINE_LINUX` line: `modprobe.blacklist=nouveau`

The line should look something like this:

```text
GRUB_CMDLINE_LINUX="crashkernel=auto resume=/dev/mapper/rhel-swap rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap rhgb quiet modprobe.blacklist=nouveau"
```

### 2. Create Modprobe Denylist dynamic config

Run the following command which will add another play to deny Nouveau's kernel module from loading:

```bash
echo "blacklist nouveau" > /etc/modprobe.d/denylist.conf
echo "options nouveau modeset=0" >> /etc/modprobe.d/denylist.conf
```

*One of these days we'll get better language adopted in core Linux systems...*

### 3. Set the default boot target to text-mode [If running Server w/ GUI]

To avoid driver issues with X being loaded, let's just set the boot target level to text mode instead of a graphical login:

```bash
sudo systemctl set-default multi-user.target
```

*You can switch this back to a GUI later with:* `systemctl set-default graphical.target`

### 4. Regenerate Kernel InitRAMFS

Run the following to rebuild your initramfs:

```bash
sudo dracut --force
```

### 5. Rebuild GRUB

Rebuild the GRUB2 configuration file by running the `grub2-mkconfig -o` command as follows, depending on how your system boots/was installed:

- **On BIOS-based machines**: `grub2-mkconfig -o /boot/grub2/grub.cfg`
- **On UEFI-based machines**: `grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg`

*If you're on a BIOS-based machine, you won't have any files located in `/boot/efi/EFI/redhat/`*

### 6. Reboot

And finally...

```bash
sudo systemctl reboot
```

At this point you can continue to install NVidia drivers!