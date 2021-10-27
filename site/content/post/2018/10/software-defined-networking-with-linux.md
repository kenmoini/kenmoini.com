---
title: "Software Defined Networking with Linux"
date: 2018-10-01T22:31:48-05:00
draft: false
listed: true
aliases:
    - /blog/software-defined-networking-with-linux/
hero: /images/posts/heroes/resized/resized-sdn-linux.png
tags: 
  - administration 
  - centos 
  - chrony 
  - chronyd 
  - cluster 
  - cumulus 
  - debian 
  - dhcp 
  - dns
  - gluster 
  - guide 
  - kubernetes 
  - linux 
  - linux networking 
  - network 
  - networking 
  - ntp 
  - raspberry pi 
  - red hat 
  - rhel 
  - sdn 
  - software defined networking 
  - tutorial 
  - ubuntu 
  - walkthrough
authors:
  - Ken Moini
---

Well well well, it’s been a while y’all.

Been busy developing and writing a few things, some more exciting stuff coming up in the pipeline.
A lot of the projects I’m working on have to kind of sort of “plug together” and to do a lot of this I use open-source solutions and a lot of automation.
Today I’d like to show you how to setup a Linux based router, complete with packet forwarding, DHCP, DNS, and dare I even say NTP!

## Why and what now?

One of the projects I’m working on requires deployment into a disconnected environment, and it’s a lot of things coming together.  Half a dozen Red Hat products, some CloudBees, and even some GitLab in the mix.  Being disconnected, there needs to be some way to provide routing services.  Some would buy a router such as a Cisco ISR, I in many cases like to deploy a software-based router such as pfSense or Cumulus Linux.  In this environment, there’s a strict need to only deploy Red Hat Enterprise Linux, so that’s what I used and that’s what this guide is based around but it can be used with CentOS with little to no modification, and you can execute the same thing on Debian based system with some minor substitutions.

A router allows packets to be routed around and in and out of the network, DHCP allows other clients to obtain an IP automatically as you would at home, and DNS allows for resolution of URLs such as google.com into 123.45.67.190 which can also be used to resolve hostnames internally.  NTP ensures that everyone is humming along at the same beat.  Your Asus or Nighthawk router and datacenters use Linux to route traffic every day and we’ll be using the same sort of technologies to deliver routing to our disconnected environment.

### Today’s use case

Let’s imagine you start with this sort of environment, maybe something like this...

<div class="row text-center">
{{< figure src="/images/posts/legacyUnsorted/20180930_184335-e1538450917443-768x1024.jpg" link="/images/posts/legacyUnsorted/20180930_184335-e1538450917443-768x1024.jpg" target="_blank" class="col-sm-12 col-md-4" >}}
{{< figure src="/images/posts/legacyUnsorted/20180930_184322-e1538450961695-768x1024.jpg" link="/images/posts/legacyUnsorted/20180930_184322-e1538450961695-768x1024.jpg" target="_blank" class="col-sm-12 col-md-4" >}}
{{< figure src="/images/posts/legacyUnsorted/20180930_184733-e1538451154605-768x1024.jpg" link="/images/posts/legacyUnsorted/20180930_184733-e1538451154605-768x1024.jpg" target="_blank" class="col-sm-12 col-md-4" >}}
</div>

What we have here is a 7-node Raspberry Pi 3 B+ cluster!

3 nodes have 2x) 32gb USB drives in them to support a 3-node replica Gluster cluster (it’s fucking magic!).  Then 3 other nodes are a part of a Kubernetes cluster, and the last RPi is the brains of the operation!

In order to get all these nodes talking to each other, we could set static IPs on every node and tell everyone where everyone else is at and call it a day.  In reality, though, no one does that and it’s a pain if not daunting.  So the last Raspberry Pi will offer DHCP, DNS, and NTP to the rest of the Kubernetes and Gluster clusters while also offering service as a wifi bridge and bastion host to the other nodes!  I’ve already got this running on Raspbian and have some workloads operating so I’ve recreated this lab in VirtualBox with a Virtual Internal Network and Red Hat Enterprise Linux.

## Step 1 – Configure Linux Router

Before we proceed, let’s go along with the following understandings of your Linux Router machine:


- Running any modern Linux, RHEL, Cumulus Linux, Raspbian, etc
- Has two network interface cards, we’ll call them eth0 and eth1:
  - WAN (eth0) – This is where you get the “internet” from.  In the RPi cluster, it’s the wlan0 wifi interface, in my RHEL VM it’s named enp0s3.
  - LAN (eth1) – This is where you connect the switch to that connects to the other nodes, or the virtual network that the VMs live in.  In my RHEL VM it’s named enp0s8.
- We’ll be using the network 192.168.69.0/24 on the LAN side (or netmask of 255.255.255.0 for those who don’t speak CIDR), and setting our internal domain to kemo.priv-int

I’m starting with a fresh RHEL VM here, so the first thing I want to do is jump into root and set my hostname for my router, update packages, and install the ones we’ll need.

{{< highlight bash >}}
$ sudo -i
$ hostnamectl set-hostname router.kemo.priv-int
$ yum update -y
$ yum install firewalld dnsmasq bind-utils
{{< /highlight >}}

Now that we’ve got everything set up, let’s jump right into configuring the network interface connections.  As I’m sure you all remember from your RHCSA exam prep, we’ll assign a connection to the eth1 interface to set up the static IP of the router on the LAN side and bring it up.  So assuming that your WAN on eth0 is already up (check with nmcli con show) and has a connection via DHCP, let’s make a connection for LAN/eth1 (my enp0s8)...

{{< highlight bash >}}
$ nmcli con add con-name lanSide-enp0s8 ifname enp0s8 type ethernet ip4 192.168.69.1/24 gw4 192.168.69.1
$ nmcli con modify lanSide-enp0s8 ipv4.dns 192.168.69.1
{{< /highlight >}}

Before we bring up the connection, let’s set up dnsmasq.  dnsmasq will serve as both our DNS and DHCP servers which is really nice!  Go ahead and open /etc/dnsmasq.conf with your favorite editor...

{{< highlight bash >}}
$ vi /etc/dnsmasq.conf
{{< /highlight >}}

And add the following lines:

{{< highlight bash >}}
# Bind dnsmasq to only serving on the LAN interface
interface=enp0s8
bind-interfaces
# Listen on the LAN address assigned to this Linux router machine
listen-address=192.168.69.1
# Upstream DNS, we're using Google here
server=8.8.8.8
# Never forward plain/short names
domain-needed
# Never forward addresses in the non-routed address space (bogon networks)
bogus-priv
# Sets the DHCP range (keep some for static assignments), and the lifespan of the DHCP leases
dhcp-range=192.168.69.100,192.168.69.250,12h
# The domain to append short requests to, all clients in the 192.168.69.0/24 subnet have FQDNs based on their hostname
domain=kemo.priv-int,192.168.69.0/24
local=/kemo.priv-int/
# Add domain name automatically
expand-hosts
{{< /highlight >}}

Annnd go ahead and save that file.

Now, on a RHEL/CentOS 7 machine, we have firewalld enabled by default so let’s make sure to enable those services.

{{< highlight bash >}}
$ firewall-cmd --add-service=dns --permanent
$ firewall-cmd --add-service=dhcp --permanent
$ firewall-cmd --add-service=ntp --permanent
$ firewall-cmd --reload
{{< /highlight >}}

Next, we’ll need to tell the Linux kernel to forward packets by modifying the /etc/sysctl.conf file and add the following line:

{{< highlight bash >}}
net.ipv4.ip_forward=1
{{< /highlight >}}

It might already be in the file but commented out, so simply remove the pound/hashtag in front and that’ll do.  Still, need to enable it though:

{{< highlight bash >}}
$ echo 1 > /proc/sys/net/ipv4/ip_forward
{{< /highlight >}}

Yep, almost set so let’s just bring up the network interface connection for eth1, set some iptable NAT masquerading and save it, and enable dnsmasq...

{{< highlight bash >}}
$ iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
$ iptables -A FORWARD -i enp0s3 -o enp0s8 -m state --state RELATED,ESTABLISHED -j ACCEPT
$ iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
$ firewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o enp0s3 -j MASQUERADE -s 192.168.69.0/24
$ iptables-save > /etc/iptables.ipv4.nat
$ nmcli con up lanSide-enp0s8
$ systemctl enable dnsmasq && systemctl start dnsmasq
{{< /highlight >}}

## Step 2 – Connect Clients & Test

So this part is pretty easy actually, you’ll just need to connect the clients/nodes to the same switch, or make a few other VMs in the same internal network.  Then you can check for DHCP leases with the following command:

{{< highlight bash >}}
$ tail -f /var/lib/dnsmasq/dnsmasq.leases
{{< /highlight >}}

And you should see the lease time, MAC address, associated IP, and client hostname listed for each connected client on this routed network!  We should be able to ping all those hostnames now too...

This is great, and we have many of the core components needed by a routed and switched network.  Our use case needs some very special considerations for time synchronization so we’ll use this same Linux router to offer NTP services to the cluster as well!

## Step 3 – Add NTP

Here most people would choose to use NTPd which is perfectly fine.  However, RHEL and CentOS (and many other modern Linux distros) come preconfigured with Chronyd which is sort of a newer, better, faster, stronger version of NTPd with some deeper integrations into systemd.  So today I’ll be using Chronyd to setup an NTP server on this Linux router.  Chronyd is also a bit better for disconnected environments, too.

Essentially, we just need to modify the /etc/chrony.conf and set the following lines:

{{< highlight bash >}}
stratumweight 0
local stratum 10
allow 192.168.69.0/24
{{< /highlight >}}

After that, enable NTP synchronization and restart with:

{{< highlight bash >}}
timedatectl set-ntp 1
systemctl restart chronyd
{{< /highlight >}}

And give that a moment to sync and you should have a fully functional network core based on simple Linux and a few packages!

## Next Steps

There are a few things that come to mind that you could do in this sort of environment...

- Create an actual GPS-based NTP Server – Be your own source!
- Set Static Host/IP Mappings – Make sure you have a section of IPs available that aren’t in the DHCP block to set the static IP reservations to.
- Create site-to-site VPNs – Tack on a bit of OpenVPN and we could easily create a secure site-to-site VPN to join networks or access other resources!
- Anything in your router’s web UI – Pretty much every router out there runs some sort of Linux embedded, and they’re all abstracting elements and functions that are primarily built-in and accessible to everyone.  Set up port-forwarding?  No problem. Add UPnP?  Not too hard either.
- Add PiHole Ad-Blocker – Maybe you’re using a Raspberry Pi as a wireless bridge to connect some hard wired devices on a switch to a wifi network.  Wouldn’t it be nice to block ads for all those connected devices?  You can with PiHole!
