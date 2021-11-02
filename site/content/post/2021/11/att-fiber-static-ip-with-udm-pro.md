---
title: "AT&T Static IP Blocks with the Unifi Dream Machine Pro"
date: 2021-11-01T04:20:47-05:00
draft: false
toc: false
publiclisting: true
hero: /images/posts/heroes/att-fiber-udmp.png
tags:
  - homelab
  - att
  - at&t
  - fiber
  - ip address
  - static
  - unifi
  - ubiquiti
  - dream machine pro
  - udmp
  - udm pro
authors:
  - Ken Moini
---

> ***brb starting a datacenter in my closet***

#### ***tl;dr:*** Getting & setting Static IPs on AT&T Fiber's Gateway and passing them through to a Unifi Dream Machine Pro

So thankfully we have AT&T's Fiber service where we live - I will never go back to living somewhere with Spectrum or the like. ***#fiber4eva***

Even better is that AT&T Fiber has the option of buying Static IP blocks!  

## Buying a Static IP Block

You can buy a single block - the [options](https://www.att.com/support/article/u-verse-high-speed-internet/KM1002300/) are:

- **Block Size:** 8, **CIDR:** /29, **Netmask:** 255.255.255.248, **Usable:** 5 - ***$15***
- **Block Size:** 16, **CIDR:** /28, **Netmask:** 255.255.255.240, **Usable:** 13 - ***$25***
- **Block Size:** 32, **CIDR:** /27, **Netmask:** 255.255.255.224, **Usable:** 29 - ***$30***
- **Block Size:** 64, **CIDR:** /26, **Netmask:** 255.255.255.192, **Usable:** 61 - ***$40***

I just got the $15 option, I use one for L7 HTTP{S} services, and others as L4 Load Balancers for exposing things like Kubernetes/OpenShift clusters.

Also, I believe Static IPs are only available on the 1Gbit+ connections, not sure why anyone would have a slower speed with a fiber connection...I want as many of those light beams as possible.

**To order, just call *800-288-2020*** and ask for a technical sales representative, tell them that you want to buy a Static IP Block for your Fiber Internet connection - it will take a few hours to provision across the network but they can tell you the provisioned block when the order is initially completed.  They'll tell you it's something like the following:

- **Provisioned Block:** 161.192.161.32/29
- **Network Address:** 161.192.161.32
- **Subnet Mask:** 255.255.255.248
- **Broadcast Address:** 161.192.161.39
- **Usable Host IP Range:** 161.192.161.33 - 161.192.161.37
- **Gateway/Router Address:** 161.192.161.38

## Configure the Gateway Device

The Gateway device (not the ONT) being used here is the ***BGW210-700***.  There may be other AT&T Fiber Gateways that Static IPs can work with but I'm not sure.

To configure the Static IP Block, first you need to add it to the Gateway - access the Gateway's Web UI, traditionally at `http://192.168.1.254/`

### Disable IP Passthrough & Firewall Functions

So with a Unifi Dream Machine Pro, most AT&T Fiber subscribers pass the IP from the gateway to the UDM Pro via **IP Passthrough** - with a Public Subnet being assigned (your *public* Static IP block), you don't use IP Passthrough and instead assign the Public Subnet to the Gateway to route.

Since we're using the UDM Pro as our Gateway/Firewall, you can go ahead and disable the firewall functions on the gateway to prevent any conflicts.

{{< imgSet cols="2" name="ip-passthrough" >}}
{{< imgItem src="/images/posts/2021/11/ip-passthrough-settings.png" alt="IP Passthrough should be set to Off" >}}
{{< imgItem src="/images/posts/2021/11/att-gateway-firewall.png" alt="Disable the various Gateway Firewall functions if that's being handled by something else" >}}
{{< /imgSet >}}

### Set your Public Subnet

The way you configure a gateway to route a block of static IPs, is via the Public Subnet function.

{{< imgSet cols="1" name="public-subnet" >}}
{{< imgItem src="/images/posts/2021/11/public-subnet-config.png" alt="Set your Static IP block under Home Network > Subnets & DHCP" >}}
{{< /imgSet >}}

At this point, you should be able to ping the IPs 161.192.161.33 - 161.192.161.37 and get a response from the gateway.  Now the Gateway treats those IPs as client-side IPs, meaning the UDM Pro can now use those as WAN IP addresses - let's configure that side of things now.

## Unifi Dream Machine Pro Configuration

With the Gateway configured with the Public Subnet, we can attach our available IPs to the UDM Pro WAN port.

Log into your UDM Pro, you can likely access it via [Unifi's Online Services](https://unifi.ui.com/)

Navigate to the Network and UDM Pro in question, then to **Settings > Internet**.

Set the WAN IPv4 settings to resemble the following:

{{< imgSet cols="2" name="udmp-settings" >}}
{{< imgItem src="/images/posts/2021/11/udmp-navigate-to-internet.png" alt="Navigate to Settings > Internet" >}}
{{< imgItem src="/images/posts/2021/11/udmp-wan-ipv4-settings.png" alt="Set the Static IPs on the WAN IPv4" >}}
{{< /imgSet >}}

> And that's it, route the IPs through your UDM Pro firewall however you'd like!