---
title: "SFF FTW"
date: 2024-05-10T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/sff-ftw.png
photo_credit:
  title: Pexels
  source: https://www.pexels.com/photo/person-in-white-long-sleeve-shirt-using-black-and-red-audio-mixer-4705623/
tags:
  - open source
  - oss
  - homelab
  - automation
  - red hat
  - rhel
  - fedora
  - onlogic
  - cl250
  - minisforum
  - ms-01
  - beelink
  - ser5
  - amd
  - epyc
  - intel
  - kvm
  - libvirt
  - qemu
  - podman
  - containers
  - kubernetes
authors:
  - Ken Moini
---

> Not Another NUC Movie

---

Normally I'm a fan of big, beefy servers.  I really like my custom built AMD EPYC towers - watercooled 64C/128T with 512GB DDR4, handles pretty much anything I throw at them.

However, I got kinda tired of having one running for some basic stuff  like DNS, FreeIPA/RH IDM, an OpenVPN server, etc services that glue my networks together.  *Plus I wanted to repurpose that big server to run OpenShift bare metal.*

Another annoying point was that if that one server went down then most of my lab and home network would too, so I barely updated it and was terrified of reboots.  To solve that I of course wanted to use something like Kubernetes where I could have a small cluster that I could float containers around while I ran maintenance on a physical node.

Alas, not everything can be run so easily as a container - namely IDM and my OpenVPN server.  Believe me, I tried to run the OpenVPN server - which is already running as a container with Podman - on the Kubernetes cluster, but it totally FUBAR'd things.  Some things are just better with the KISS method - a little VM here, bit of Podman there, rock solid.

In this article I'll be reviewing a few Small Form Factor (SFF) systems around similar price points that I've tested and detailing what I've done with them.  The contenders are:

- BeeLink SER5 MAX
- OnLogic CL250
- Minisforum MS-01

I won't be getting into the unboxing or in-depth spec list, there are plenty of videos on YouTube about that - I'll mostly be going over how I'm using these SFF systems for a more efficient and resilient homelab.

---

## BeeLink SER5 MAX and Kubernetes

So my first task was to use Kubernetes to offload things like my DNS, StepCA, Vault, etc containers that I was already running with Podman on that big physical host.  For this I needed at least 3 hosts with a couple storage interfaces, and a decent count of cores and GBs of RAM.

Saw a post in a #homelab chatroom about the BeeLink line of SFF systems and picked up a few SER5 MAX boxes - they're often on sale for $100 off!  They're sleek AMD Ryzen systems that check all the boxes for a little K8s cluster - NVMe for boot, and SATA SSD for bulk storage that is provided by Longhorn.

Installing Fedora and Kubernetes is pretty trivial, and of course I spent days automating a process that would have manually taken a few hours - you can find that here: https://github.com/kenmoini/ansible-fedora-k8s/

Now, if you know anything about me *(most of you probably don't)* then you know I love me some GitOps - so pretty much everything is taken care of via ArgoCD with sync waves to handle the roll outs of services in what *(hopefully)* seems like the right order.  The cluster currently runs:

- ArgoCD (of course)
- Longhorn for storage
- Hashicorp (IBM now?) Vault
- External Secrets
- StepCA and Step Issuer
- cert-manager
- PowerDNS Authoritative & Recursive Servers
- Pi-Hole
- Nginx-Ingress
- MetalLB
- phpIPAM
- Squid Outbound Proxy
- Kubernetes Dashboard
- Dashy
- Misc internal sites

Now I did run into a bit of a chicken-egg problem with DNS - my DNS servers need to be running for the K8s cluster to work, and now I run them on my K8s cluster.  So for emergency instances I have my Podman containers ready to start as SystemD services on each of the K8s hosts to run DNS, which I've only had to use once.  Since I run two separate deployments of both my authoritative and recursive servers, along side two separate deployments of Pi-Hole, I can float the services between nodes pretty effectively and cover most scenarios.

Aside from that, they're a dream for what they do - plenty of room for workloads, I could burn the whole set of systems down and start back up pretty easily.  Some backups of the PowerDNS and Vault PVCs to my TrueNAS server covers any "uh oh" moments...*I think*.

My one gripe would be that the tiny fan is pretty audible up close.  Not anything like a 1U/2U rack-mount server, but enough to be somewhat annoying if you're close by - can't hear it when I'm in the other room but I'd probably be tired of the tiny boxes if it were sitting on my desk.

Anywho, I'd highly recommend them for similar workloads - could even handle a few simple VMs really, but I wanted them dedicated to K8s without having to manage pets on specific nodes.

---

## OnLogic CL250

Next I needed something to run a couple things that don't work well on Kubernetes.  For this I tried another SFF system I had laying around - an OnLogic CL250.

I used this system before simply because it was RHEL certified and needed to run Microshift for a couple demos - the demos came and went, and it had been sitting in a box collecting dust since then so I figured why not try to use it.

On the surface it's a pretty cool bit of gear wrapped in some sleek silver and orange - however when you dig deeper it's rather disappointing.

The main problem is just getting one - first time I ordered, even though it was "In Stock," I got an immediate "oops it's on backorder actually" email so I waited 6 months, hit them up and got an "oops, we forgot, hopefully soon" so I canceled my order and emulated an "edge device" with a VM for my demo.  Tried again, same story with the In Stock/Backorder bait and switch so I immediately canceled it.  Third time, still got the immediate backorder email, but I proactively engaged them, and a very kind guy named Gray helped get things moving.  While he was more helpful than the previous manifestation of marinated cabbage, it's still kinda lame to have to go through those extra motions and purchasing whiplash.

Anywho, after I finally got it for my second intended demo, the first thing I did is pop it open of course - for an "industrial PC" the bit of tape they had around the ports wasn't impressive with its lack of full coverage.  The case acts as a heatsink which is kinda cool and it does have some wireless connectivity options that were handy for a wireless bridge, but that doesn't matter when using in my lab as a host for a VM and a couple of containers.

Loaded RHEL on it which was easy of course, however when I started to migrate my IDM VM and some containers over I found out that the Intel Celeron CPU and measly 8GB of RAM really don't give you much room to roam.  It started to thrash the swap and basically folded itself into the void.  This happened before when I ran Microshift on it, the swapping made the system unstable and eventually crash - which honestly I should have know better than to have enabled considering K8s doesn't like swap.

So I ended up throwing it back into the bin from whence it lurked - pretty sad considering it's in the same 600-700 base price range of these other systems.  OnLogic of course has beefier systems but the price of those is a non-starter and I'd be skeptical of their quality and supply chain.

---

## Minisforum MS-01

So I still had the problem of running a few workloads on a tiny system.  Of course I could have gave in a gotten some sort of NUC but since Intel got rid of their NUC division I decided to stay away from that option.

Another recommendation from the *#homelab homies* was a Minisforum MS-01 - a new box, slightly larger than the others, but with a list of dream-like specs.  2x10G SFP+ ports, bunch of cores, and up to 96GB of DDR5?!?!  After reading the [ServeTheHome article](https://www.servethehome.com/minisforum-ms-01-review-the-10gbe-with-pcie-slot-mini-pc-intel/) on the MS-01, I smashed that Order button like a cicada going at my windshield.

Supply chain sadness struck again - I ordered it in January and finally got it at the end of April...right when they started to become available on Amazon with week-out shipping :upside_down_face:

Threw in some RAM, a couple sticks of NVMe, slid in some SFP+ DACs, and was set up running Fedora within a few songs.  Thanks to some more automation I've had for a while, I was able to quickly stand up my needed services such as Libvirt and Podman.

However when migrating things from RHEL to Fedora I ran into a few snags.  Evidently, newer versions of Podman use a different network definition in a new location - that was fun to debug.  With a peak at the docs I was running my OpenVPN server like it had been on my big beefy RHEL+EPYC system with the containers bridged to my local network...it looks something like this:

```bash=
# cat /etc/containers/networks/bridge0.json 
{
     "name": "bridge0",
     "id": "627bf10a7b8080f8bcdcecc575de964c16d488afb8348ec2c9707fd4177e1b96",
     "driver": "macvlan",
     "network_interface": "bridge0",
     "created": "2024-05-03T17:01:16.476121287-04:00",
     "subnets": [
          {
               "subnet": "192.168.42.0/23",
               "gateway": "192.168.42.1"
          }
     ],
     "ipv6_enabled": false,
     "internal": false,
     "dns_enabled": false,
     "ipam_options": {
          "driver": "host-local"
     }
}
```

Next up I had to edit a bunch of things in the Libvirt VM XML definition for my RH IDM migration.  **Fun Fact:** Fedora and RHEL store EFI package files in different places - *sweet*!  They also don't have the same sort of display interfaces, and RHEL has a more expansive machine emulation list so I just went with the default Q35.

One of the hesitations I had with the MS-01 was the Intel i9 CPU - it has their mix of Performance and Efficiency cores and I don't really care for that sort of thing.  So far for these sort of workloads it's been pretty solid, haven't seen much of a performance impact outside of some odd instances where executing some things are a little slow - even then it's plenty fast enough for what it needs to do.

Still don't know what to do with the PCIe slot - kinda wanted to put a GPU in since all my other systems have GPUs, but when I looked up their "supported GPU" as listed on the Miniforums site they mention an "A2000 Mobile" - which simply does not exist as a PCIe card.  Evidently some people have been modding the A2000 cards to work in smaller enclosers and that seemed like a bit too much for my blood.  I can't think of what I'd really run with it anyway, so I'm good with keeping it cooler and consuming less power.

Overall I'd highly suggest the MS-01 system for homelab servers - not so much for things like OpenShift maybe just due to the P/E cores, which with 96GB of DDR5 seems a bit pear shaped.  With the included U.2 drive adapter this could even be a pretty damned good Ceph node.  The multiple NICs also would give it a good run at being a router.  All around a pretty solid machine - good enough to where I ordered a second one to run a little ESXi node.

---

With all that, I feel like my homelab is now right-sized and a bit more efficient.  I can shut off my big beefy systems when not in use, save power, reduce background noise, and produce less heat - which during the summer here in North Carolina is *crucial*.

Most important of all, I found myself to love my homelab a little more, in all it's various shapes and sizes *#hardwarePositivity*