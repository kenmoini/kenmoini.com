---
title: "PCI Passthrough with Libvirt on RHEL 8"
date: 2021-03-14T10:21:47-05:00
draft: false
toc: false
hero: /images/posts/heroes/libvirt-passthrough.png
tags:
  - pci passthrough
  - pcie passthrough
  - virtual machine
  - vm
  - red hat
  - rhel
  - rhel 8
  - libvirt
  - kvm
  - qemu
  - nvidia
  - gpus
authors:
  - Ken Moini
---

> ***Part 3 of what is a small series in me figuring out all this Ray Tracing & Pixel Streaming from containers in OCP stuff...***

Now that I've tested that the [GPUs do in fact work with Linux](https://kenmoini.com/blog/nvidia-drivers-on-rhel8/), I'm going to forsake all the work I did in the past few articles and dedicate the GPUs to some VMs!

## 1. New-ish Virt

First off you need CPU Virtualization Support (Intel VT-x or AMD-V) - you can check this by running the command: `grep --color -E "vmx|svm" /proc/cpuinfo`.  If there are results printed out then your CPU supports modern virtualization extensions.

## 2. IOMMU 4 U

Next is what actually allows the PCI Passthrough to happen, IOMMU.  It's likely something you've passed over in your BIOS settings many times - which is a good thing, don't fuck with things in there you don't know about.

Either way, this is something you need enabled in your BIOS in order to have support in your OS.  Refer to your BIOS' Owner's Manual to find where to do that - mine was in some weird AMD thing under **Advanced > AMD CBS > NBIO Common Options > IOMMU**.  I'm more of an NBC fan myself really, CBS is forgettable.

If there's an option to enable something called **"ACS"** that's IOMMU's Access Control System - enable that shit too.

## 3. Enable IOMMU in your GRUB2 Kernel Parameters

By now, you should expect a kernel module to load - edit your `/etc/default/grub` file and add either `intel_iommu=on` or `amd_iommu=on` to your `GRUB_CMDLINE_LINUX` definition - it should look something like this:

```
...
GRUB_CMDLINE_LINUX="crashkernel=auto resume=/dev/mapper/rhel-swap rd.lvm.lv=rhel/root rd.lvm.lv=rhel/swap rhgb quiet modprobe.blacklist=nouveau nomodeset amd_iommu=on"
...
```

## 4. Enable VFIO Unsafe Interrupts

If you're working with an NVidia card you'll likely need this piece right here too - don't ask me too much about what it does, it works for me and I found it on page 3 of a Google search soooo...do that with what you will, but it works:

```bash
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/unsafe-interrupts.conf
```

## 5. Rebuild GRUB

Rebuild the GRUB2 configuration file by running the `grub2-mkconfig -o` command as follows, depending on how your system boots/was installed:

- **On BIOS-based machines**: `grub2-mkconfig -o /boot/grub2/grub.cfg`
- **On UEFI-based machines**: `grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg`

*If you're on a BIOS-based machine, you won't have any files located in `/boot/efi/EFI/redhat/`*

## 6. Reboot

Of course, reboot to freshen things up...

```bash
sudo systemctl reboot
```

## 7. Installing Libvirt/KVM

Of course, you need to have KVM and LibVirt installed - I find this easiest by using Cockpit and installing the Machines application which takes of everything and gives you a decent only mildly-buggy Web UI to interface with your VMs.

## 8. Finding your PCI cards

Next, we'll need to find our PCI devices we want to pass through, in this case my GPUs.  You have to map it from Device ID numbers, and there's a decent way to do it without much effort:

First, find the friendly named device, this is what it shows for me:

```bash
# lspci | grep -i nvidia

41:00.0 3D controller: NVIDIA Corporation GM200GL [Tesla M40] (rev a1)
81:00.0 VGA compatible controller: NVIDIA Corporation TU104GL [Quadro RTX 4000] (rev a1)
81:00.1 Audio device: NVIDIA Corporation TU104 HD Audio Controller (rev a1)
81:00.2 USB controller: NVIDIA Corporation TU104 USB 3.1 Host Controller (rev a1)
81:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU104 USB Type-C UCSI Controller (rev a1)
```

What you want to take note of is the set of numbers in front of the root devices, in my case it's `41:00.0` and `81:00.0-81:00.3`

Note that if your logical/physical device exposes a number of PCI devices like my Quadro RTX 4000 does, you'll need all those numbers and you'll need to pass all those devices through to the VM.

## 9. Convert to Node Device Format

With that we can now convert it into node device format.  So for my first card, the M40 at `41:00.0`, my libvirt node device would be `pci_NNNN_41_00:0` where NNNN can be something different depending on your PCI controllers - you can find out exactly by running:

```bash
# virsh nodedev-list | grep pci

...
pci_0000_41_00_0
pci_0000_81_00_0
pci_0000_81_00_1
pci_0000_81_00_2
pci_0000_81_00_3
...
```

## 10. Create your VMs with --host-device

Finally, you can add your device(s) to the Virtual Machine with `virt-install` (the last line):

```bash
virt-install --name=raza-ocp-app-1-m40 \
 --vcpus ${AN_VCPUS} \
 --memory=${AN_RAM} \
 --cdrom=${OCP_AI_ISO_PATH} \
 --disk size=120,path=${VM_PATH}/raza-ocp-app-1.qcow2 \
 --os-variant=rhel8.3 \
 --autostart \
 --noautoconsole \
 --events on_reboot=restart \
 --host-device=pci_0000_41_00_0
```

And again, if you're using something like a Quadro that has multiple devices, you'll need to pass all of them through, such as the following (note the last line):

```bash
virt-install --name=raza-ocp-app-2-quadro \
 --vcpus ${AN_VCPUS} \
 --memory=${AN_RAM} \
 --cdrom=${OCP_AI_ISO_PATH} \
 --disk size=120,path=${VM_PATH}/raza-ocp-app-2.qcow2 \
 --os-variant=rhel8.3 \
 --autostart \
 --noautoconsole \
 --events on_reboot=restart \
 --host-device=pci_0000_81_00_0 --host-device=pci_0000_81_00_1 --host-device=pci_0000_81_00_2 --host-device=pci_0000_81_00_3
```

Now you have the devices dedicated to those VMs - of course those VMs will need the drivers installed in order to use them, or if like in my case where these VMs are actually OpenShift nodes, they'll just use the [Operator Framework to wire everything up automatically](https://kenmoini.com/blog/using-nvidia-gpus-in-openshift/)!