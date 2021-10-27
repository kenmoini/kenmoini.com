---
title: "Installing NVidia Drivers in RHEL 8"
date: 2021-03-13T22:02:47-05:00
draft: false
toc: false
aliases:
    - /blog/nvidia-drivers-on-rhel8/
hero: /images/posts/heroes/resized/resized-nvidia-drivers-rhel8.png
tags:
  - rhel
  - rhel 8
  - red hat enterprise linux
  - red hat
  - nvidia
  - drivers
  - cuda
  - data center driver
authors:
  - Ken Moini
---

> ***Part 2 of what is likely to be a small series in me figuring out all this Ray Tracing & Pixel Streaming from containers in OCP stuff...***

If you're following along with my adventures in Polygon Land, I'm working on getting a couple GPUs rolling on a RHEL 8 host, that will eventually run some OCP VMs to access these GPUS, but I'm wanting to test things first before just throwing them into some PCIe passthrough.

In [Part 1, I removed the Nouveau drivers from my RHEL 8 system](https://kenmoini.com/blog/disabling-nouveau-drivers-rhel-8/), and now I'm free to install NVidia drivers for these GPUs.

## DISCLAIMER!

***This will hella void your RHEL system's supportability.  If that's something you care about then probably don't do this, and open a support ticket with Red Hat for guidance to drive more interest around supporting this sort of thing directly.***

### 1. Download the latest drivers

I'm using two different cards, a Quadro RTX 4000 and an M40.  These GPUs are for different sorts of workloads, Quadro more so for high performance video stuff, and the M40 for more computational workloads like Machine Learning.  Of course, they use different sorts of drivers.

#### 3D GFX

If you're using a GeForce/Quadro card, grab the latest drivers from the NVidia site: https://www.nvidia.com/Download/index.aspx?lang=en-us

For this article, I'm would be using driver version: 460.56, Release Date: 2021.2.25, Operating System: Linux 64-bit

#### Machine Learning

For the M40, the same driver page will filter you to the needed drivers, in this case being CUDA drivers.

At the time of writing, I'm using the CUDA Data Center Driver version: 460.32.03, Release Date: 2021.1.19, Operating System: Linux 64-bit, CUDA Toolkit: 11.2

#### Set executable bits

Don't forget to add the executable bits to the driver bundles that you download, eg: `chmod +x ./NVIDIA-Linux-x86_64-460.32.03.run`

#### Duplicate Drivers

Note that even though I'm using two cards and there are two kinds of drivers, I'm only installing the CUDA Driver bundle since it also has the base 460 drivers, just with the CUDA toolkit as well...*I think*...

### 2. Install Needed Packages

Before you start to run the driver installs there are a few packages that the installers will need:

```bash
sudo dnf groupinstall "Server with GUI" "base-x" "Legacy X Window System Compatibility" "Development Tools"
sudo dnf install -y elfutils-libelf-devel gcc make kernel-headers kernel-devel acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig kmod
```

### 3. Set Text-Mode

Before installing the drivers, let's make sure we're in text-mode:

```bash
sudo systemctl set-default multi-user.target
sudo systemctl isolate multi-user.target
```

*You can switch this back to a GUI later with:* `systemctl set-default graphical.target`

### 4. Run the Driver Install

Now simply run the installations - for me it was:

```bash
sudo ./NVIDIA-Linux-x86_64-460.32.03.run
```

### 5. Reboot

Of course...

```bash
sudo systemctl reboot
```

With this now you've got NVidia drivers installed on RHEL 8 - test by running `sudo nvidia-smi`

Note that I haven't been able to get GNOME/GDE to work for me, that's due to an XOrg config issue from having multiple cards, including an on-board nerfy one, where one doesn't have a screen (the M40), and one has 4 (the Quadro).  I'm not too worried about it myself since this is a headless system and these cards will be dedicated to some VMs that run OpenShift..