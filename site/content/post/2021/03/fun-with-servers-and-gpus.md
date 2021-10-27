---
title: "Fun with Servers and GPUs"
date: 2021-03-20T07:42:47-05:00
draft: false
publiclisting: true
aliases:
    - /blog/fun-with-servers-and-gpus/
toc: false
hero: /images/posts/heroes/resized/resized-fun-with-gpus.png
tags:
  - homelab
  - dell
  - servers
  - r720
  - r730
  - psu
  - eps 12v
  - eps-12v
  - nvidia
  - tesla
  - grid
  - quadro
  - rtx
  - gpu
  - pci
  - pcie
  - power
  - cable
  - N08NH
  - 9H6FV
  - K80
  - M40
  - M60
  - P100
  - V100
  - red hat
  - openshift
  - kubernetes
authors:
  - Ken Moini
---

> ***I have bought way too many cables and dongles lately...***

So as I jump into the world of GPU accelerated workloads, I had to well, get a few GPUs.  In my inventory now is the following:

- 2x) NVidia M40 GPUs
- 1x) Nvidia Quadro RTX 4000 GPU

And I have a few others that are Radeons that I use in my workstations - anywho, the NVidia gear is meant to be used with my heavy compute resources in my homelab.  At first they were in my EPYC server but it didn't feel too right to me - plus, I have more RAM available in my R720s.

## Dell Servers and GPUs

So I actually had 3x) R620s before all this, each with 256GB of RAM, 2x E5-2660v2 CPUs and unfortunately the R6x0 series can't really take GPUs - well, it can with a single-width 3/4-length card that uses 75w at most, which isn't many GPUs you really would want to put in a server.

With that, I traded those R620s for 2x) R720s which can power GPUs and other PCI devices up to 250w!

Now, even in R720/R730s, the actual PCIe slot only provides 75w of power - however, on the edge of PCIe riser you'll see a little port to plug in a cable for extra power!

{{< center >}}![Moar power](/images/posts/legacyUnsorted/20210320_234723.jpg){{</ center >}}

This plug right here, it gives EPS-12v power - this is IMPORTANT!  "Why," you ask?

## Dell GPU Power Cables

So now you have a GPU, and a server that can house/power it, but you still need some cable to power it - naturally you search eBay for something like "R720 GPU cable" which lands you on something like this:

{{< center >}}![Seems legit](/images/posts/legacyUnsorted/dellGPGPUcable.jpg){{</ center >}}

*Ah yes!  The classic N08NH/9H6FV cable, of course!*  These cables take the 8-pin EPS-12v power at the riser's port and converts it to two PCIe device power cables, a 6-pin an a 6+2-pin line.

Take note of the ***"GPGPU"*** in that title - this is important.  This is "General Purpose GPU" which for us means it takes general PCIe device power - this works well for my Quadro RTX 4000, any GeForce GPU, and other PCIe devices that require extra power.

> **So what *isn't* a GPGPU?**

### Meth-addled Raccoons

There is a series of cards that NVidia made, Tesla cards, Grid cards, or something like that - they can't be bothered to name things in ways normal humans can comprehend.

Anywho, these cards are ***NOT*** GPGPUs and do ***NOT*** take PCIe power - in fact they take EPS-12v power.  Why they decided to do this is beyond me really but they obviously realized it was dumb and stopped using EPS-12v in.

These cards consist of the following:

- K80
- M40
- M60
- P100
- V100

***What happens when you try to plug in a PCIe power cable into one of these cards?***

Well, the plastic tab doesn't quite fit, and the 8-pin and 6+2-pin connectors have some extra plastic on them that prevent insertion.  Of course, I shaved down those annoying plastic parts and tried anyway.  GROUND ERROR.  Whoops!

On top of that, if your PSU doesn't have good current protection mechanisms you can actually start a fire!  ***DO NOT FORCEFULLY INSERT POWER CABLES IF THEY DO NOT FIT!***

## Power Cable for Tesla/Grid GPUs in Dell Servers

So I'll save you all the embarassing trial & error cycles I spent with different cables, exacto knives, and a myriad of dongles.  If you're following along you may have caught two points:

- The power provided by the plug at the Riser is EPS-12v
- The power needed by the Tesla cards like my M40 is EPS-12v

***Wait - does this mean all that's needed is a straight cable?***

{{< center >}}![FML](/images/posts/legacyUnsorted/yup.gif){{</ center >}}

Yeah, it took me too long to figure that one out - to be fair though, this isn't very well documented anywhere.

There is no "official Dell EPS-12v cable" that I could find - the right type of cable looks something like this:

{{< center >}}![The right cable](/images/posts/legacyUnsorted/rightCable.jpg){{</ center >}}

8-pin and male on both ends, EPS-12v, not-PCIe.

## Mixing and Matching

Something else to know - the Dell Technical Guide says you have to have the same sort of GPU in the system, and this is not quite the case...

{{< center >}}![M40 and Quadro sitting in PCIe...](/images/posts/legacyUnsorted/20210320_234838.jpg){{</ center >}}

Anywho, hopefully that helps some people who are messing around with some of this sort of gear, save ya an extra 2-3 weeks and $100 of cables/dongles...