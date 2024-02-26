---
title: "Plex n Pals"
date: 2024-02-17T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/movie-night-done-right.png
tags:
  - open source
  - oss
  - homelab
  - automation
  - media
  - movies
  - tv shows
  - radarr
  - sonarr
  - bazarr
  - overseerr
  - jackett
  - tautulli
  - sabnzbd
  - deluge
  - plex
  - fedora
authors:
  - Ken Moini
---

> PLEX GO NOM NOM NOM

So I recently got rid of the trash QNAP software on my NAS and replaced it with TrueNAS.  In the process, I had to offline my multimedia stack as well - but this has provided me an opportunity to retool my deployments and make it a little mo betta'.

Today's exercise will be in getting Plex up and running with a few swashbucklin' pals - swabbing the deck will be Bazarr, Sonarr, Radarr, Sabnzbd, Overseerr, Tautulli, Jackett, and Deluge.

Deluge will be run on a separate VM so that firewall rules can be applied to not allow traffic to the public Internet unless the VM maintains a VPN connection to a different VM/VPS.

Most of the services will be fronted by an HAProxy reverse proxy for easy access and SSL/TLS termination - and all while keeping SELinux enabled!

---

## Prerequisites

To get started you'll need a few things such as:

- A remote VM/VPS somewhere else to act as a OpenVPN Server - something like a VPS in OVH's Canadian data centers...
- 2 local VMs, one for the media stack and another for Deluge
- Static IP Addresses for those local VMs - for me they're:
  - **Plex VM**: 192.168.42.20 at plex.kemo.labs
  - **Deluge VM**: 192.168.42.24 at deluge.kemo.labs
- A set of DNS A records:
  - **plex.kemo.labs** > `192.168.42.20`
  - **jackett.kemo.labs** > `192.168.42.20`
  - **sonarr.kemo.labs** > `192.168.42.20`
  - **radarr.kemo.labs** > `192.168.42.20`
  - **bazarr.kemo.labs** > `192.168.42.20`
  - **overseerr.kemo.labs** > `192.168.42.20`
  - **sabnzbd.kemo.labs** > `192.168.42.20`
  - **tautulli.kemo.labs** > `192.168.42.20`
  - **deluge.kemo.labs** > `192.168.42.24`
  - **deluge-web.kemo.labs** > `192.168.42.20` - Note: This is correctly going to the Plex VM IP since we'll be using the HAProxy Reverse Proxy to access deluge-web.kemo.labs
- Shared storage - in my lab I'm using NFS shares.

---

## OpenVPN Server Setup

Before we start to deploy the local media services, we need a remote VM/VPS that's running an OpenVPN server.  This keeps our Deluge traffic secure and private.

Start out by getting a VM/VPS in some cloud - something like OVH: https://us.ovhcloud.com/vps/

I like their Canadian data centers because it's the closest to me.  I use the `VLE-2` VPS type with the latest version of Fedora - I like the VLE-2 because it provides 500Mbps of unmetered bandwidth, and that means I'll get about 200-250Mbps each way through the VPN tunnel.  Make sure you have a public DNS A record pointing to this VM.

With that you can run the following to get an OpenVPN Server, Cockpit, and Fail2ban setup quickly, along with an Nginx server using Let's Encrypt to serve things like the CA Cert and Client Configuration:

```bash
## Update
sudo dnf update -y

## Reboot
sudo systemctl reboot

## Install needed packages
sudo dnf install -y git nano wget curl ansible

## Clone the playbook
git clone https://github.com/kenmoini/ansible-openvpn-server.git
cd ansible-openvpn-server

## Set up a local inventory
echo "[all]" > inventory
echo "vpn.example.com ansible_connection=local ansible_user=fedora ansible_host=localhost" >> inventory

## Edit the variables where need be
nano vars/main.yaml

## Run the Playbook
ansible-playbook -i inventory configure.yaml

## Create linux users for the OpenVPN Client
sudo useradd -s /bin/false -G openvpn -M vpnUser1

## Set a password for the user
sudo passwd vpnUser1
```

On Fedora you'll need to disable the EPEL repo in the Ansible Playbook variables.  The `vpnUser1` account is what will be used on the Deluge VM to authenticate to the remote OpenVPN Server - of course feel free to change that.

---

## Infrastructure Basics

Now that the remote OpenVPN Server is set up, we can get our local resources up and running.  I'm deploying everything on a set of VMs that are running on my TrueNAS server, but you can use whatever to host the VMs.

- Start with two fresh Fedora 39 Server VMs
- Give the Plex VM a large disk to use for the library metadata, I provided a 300GB disk - the Deluge VM doesn't need much, I gave it 30GB
- Set their static IP and hostname
- When booted, do a fresh update and reboot: `dnf update -y && systemctl reboot`
- Add an NFS store pointing to your Media - this can easily be done through Cockpit via the `cockpit-storage` package if not already installed with `cockpit`.  If using TrueNAS, I set the owner/group of the Dataset to nobody/nogroup so Plex and the various services could access and see everything.  Probably a better way to do that, but it works for me.  Other shared storage options are available it's just that NFS is probably the easiest.

---

## Deluge Setup

Before we get started with the media stack, let's configure the Deluge VM since some things will need it as an endpoint to work against.  Thankfully the process is really simple in Fedora and more straightforward since the last time I wrote about it.

```bash
# Install Deluge
dnf install deluge -y

# Enable and start Deluge
systemctl enable --now deluge-daemon
systemctl enable --now deluge-web
```

With that you should be able to access the Web UI on port `:8112` - the default password is `deluge` and you'll be prompted to change that after the initial log in.

Once logged in, you can set some basic settings like:

- Set the download paths under the **Preferences > Downloads** pane, likely mounting some sort of NFS storage
- Disable bad protocols features such UPnP and DHT under the **Preferences > Network**
- Force Full Stream Encryption for at least Outgoing connections in **Preferences > Encryption**
- Increase the Maximum Connections and whatnot under **Preferences > Bandwidth**
- Allow Remote Connections to the Daemon under **Preferences > Daemon** to allow use with things such as Sonarr, Radarr, etc
- Set Queue limits under **Preferences > Queue**
- Enable optional Plugins under **Preferences > Plugins** such as AutoAdd, Label, and Scheduler - refresh your browser after adding/removing plugins
- Configure optional plugins

Next, you can configure some FirewallD rules and OpenVPN to secure the Deluge VM:

```bash
############################
# Prerequisites

# Disable IPv6 to prevent any "leakage"
echo "net.ipv6.conf.all.disable_ipv6=1" > /etc/sysctl.d/99-disable-ipv6.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.d/99-disable-ipv6.conf
sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

# Install OpenVPN and FirewallD
dnf install openvpn firewalld -y
```

With IPv6 disabled and the packages installed, it's important to establish VPN connectivity before locking things down:

```bash
############################
# Setup OpenVPN

## Download the OpenVPN config file from wherever you have it - scp it over, etc if you didn't enable the NGINX+Let's Encrypt deployment on the OpenVPN Server
wget -O /etc/openvpn/client/client.conf https://vpn.example.com/openvpn-base-client-config.ovpn

## Create a user/pass file if needed
echo "username" > /etc/openvpn/client/pass_file
echo "password" >> /etc/openvpn/client/pass_file

## Change the `auth-user-pass` line to `auth-user-pass /etc/openvpn/client/pass_file`
nano /etc/openvpn/client/client.conf

## Set Permissions
chmod 400 /etc/openvpn/client/*

## Enable and Start the Client Service
systemctl enable --now openvpn-client@client

## Check the status of the connection
systemctl status openvpn-client@client

## The following result should match your VPN Server IP Address once connected
curl ipinfo.io/ip
```

Executing the last `curl` command, you should see the IP of your OpenVPN Server returned.

However, if the VPN connection goes down, outbound traffic can still traverse the LAN out to the public Internet.  Ideally it would only maintain a connection to the Internet through the VPN tunnel - this is where a "VPN Killswitch" comes into play:

```bash
# Enable FirewallD
systemctl enable --now firewalld

# VPN Killswitch - largely thanks to https://meow464.neocities.org/blog/firewalld-vpn-killswitch/
# Create a new FirewallD Zone
firewall-cmd --permanent --new-zone vpn

# Set the default to drop packages
firewall-cmd --permanent --zone vpn --set-target DROP

# Create a new Policy
firewall-cmd --permanent --new-policy vpn-tunnel

# Set the Policy default to drop packages too
firewall-cmd --permanent --policy vpn-tunnel --set-target DROP

# Add the public interface to the Zone
firewall-cmd --permanent --zone vpn --add-interface=ens3

# Allow services and ports on this new Zone
firewall-cmd --permanent --zone vpn --add-service=ssh
firewall-cmd --permanent --zone vpn --add-service=cockpit
firewall-cmd --permanent --zone vpn --add-port=8112/tcp

# Reload Firewalld - needed to make the Policy active
firewall-cmd --reload

# Allow connections to the OpenVPN server from the public IP it's listening on
# Change 1.2.3.4 to the IP of your OpenVPN Server
firewall-cmd --policy vpn-tunnel --add-rich-rule='rule family="ipv4" destination address="1.2.3.4" service name="openvpn" accept'

# Allow connections from the local LAN as well
# Make sure to change 192.168.0.0/16 to match the LAN your Deluge VM is on
firewall-cmd --policy vpn-tunnel --add-rich-rule='rule family="ipv4" destination address="192.168.0.0/16" accept'

# Set ingress and egress targets
firewall-cmd --policy vpn-tunnel --add-ingress-zone HOST
firewall-cmd --policy vpn-tunnel --add-egress-zone vpn

# Make the policy configuration permanent
firewall-cmd --runtime-to-permanent
```

With that you should be able to disable the VPN with `systemctl stop openvpn-client@client` and do a `ping 1.1.1.1` or `curl https://google.com` and see it fail - when you start the OpenVPN client again with `systemctl start openvpn-client@client` then you can also re-run those `ping` and `curl` commands to check that the tunnel is operating properly.

## Plex VM and Media Stack

Now that we have our VPN tunnel set up, we can bring online the media stack

### Plex Media Server Installation

Switch over to the Plex VM and set up a few things - make sure to get the link to the latest Plex Media Server download here: https://www.plex.tv/media-server-downloads/?cat=computer&plat=linux#plex-media-server

```bash
# Download the Plex Media Server RPM
wget -O plexmediaserver.rpm https://downloads.plex.tv/plex-media-server-new/1.32.8.7639-fb6452ebf/redhat/plexmediaserver-1.32.8.7639-fb6452ebf.x86_64.rpm

# Install the RPM
rpm -iv plexmediaserver.rpm

# Add firewall rules for Plex
firewall-cmd --permanent --add-port=32400/tcp
firewall-cmd --permanent --add-port=1900/udp
firewall-cmd --permanent --add-port=5353/udp
firewall-cmd --permanent --add-port=8324/tcp
firewall-cmd --permanent --add-port=32410/udp
firewall-cmd --permanent --add-port=32412-32414/udp
firewall-cmd --permanent --add-port=32469/tcp
firewall-cmd --reload
```

The Plex Media Server should automatically start once installed, and it will install an RPM Repo so you can simply update via a `dnf update`.

Access the Plex Media Server interface at `:32400/web/` - perform the out-of-the-box install, and setup the Libraries pointing to the shared NFS mount.

### Media Stack with Podman Compose

With Plex running we'll run the rest of the services via containers running with Podman Compose - yes, I know you can also run the Plex Media Server as a container, however in the past I've had issues with persistence and around upgrades.  *This just makes things simpler, for me anyways...*

```bash
# Install Podman, Podman Compose, and the Cockpit plugin
dnf install podman cockpit-podman podman-compose -y

# Enable Cockpit if not already done so
systemctl enable --now cockpit.socket

# Enable Podman
systemctl enable --now podman.socket
```

With the services installed and running, we can now run some preliminary work to set up the container environment:

```bash
# Make data directories
mkdir -p /opt/media-services/data/{jackett-config,jackett-blackhole,radarr-config,sonarr-config,bazarr-config,overseer-config,sabnzbd-config,tautulli-config,ingress-config,ingress-certs}

# SELinux things
semanage fcontext -a -t container_file_t '/opt/media-services/data/jackett-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/jackett-blackhole'
semanage fcontext -a -t container_file_t '/opt/media-services/data/radarr-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/sonarr-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/bazarr-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/overseerr-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/sabnzbd-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/tautulli-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/ingress-config'
semanage fcontext -a -t container_file_t '/opt/media-services/data/ingress-certs'

# Apply the contexts
restorecon -v '/opt/media-services/data/*'
```

Now that the directories for persistence and some SELinux contexts have been set, we can create the Podman Compose file - somewhere like `/opt/media-services/podman-compose.yml`:

```yaml
---
version: '3'
services:
#######################################################################
# Jackett - https://docs.linuxserver.io/images/docker-jackett/
  jackett:
    image: lscr.io/linuxserver/jackett:latest
    container_name: jackett
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - AUTO_UPDATE=true #optional
      - RUN_OPTS= #optional
    volumes:
      - /opt/media-services/data/jackett-config:/config
      - /opt/media-services/data/jackett-blackhole:/downloads
    ports:
      - 9117:9117
    restart: unless-stopped
#######################################################################
# Radarr - https://docs.linuxserver.io/images/docker-radarr/
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/media-services/data/radarr-config:/config
      - /mnt/Media/Movies:/movies #optional
      - /mnt/Media/deluge/complete:/downloads #optional
    ports:
      - 7878:7878
    restart: unless-stopped
#######################################################################
# Sonarr - https://docs.linuxserver.io/images/docker-sonarr/
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/media-services/data/sonarr-config:/config
      - /mnt/Media/TVShows/TVShows:/tv #optional
      - /mnt/Media/deluge/complete:/downloads #optional
    ports:
      - 8989:8989
    restart: unless-stopped
#######################################################################
# Bazarr - https://docs.linuxserver.io/images/docker-bazarr/
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/media-services/data/bazarr-config:/config
      - /mnt/Media/Movies:/movies #optional
      - /mnt/Media/TVShows/TVShows:/tv #optional
    ports:
      - 6767:6767
    restart: unless-stopped
#######################################################################
# Overseerr - https://docs.linuxserver.io/images/docker-overseerr/
  overseerr:
    image: lscr.io/linuxserver/overseerr:latest
    container_name: overseerr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/media-services/data/overseerr-config:/config
    ports:
      - 5055:5055
    restart: unless-stopped
#######################################################################
# Sabnzbd - https://docs.linuxserver.io/images/docker-sabnzbd/
  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:latest
    container_name: sabnzbd
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/media-services/data/sabnzbd-config:/config
      - /mnt/Media/sabnzbd/complete:/downloads #optional
      - /mnt/Media/sabnzbd/incomplete:/incomplete-downloads #optional
    ports:
      - 8080:8080
    restart: unless-stopped
#######################################################################
# Tautulli - https://docs.linuxserver.io/images/docker-tautulli/
  tautulli:
    image: lscr.io/linuxserver/tautulli:latest
    container_name: tautulli
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - /opt/media-services/data/tautulli-config:/config
    ports:
      - 8181:8181
    restart: unless-stopped
#######################################################################
# HAProxy
  haproxy:
    image: docker.io/haproxy:latest
    container_name: haproxy
    cap_add:
      - NET_BIND_SERVICE
    environment:
      - TZ=America/New_York
    volumes:
      - /opt/media-services/ingress-config:/usr/local/etc/haproxy
      - /opt/media-services/ingress-certs:/usr/local/etc/certs
    ports:
      - 80:80
      - 443:443
    restart: unless-stopped
```

That Podman Compose file will manage the rest of our services: Jackett, Radarr, Sonarr, Bazarr, Overseerr, Sabnzbd, Tautulli, and our Reverse Proxy Ingress.

Yes, you could access all the services at their specific ports without the ingress, but I often forget what ports do what, and it's much easier to have service names for access that are secured with TLS/SSL.

### SSL/TLS Setup

Speaking of TLS/SSL, before we start the services we need to set up a little bit of configuration - first, let's create the SSL certificate that will secure all our services:

```bash
# Navigate to the Ingress Certificate path
cd /opt/media-services/ingress-certs

# Set the wildcard base domain for all services
WILDCARD_DOMAIN='*.kemo.labs'

# Generate a Key
openssl genrsa -out server.key.pem 4096

# Create a Certificate Signing Request
openssl req -new -key server.key.pem -out server.csr.pem -subj "/C=US/ST=California/L=Los Angeles/O=IT/CN=${WILDCARD_DOMAIN}"

# Self-sign the certificate
openssl x509 -req -days 365 -in server.csr.pem -signkey server.key.pem -out server.cert.pem

# Concatenate the key and certificate into a bundle for HAProxy to use
cat server.key.pem server.cert.pem > haproxy-bundle.pem
```

Now that's not the best SSL chain, it's a wholely self-signed certificate - but it works unless you want to roll your own PKI (which I think is a good idea).  Make sure to download/`scp` over the `server.cert` file to your systems and add it to your trusted root store.