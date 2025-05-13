---
title: Lab Basics - Architecture and Core
date: 2022-11-17T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/lab-basics-architecture.png
tags:
  - red hat
  - open source
  - oss
  - home lab
  - podman
  - rhel
  - ubi
  - docker
  - containers
  - devops
  - gitops
  - developer
  - kubernetes
  - openshift
  - lab
  - lab basics
  - architecture
  - core services
authors:
  - Ken Moini
---

> Kicking off a small series called "Lab Basics" to help maybe inspire some of you to get started with your own home lab with a look into how I do things.

Starting down the path of assembling your own home lab can be overwhelming - especially when you see people on [/r/home lab](https://reddit.com/r/home lab/) with their racks stacked to the max - *sometimes with Macs*.

I'm not going to tell you what sort of form-factor lab you should assemble, or with what sort of hardware vendors - that's for you to decide and everyone ends up having their own preferences.  There's no right or wrong way and the way you start off will probably change over time.

I will go into why I created my lab in the way I did, the evolution of it over time, and some common things to consider when you're going through the similar motions.  These common considerations are:

- **Network Architecture** - How you lay out your lab, connect it together, and also keep it separate from each other in a production/non-production sort of way
- **Name Services** - Primarily how do you manage your custom DNS zones and internal DNS resolution?
- **Remote Access** - Being able to access your lab from anywhere is a must
- **Ingress and Reverse Proxy** - How do you expose your lab services to your internal network and the internet?
- **PKI and SSL** - You'll need SSL certificates for services, it's much easier to manage your own Public Key Infrastructure (PKI) that you can trust than it is to make a bunch of one-off self-signed certificates
- **Centralized User Management** - Connecting to every system and setting up users and sudoers and groups and stuff is a pain - centralizing this is pretty important and easy to do
- **Monitoring** - The least sexy part of the lab, but also a very important one.  I don't go too crazy with monitoring and observability but a Grafana dashboard or two isn't bad to have
- **Core Services** - Across your lab you'll have a few services that will be considered core to its operation, such as DNS - you'll need a way to run those services in a lightweight manner that incurs minimal overhead with few dependencies.

---

## Network Architecture

Many people don't go any further past the default [Class C private network](https://en.wikipedia.org/wiki/Private_network#Private_IPv4_addresses) that their routers come preconfigured with - and 9 times out of 10 that's fine.

However, when it comes to home labs that will likely grow over time, it's best to start off investing a bit of time into planning things out so you can have a solid and scalable foundation to your networks.

The lab network hardware you pick can be more or less anything - I've done the DD-WRT bit, [pfSense](https://www.pfsense.org/) on a R210i/R620, and a few other things in between there and decided to go in on the [Unifi Dream Machine Pro](https://store.ui.com/products/udm-pro).  The Unifi ecosystem is not without its flaws, but for my application it's great - remote management, a unified experience as I push 10Gbit and 25Gbit networks with their purpose built ASIC-enabled network hardware, and the ability to customize it pretty well - set firewall rules, routes, VLANs, DHCP options, etc.  I use the Unifi kit for DHCP and Routing - DNS and other services are handled by containers running on a separate server.  Again, there's no right or wrong way to do this - you can use whatever you want, there are many people who are very successful in simply relying on pfSense/[opnsense](https://opnsense.org/) running on a server with an extra NIC attached.

I have a few VLANs set up and you may want to do the same - I separate out things by:

- **Default LAN**, `192.168.42.0/24` - When you connect to the main network on an unmanaged port without a VLAN tag, you get this network and DHCP is provided in the 192.168.42.100-250 range.  The non-DHCP range is where I host many of my core services like DNS, VPN, etc.  If I ever need to expand this network, I can simply increase the CIDR range to `192.168.42.0/23` and gain access to the addresses in the `192.168.43.0-254` range.
- **Wireless VLAN 40**, `192.168.40.0/24` - The ports on the UDM Pro router that connect to Wifi Access Points are tagged with this VLAN.  DHCP is provided in the 192.168.40.100-250 range.  Separating my wireless network from my wired network is useful for a few reasons: so I can have a separate DHCP range to quickly identify device interfaces, limit range exhaustion, and separate routes in case a device is connected via both a wired and wireless interface.
- **Lab LAN 44**, `192.168.44.0/23` - This subnet allows me to experiment and do things such as run services in parallel for testing or deploy devices without impacting the other subnets and thus the key things running in the Default LAN like the NAS and Plex...
- **Trusted IoT VLAN 39**, `192.168.39.0/24` - This is a separate VLAN for IoT devices on a specific SSID that I "trust enough" to have access to the internet - access to the other subnets is blocked.
- **Untrusted IoT VLAN 38**, `192.168.38.0/24` - This is a separate VLAN for IoT devices on a specific SSID that I do not trust whatsoever and do not allow access to any other networks internet or external.  This is handy for that off-brand local-storage NVR that you don't trust to "disable cloud access" on its own.
- **Management VLAN 46**, `192.168.46.0/24` - This VLAN provides a separate network for the out-of-band management interfaces of the different servers in the lab - this is where the iDRAC/IPMI interfaces are served from.  This Management VLAN is not allowed to access the internet, there's no real reason why my iDRAC interfaces should reach out to the internet.
- **OpenVPN VLAN 69**, `192.168.69.0/24` - When roaming OpenVPN clients connect to the server, they need a subnet to be addressed from.  This is that subnet and allows routed access to all the other subnets in the lab, but not from them - meaning if you're connected via the VPN as a client you can access all the other subnets but none of the other subnets are able to route to your OpenVPN client IP.
- **"Disconnected" VLAN 70**, `192.168.70.0/23` - There are cases when I need to isolate a set of devices from being able to access other networks unless I explicitly allow it, or such as through an outbound Squid proxy.  DHCP is served on from `192.168.71.100-250`, most of the subnet is used for static assignments.  This subnet is "disconnected" from the internet and the other subnets, with the exception of the router and proxy server - this is done via firewall rules on the router.

Do you need all the same networks?  Probably not - though, you probably at least want to segment things out a little bit beyond the default `192.168.0.1/24` network your WRT-56G came with.  Shoot, you may want to get even more wild and set up a storage VLAN for your Ceph or VSAN clusters.

---

## Name Services

Across all these subnets, you likely don't want to reference things via IP - eg, I named one of my servers `raza` and I can access the system's IP 192.168.42.45 via `raza.kemo.labs` and the IPMI interface with the IP of 192.168.46.45 via `raza.mgmt.kemo.labs`.

This is done via a DNS server that provides authoritative records for a domain zone, or few.

You can use a public domain like `your-awesome-lab.com` and pay the yearly fee for the registration of that publicly resolvable domain - the registrar often also provides free DNS services that you could leverage as well if you're ok with having your DNS records public.

Otherwise, you could alternatively host a private DNS server that provides authoritative records for any domain you'd like - for example I leverage `kemo.labs` as my private domain base.  The `.labs` TLD does not exist and is not publicly resolvable, so you have to be able to access the services in my lab in order to resolve the domain and likely the services the records point to.  I leverage delegated sub-zones such as `mgmt.kemo.labs` and `vpn.kemo.labs` to provide authoritative records for the different subnets in my lab.

Down the line you may actually end up using multiple domains - I use `kemo.labs` for private resources only available in my lab, then I have `kemo.network` used for things across my networks at large, and I can delegate a subdomain zone like `r53.kemo.network` to my AWS Route53 account for things that need API-based DNS record management like Let's Encrypt for DNS-01 challenges.

### Types of DNS Servers

Assuming you'll want to use a private domain, you'll need to host an **Authoritative DNS server**.  This is a DNS server that provides authoritative records for domain zones, considered to be the source of truth for the records it provides.

[This is different from a Recursive DNS server](https://umbrella.cisco.com/blog/what-is-the-difference-between-authoritative-and-recursive-dns-nameservers) - this is a type of DNS server that is used to query and resolve DNS records for a domain when requested by clients on the network.  Recursive DNS servers are often used to cache DNS records for faster resolution within a local boundary and reduces load on the networks and servers to and from the authoritative DNS servers.

- A Recursive DNS server will take a request from a client for a domain such as `app.example.com`
- It then queries the cached records it has for the record, if it has it, it returns it to the client
- If it does not have the record cached or if the cache expired, it will query the upstream recursive DNS server it is configured to use such as the Cloudflare/Google/OpenDNS/etc DNS servers that are often used for upstream resolution.

The upstream DNS servers often have a good idea of where you can find the authoritative DNS servers for the domain and record you're looking for.  It does so by:

- Querying the root DNS servers for the TLD of the domain - `.com` in this case
- The Root DNS servers return the authoritative DNS server for the `example.com` domain zone via the NS records
- It then queries the authoritative DNS server for the `example.com` domain zone for the `app.example.com` record and returns what it found to the client

You'll likely want to use multiple DNS servers - for instance, an authoritative DNS server for your private domains and their records, and a recursive DNS server like Pi-Hole that is configured to block domains for ad and malware servers.

In my lab, network clients are configured to query the authoritative DNS servers first, then if those servers don't have the records/zones, they forward the request to the recursive Pi-Hole DNS servers, which use OpenDNS as upstream DNS servers.
You could do this the other way where the clients query Pi-Hole, which queries the authoritative DNS servers, which then forwards requests to OpenDNS - but that could cause Pi-Hole to also cache my internal records and I do not want those cached.

---

## Remote Access

Odds are your home lab won't be entirely mobile, but you'll still want to access it remotely.  There are plenty of ways to do this and you'll probably want to leverage a few of them in case one becomes unavailable.  Personally, I use OpenVPN, ZeroTier, SSH, and the Teleport functionality in Unifi to access my lab remotely.

Primarily I use OpenVPN and haven't ever really needed to use the other options but they're there in case I ever mess up my OpenVPN server when doing some remote reconfiguration.  Works great out of a container and requires little configuration.

ZeroTier is a great option for a non-VPN VPN - it's more of an SD-WAN of sorts and requires a little less configuration than OpenVPN with its UDP magic that also helps circumvent anti-VPN measures that some ISPs and networks use.

---

## Ingress and Reverse Proxy

In my lab there are a lot of services being run - there are the classics such as DNS, more DNS, VPN, etc of course, but there are also other services such as [Radarr](https://radarr.video/), [Sonarr](https://sonarr.tv/), and [Deluge](https://deluge-torrent.org/) that are web-based services but run on funny ports that I can never remember.

So to solve for this issue I leverage an HAProxy container that is configured to listen on port 80 and 443 and reverse proxy requests to services running on other ports elsewhere.  This means I can simply navigate in my browser to `https://radarr.kemo.labs` and it will get me to the Radarr service - this also provides the added benefit of being able to secure all of my services with a single wildcard SSL certificate.

This same reverse proxying functionality can be used as a sort of ingress as well - this allows me to expose internal lab services such as [NextCloud](https://nextcloud.com/) to the internet.  The `cloud.kemo.network` domain points to one of my public IPs, my router forwards requests to that IP on port 80/443 to the HAProxy container, which then serves matching requests - I even leverage Let's Encrypt for publicly trusted SSL certificates on those sorts of public domains through the ingress.

---

## PKI and SSL

Almost every service you use will want to use SSL.  Most guides will have you creating a bunch of self-signed certificates and then using them to "secure" the service - while also telling everything to ignore SSL verification between clients/services because you're using a bunch of different self-signed certificates!

There's a better way to do this - you can create your own Certificate Authority (CA) which you can then add to your systems as a trusted Root CA.  Then the certificates signed by that CA will be trusted by your systems and you can use them to more properly secure your services.

You have many options for creating and managing a CA - there's Vault, some use FreeIPA, StepCA, and there's always manual steps and scripts.  I've found Vault and FreeIPA to be very opinionated and not flexible so I leverage a StepCA server for an ACME provider inside my lab and a manual set of scripts to create and manage certificates with the `openssl` CLI tool.

---

## Centralized User Management

With one server you may be able to manage things with local users and groups - as you scale the number of servers though this task becomes exponentially more difficult.  You'll want to provide a centralized user management store for your systems to use - this means that no matter what system you log in to your password is the same, things are dynamically updated, access controlled as a policy, and so on.  You can even leverage something like an NFS server for home directories that are mounted on login so your users files travel with them across systems.

You can leverage something like [FreeIPA](https://www.freeipa.org/page/Main_Page) to provide centralized user management to your various physical and virtual hosts - and even the services that run on them that can leverage LDAP for authentication.  You can then extend the LDAP authentication and directory services provided by FreeIPA with something like [Keycloak](https://www.keycloak.org/) to provide SSO for your various services via OAuth, OpenID Connect, and even other identity providers such as Google, GitHub, and other social providers.

---

## Monitoring

Dashboards and web pages full of charts are always cool to see and check out but horrible to build.  There's always some different DSL or QL to figure out, and then you have to figure out how to connect the monitoring stack together to the things that you want to monitor.

Thankfully these days it's not that bad if you want pretty standard out-of-the-box functionality, and that functionality is pretty solid.  You can use the stack of [Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/), [AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/), and [NodeExporter](https://prometheus.io/docs/guides/node-exporter/) to cover like 80% of your Linux/Kubernetes monitoring concerns.  There are even some community dashboards that interface with things such as [Unifi](https://grafana.com/grafana/dashboards/9390-unifi-controller-dashboard/) and [Pi-Hole](https://grafana.com/grafana/dashboards/5855-pi-hole/) that you can use to monitor those services.

---

## Core Services

If you're not relying on your router to provide all your services for you then you'll need something to run these workloads - some people use things like Raspberry Pis to run Pi-Hole and other lightweight services, personally though I find managing multiple small systems to be tiring and would rather have a single system that can run these services.

For my core service host I use a custom built AMD EPYC tower server called `raza` - it has Red Hat Enterprise Linux installed and subscribed via the free subscriptions provided by the [Red Hat Developer Susbscription](https://developers.redhat.com/articles/faqs-no-cost-red-hat-enterprise-linux).

### Raza Networking

Before getting to the services running on `raza` I'll go over how I have the networking set up - it's very simple...in the server I have an [Intel X520-DA2](https://www.ebay.com/itm/164412239275) NIC installed that is connected with a single [CableMatters DAC](https://www.amazon.com/gp/product/B071KWNFP3/) to the Unifi 16-XG.  This NIC is then bridged and other VLANs set on this bridge which has their own bridges created on those VLAN interfaces - KVM/Libvirt and Podman use these bridges to connect the containers/VMs to subnets routed by the core Unifi network.

{{< code lang="bash" line-numbers="true" >}}
## Create a bridge interface
nmcli connection add type bridge autoconnect yes con-name bridge0 ifname bridge0

## Configure the bridge interface with a static IP
BRIDGE_IP="192.168.42.40/24"
BRIDGE_GATEWAY="192.168.42.1"
BRIDGE_DNS_SERVER="192.168.42.9"
BRIDGE_DNS_SEARCH="kemo.labs"

nmcli connection modify bridge0 ipv4.addresses ${BRIDGE_IP} ipv4.method manual
nmcli connection modify bridge0 ipv4.gateway ${BRIDGE_GATEWAY}
nmcli connection modify bridge0 ipv4.dns ${BRIDGE_DNS_SERVER}
nmcli connection modify bridge0 ipv4.dns-search ${BRIDGE_DNS_SEARCH}

## Add the physical interface to the bridge
PHYSICAL_INTERFACE="enp1s0f0"

nmcli connection delete ${PHYSICAL_INTERFACE}
nmcli connection add type bridge-slave autoconnect yes con-name ${PHYSICAL_INTERFACE} ifname ${PHYSICAL_INTERFACE} master bridge0

## Bring up the bridge interface
nmcli connection up bridge0
{{< /code >}}

With this bridge I can get to the Default LAN in my lab, but I also want to make another set of interfaces so I can run containers and VMs that have interfaces from other VLANs such as my "disconnected" VLAN.

{{< code lang="bash" line-numbers="true" >}}
## Create a VLAN interface
nmcli connection add type vlan autoconnect yes con-name bridge0.70 ifname bridge0.70 dev bridge0 id 70

## Create a bridge interface for the VLAN
nmcli connection add type bridge autoconnect yes con-name bridge70 ifname bridge70

## Configure the bridge interface with a static IP in the VLAN
DISV70_BRIDGE_IP="192.168.70.40/24"
DISV70_BRIDGE_GATEWAY="192.168.70.1"
DISV70_BRIDGE_DNS_SERVER="192.168.42.9"
DISV70_BRIDGE_DNS_SEARCH="d70.lab.kemo.labs"

nmcli connection modify bridge70 ipv4.addresses ${DISV70_BRIDGE_IP} ipv4.method manual
nmcli connection modify bridge70 ipv4.gateway ${DISV70_BRIDGE_GATEWAY}
nmcli connection modify bridge70 ipv4.dns ${DISV70_BRIDGE_DNS_SERVER}
nmcli connection modify bridge70 ipv4.dns-search ${DISV70_BRIDGE_DNS_SEARCH}

## Add the VLAN interface to the bridge
nmcli connection delete bridge0.70
nmcli connection add type bridge-slave autoconnect yes con-name bridge0.70 ifname bridge0.70 master bridge70

## Bring up the bridge interface
nmcli connection up bridge70
{{< /code >}}

This sort of networking interface layout can be replicated for any number of VLANs that you want to have bridged interfaces for, across any number of physical hosts with like configurations.

### Raza Runtimes

There are two methods services are run on the Raza: with KVM/Libvirt VMs or with Podman.  Either way, the workloads can take IPs from the previously bridged interfaces.

{{< code lang="bash" line-numbers="true" >}}
## Install the needed services for Libvirt
yum -y module install virt
dnf install -y virt-viewer virt-install

## Enable Virtualization Kernel Mods
CPU_TYPE=$(cat /proc/cpuinfo | grep '^vendor_id' | head -n 1 | cut -d : -f 2 | awk '{$1=$1};1')

if [ "$CPU_TYPE" = "GenuineIntel" ]; then
  modprobe -r kvm_intel
  modprobe kvm_intel nested=1
  echo 'options kvm_intel nested=1' > /etc/modprobe.d/kvm_intel.conf
fi

if [ "$CPU_TYPE" = "AuthenticAMD" ]; then
  modprobe -r kvm_amd
  modprobe kvm_amd nested=1
  echo 'options kvm_amd nested=1' > /etc/modprobe.d/kvm_amd.conf
fi

echo 'options vfio_iommu_type1 allow_unsafe_interrupts=1' > /etc/modprobe.d/vfio.conf

## Install the needed services for Podman
dnf install -y podman podman-compose

## Start Libvirt
systemctl enable --now libvirtd

## Start Podman
systemctl enable --now podman.socket

## Create Libvirt Bridge Networks
cat <<EOF > /opt/libvirt-bridge0.xml
<network>
  <name>bridge0</name>
  <forward mode="bridge"/>
  <bridge name="bridge0"/>
</network>
EOF

cat <<EOF > /opt/libvirt-bridge70.xml
<network>
  <name>bridge70</name>
  <forward mode="bridge"/>
  <bridge name="bridge70"/>
</network>
EOF

## Define and start the Libvirt networks
virsh net-define /opt/libvirt-bridge0.xml
virsh net-define /opt/libvirt-bridge70.xml
virsh net-start bridge0
virsh net-start bridge70
virsh net-autostart bridge0
virsh net-autostart bridge70

## Create Podman networks
mkdir -p /etc/cni/net.d/

cat <<EOF > /etc/cni/net.d/bridge0.conflist
{
  "cniVersion": "0.4.0",
  "name": "bridge0",
  "plugins": [
      {
        "type": "bridge",
        "bridge": "bridge0",
        "ipam": {
            "type": "host-local",
            "ranges": [
                [
                    {
                        "subnet": "192.168.42.0/24",
                        "rangeStart": "192.168.42.2",
                        "rangeEnd": "192.168.42.250",
                        "gateway": "192.168.42.1"
                    }
                ]
            ],
            "routes": [
                {"dst": "0.0.0.0/0"}
            ]
        }
      },
      {
        "type": "portmap",
        "capabilities": {
            "portMappings": true
        }
      },
      {
        "type": "firewall",
        "backend": ""
      },
      {
        "type": "tuning",
        "capabilities": {
            "mac": true
        }
      }
  ]
}
EOF

cat <<EOF > /etc/cni/net.d/bridge70.conflist
{
  "cniVersion": "0.4.0",
  "name": "bridge70",
  "plugins": [
      {
        "type": "bridge",
        "bridge": "bridge70",
        "ipam": {
            "type": "host-local",
            "ranges": [
                [
                    {
                        "subnet": "192.168.70.0/24",
                        "rangeStart": "192.168.70.2",
                        "rangeEnd": "192.168.71.250",
                        "gateway": "192.168.70.1"
                    }
                ]
            ],
            "routes": [
                {"dst": "0.0.0.0/0"}
            ]
        }
      },
      {
        "type": "portmap",
        "capabilities": {
            "portMappings": true
        }
      },
      {
        "type": "firewall",
        "backend": ""
      },
      {
        "type": "tuning",
        "capabilities": {
            "mac": true
        }
      }
  ]
}
EOF
{{< /code >}}

> With that, the Raza is now ready to run containers and VMs to provide additional services to our lab.

Now that we have a host ready to run containers and VMs, we can start to add services to make the lab usable:

- DNS Services
- Rolling Your Own Certificate Authorities
- Identity Management
- Authentication and Authorization
- Remote Access
- Ingress & Reverse Proxying
- Monitoring

*Check back here for direct linking as they become available!*