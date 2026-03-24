---
title: Azure to On-Prem Lab Connectivity
date: 2026-03-20T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/azure-to-lab.png
photo_credit:
  title: Pixabay
  source: Pexels
tags:
  - azure
  - aro
  - red hat
  - microsoft
  - vpn
  - tunnel
  - vnet
  - virtual network
  - site-to-site
  - ipsec
  - dns
  - routing
  - openshift
  - lab
  - connectivity
authors:
  - Ken Moini
---

> RAM shortage got things wild

So in case you haven't heard...there are no DIMMs!  Well, there are if you want to pay 500% more for a server now than you could have in 2025 for the same server...

And that's what's bringing us this next cursed episode of "Ken has to figure things out" - lift and shifting workloads into the cloud cause we can't have no old servers.

I've got a migration to run - moving VMs from vSphere to Azure Red Hat OpenShift.  Should work, but of course I'm not exposing my vCenter and hosts to the Internet - so for this I need to make a VPN connection of sorts from Azure to/from my lab.

I'm running a Unifi stack here which natively supports a few different VPN options, so this is the process I took to set up a VPN between Microsoft Azure and my garage to securely schlep VMs around.

---

## Architecture

So before we begin, a little overview of what's going to be used in the cloud and on-prem in my lab:

### Lab Network

- `192.168.42.0/23` - Lab Network, has vCenter
- `192.168.60.0/23` - OpenShift Network
- `kemo.labs` - Private zone that runs my things

### Azure Network

- `10.0.0.0/20` - ARO Virtual Network
- `10.0.0.0/23` - ARO Control Plane Subnet
- `10.0.2.0/23` - ARO Control Plane Subnet
- `10.0.4.0/26` - Virtual Network Gateway Subnet (will be created in further steps)
- `10.0.4.64/28` - Subnet for Private DNS Resolver Inbound Endpoint (will be created in further steps)
- `10.0.4.80/28` - Subnet for Private DNS Resolver Outbound Endpoint (will be created in further steps)
- `azure.kemo.network` - Public zone that will be used for some Azure things (mostly just a DNS record for testing with a bastion host)

---

## Azure VPN Setup

1. If you haven't already, create a Virtual Network (VNet) in Azure.  If you're using Azure Red Hat OpenShift then you already have a VNet created.  Note that the default VNet Address Space probably only accounts for the node IP pools - I had to expand the Address Space to make room for the Virtual Gateway subnet that we'll create in a second.
2. With the VNet and it's subnets in place, search for "Virtual Network Gateway" and create a new one.
3. For my example I'm running a non-redundant VPN - mostly because I don't want to do BGP routing between my site and the cloud.  Below you can see the settings I used to create the VNet Gateway.
4. After you click Create, go take a walk - a long one.  Took about an hour for my VNet Gateway to spin up.
5. Next we'll create a **Local Network Gateway** in the Virtual Network Gateway.  The Local Network Gateway is defined in Azure that represents the public IP address of your on-prem network - doesn't have to be static, so long as it doesn't change too often.  If it does change or you use something like DynDNS then just give it the FQDN instead.  Map some of the local networks you'll tunnel into Azure by defining the subnets in the LNG.
6. Now we go BACK to the Virtual Network Gateway, in the left pane navigate to "VPN Gateway > Connections" and make a new Connection.  This glues the VNG and LNG together and actually spins up the VPN.  You'll want to use the Site-to-Site IPSec type of VPN Connection.  What's important in the Settings page for the VPN Connection is to set the IPSec/IKE Policy to "Custom" - then set the two phases' Encryption to "AES256", Integrity to "SHA256", and Groups to "2" like shown in the screenshots below.  Generate a long PSK and store it in a secure password vault of some sort.
7. Wait for the VPN Connection to be created - once it is, grab the IP Address of the Virtual Network Gateway, we'll need that to configure the Unifi side of things

---

## Unifi Setup

1. In the Unifi Network dashboard, navigate to Settings > VPN then click the tab for "Site-to-Site VPN" and create a new one.
2. VPN type will be IPSec, give it a name and that Pre-Shared Key from earlier that we configured in Azure's VPN Connection.
3. Set the Local IP for the WAN IP you configured in Azure's Local Network Gateway.
4. The Remote IP / Hostname will be the Public IP Address from the Virtual Network Gateway in Azure.
5. Leave VPN Method to Route Based, then configure the Static Remote Networks for what the Azure VNet has, in this case `10.0.0.0/20`
6. Scroll down and set the Advanced mode to "Manual" - Key Exchange Version should be set to IKEv2.
7. Configure the Encryption/Hash/Group as you did on the Azure side, so AES0256, SHA256, and 2.
8. Leave the rest as the default settings and click Add.  It might take a moment for the tunnel to be established but eventually you should see "Online".  Azure seems to be a bit slow with updating things so give it a little time and you should also see "Connected" in the VPN Connection.

The VPN tunnel is now established!  But it's still barely usable.  Next up we'll need to create some Routes so that things can get between the two infrastructure providers.

---

## Azure Routing Setup

Next we need to create a few things in Azure so that it can route to the on-premise environment.  Namely a Route Table.

1. In Azure, search for "Route Table" and create a new one.
2. With the Route Table created, access the resource and navigate to Settings > Routes.  Create a new Route.
3. Give it a name, Destination Type should be "IP Addresses" and give it the CIDR range that's on the other side of the tunnel - in my case I have 2 so I'll need to make Routes for each subnet.
4. Set the Next Hop Type to "Virtual Appliance" and set it to the WAN IP of the on-prem network that was configured in the Local Network Gateway.
5. Rinse/repeat for as many subnets as you have to route.

Now to test this, you can go into a Virtual Machine that's in the VNet that we configured all this stuff for and do a quick `ping/ssh on-prem-address-here` - for my environment I just used a debug terminal on one of the Azure Red Hat OpenShift nodes.

> Note: If the ping fails, it is likely due to needing to open some Firewall rules in Unifi, source being VPN and the instance configured, and the destination being the routed network.

---

## Unifi Routing Setup

Now if you just need to get to assets on-prem FROM Azure, you can skip this next step, but I like bi-directional communication when possible - helps make sure things are working right on both ends.

1. In the Unifi Network dashboard, navigate to Settings > Policy Engine > Policy Table.
2. Create a new Static Route - should be a Gateway type, Distance of 1, and give the Next Hop Address the Public IP Address from the Virtual Network Gateway in Azure.
3. Set a destination network, in this case it's the Azure VNet being `10.0.0.0/20`

With that configured you should now be able to connect to Azure resources from the on-premise environment!  I tested by doing an SSH connection test to one of the ARO nodes, didn't have the SSH key but still good to test the connection/firewall/security groups are acting right.

While we're here in the Unifi dashboard, if the previous `ping`/`ssh` test from Azure to the on-prem network failed, it's probably because there are no firewall rules allowed from the VPN Source to the Destination Networks - make sure to add those in for all the routed and tunneled subnets.

---

## Azure DNS Things

Now that the Site-to-Site tunnel is setup, IP connectivity is looking good, last thing we need is to resolve DNS things - no good connecting things if you have to remember octets.

1. In Azure, search for "DNS Private Resolvers" and create a new one.
2. Set it in the intended RG/VNet.
3. Skip creating an Inbound/Outbound Endpoints and Rulesets, we'll do that once the Resolver is created.

Once the DNS Private Resolver is created, let's work on the Endpoints.

### Inbound Endpoint

The Inbound Endpoint is simply a little DNS resolver that runs in Azure and takes queries for for Private Zones defined in Azure.  With this you can point your on-prem DNS stack to send queries for zones in Azure to the Inbound Endpoint to resolve.

1. With the DNS Private Resolver resource loaded, navigate to Settings > Inbound Endpoints and create a new one.
2. Give it a name, and create a new Subnet, default /28 should work fine.  You don't want to give it an existing subnet (unless you know that's the architecture you want) because each subnet can only have ONE Endpoint type.
3. IP address assignment can be Dynamic, Azure will keep up with the updates - unless you have a specific static IP you'd rather use.

With the Inbound Endpoint created, you can now query it from an on-prem system with something like `dig @ENDPOINT_ADDRESS bastion.azure.kemo.network`

### Outbound Endpoint

The Outbound Endpoint is a DNS resolver that runs in Azure that forwards queries for zones not managed in Azure to other DNS servers.  So in this instance, I want my ARO cluster to be able to reach records in my `kemo.labs` Zone that I host in my lab.

1. With the DNS Private Resolver resource loaded, navigate to Settings > Outbound Endpoints and create a new one.
2. Give it a name, and create a new Subnet, default /28 should work fine.  You don't want to give it an existing subnet (unless you know that's the architecture you want) because each subnet can only have ONE Endpoint type.
3. Click Create - super boring, the real fun is with the Rulesets.

