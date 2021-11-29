---
title: "OpenVPN Secured Deluge Client"
date: 2021-11-28T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/deluge-openvpn-client.png
tags:
  - homelab
  - vpn
  - openvpn
  - kill switch
  - secure
  - deluge
  - bittorrent
  - torrent
  - libvirt
  - kvm
  - qemu
  - plex
authors:
  - Ken Moini
---

> How to torrent all the bits

My old Plex Media Server was just an old Windows 7 system with Plex installed and a few other things such as Sonarr, Radarr, etc.  One of the services that fed the other services was a Deluge BitTorrent client that was running in a CentOS VM on that Windows 7 host.

Running Deluge as a separate VM has some benefits such as encapsulating all the traffic for that system to an OpenVPN server elsewhere - this is how to do exactly that.

## Prerequisite - Remote OpenVPN Server

If you don't already have an OpenVPN server you could do something like:

1. Get a $6/mo Fedora 35 VPS at OVH in Canada or something
2. Set `vpn.example.com` and `vpn-ca.example.com` A Record DNS entries pointing to that VPS
3. Run the following to set up an OpenVPN server:

```bash
## Update
sudo dnf update -y

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

## Create linux users for the OpenVPN Clients
useradd -s /bin/false -G openvpn -M vpnUser1
passwd vpnUser1
```

---

## Create a Local Deluge VM

I love putting things in containers but honestly it's just so much easier in a VM so just make a small 4GB 1Core VM and call it day - I choose to run Ubuntu 20.04 LTS.

***Note:***  It seems like the Ubuntu installer is unhappy with anything less than 4GB to install - after installation you can decrease the VM size down to 2GB of RAM.

---

## Out of the Box Configuration

Just some basic steps, updates and whatnot to get Deluge going as a [SystemD Service](https://deluge.readthedocs.io/en/latest/how-to/systemd-service.html):

```bash
## Switch to root
sudo -i

## Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6=1" > /etc/sysctl.d/99-disable-ipv6.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.d/99-disable-ipv6.conf
echo "net.ipv6.conf.lo.disable_ipv6=1" >> /etc/sysctl.d/99-disable-ipv6.conf
sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw
ufw disable

## Create a group and user for Deluge - UID/GID matched to typical Plex user values
groupadd --system -g 997 deluge
adduser --system -u 997 --gecos "Deluge Service" --disabled-password --group --home /var/lib/deluge deluge

## Add repos
add-apt-repository ppa:deluge-team/stable

## Update system software
apt update
apt upgrade -y

## Install needed packages
apt install -y nfs-common openvpn deluged deluge-web deluge-console

## Mount NFS Stores
NFS_HOST="deep-thought.kemo.labs"
NFS_SHARE="/Media"
MOUNT_PATH="/mnt/Media"

mkdir -p $MOUNT_PATH
cp /etc/fstab /etc/fstab.bak-$(date +%s)
echo "${NFS_HOST}:${NFS_SHARE}   ${MOUNT_PATH}    nfs    rw,relatime   0   0" >> /etc/fstab
mount -a

## Create logging directories
mkdir -p /var/log/deluge
chown -R deluge:deluge /var/log/deluge
chmod -R 750 /var/log/deluge

## Disable original init.d based deluged service
systemctl stop deluged
systemctl disable deluged

## Create a deluged Service
cat << EOF > /etc/systemd/system/deluged.service
[Unit]
Description=Deluge Bittorrent Client Daemon
Documentation=man:deluged
After=network-online.target

[Service]
Type=simple
UMask=007
User=deluge
Group=deluge
ExecStart=/usr/bin/deluged -d -l /var/log/deluge/daemon.log -L warning --logrotate
Restart=on-failure
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

## Create a Deluge Web UI Service
cat << EOF > /etc/systemd/system/deluge-web.service
[Unit]
Description=Deluge Bittorrent Client Web Interface
After=network-online.target

[Service]
Type=simple
User=deluge
Group=deluge
UMask=027
ExecStart=/usr/bin/deluge-web -d -l /var/log/deluge/web.log -L warning --logrotate
Restart=on-failure
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
EOF

## Reload SystemD
systemctl daemon-reload

## Enable the Deluge Daemon
systemctl enable --now deluged

## Enable the Deluge Web UI
systemctl enable --now deluge-web

## Reboot
systemctl reboot
```

Once the server has rebooted you should be able to access the Deluge Web UI at the IP of that VM at port 8112.

---

## Set Up OpenVPN - Client

For this set up we'll be routing all traffic on this Deluge VM through the OpenVPN interface and dropping any traffic that tries to communicate with the external Internet not via the VPN tunnel.

On the same Deluge VM, download the Client OpenVPN config file and set up a SystemD Client Service:

```bash
## Download the OpenVPN config file from wherever you have it - scp it over, etc
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

---

## [Optional] VPN Kill Switch

As an added bonus, let's configure a VPN Kill Switch - basically just using firewall rules to not allow communication with the wider Internet unless it's through the VPN tunnel.

The following assumes:

- The Deluge VM is on a local subnet of ***192.168.1.0/24***
- The Remote OpenVPN Server has a public IP of ***12.34.56.78***
- The tunnel interface is ***tun0***

```bash
## Allow traffic all around the local subnet
ufw allow in to 192.168.1.0/24
ufw allow out to 192.168.1.0/24

## Default deny traffic rules
ufw default deny outgoing
ufw default deny incoming

## Allow connections to the OpenVPN Server on the specific port/protocol
ufw allow out to 12.34.56.78 port 1194 proto udp

## Allow connections via the tunnel - confirm tunnel interface with `ip addr | grep inet`
ufw allow out on tun0 from any to any
ufw allow in on tun0 from any to any

## Enable the VPN Kill Switch
ufw enable

## Check the firewall rules
ufw status

## Test by starting/stopping the VPN tunnel
systemctl stop openvpn-client@client.service
ping 1.1.1.1
systemctl start openvpn-client@client.service
ping 1.1.1.1
```

---

## Basic Deluge & Web UI Configuration

Now that the VPN is setup and services are loaded and all, we can access the Deluge Web UI at the Deluge VM's IP address at port 8112, eg `http://192.168.1.123:8112/`

- The default password is `deluge` and you will be prompted to change it - this will open the **Preferences** modal under the **Interface** pane.  Also it is suggested to increase the Session Timeout.
- Set the download paths under the **Preferences > Downloads** pane, likely mounting some sort of NFS storage
- Disable bad protocols features such UPnP and DHT under the **Preferences > Network**
- Force Full Stream Encryption for at least Outgoing connections in **Preferences > Encryption**
- Increase the Maximum Connections and whatnot under **Preferences > Bandwidth**
- Allow Remote Connections to the Daemon under **Preferences > Daemon** to allow use with things such as Sonarr, Radarr, etc
- Set Queue limits under **Preferences > Queue**
- Enable optional Plugins under **Preferences > Plugins** such as AutoAdd, Label, and Scheduler - refresh your browser after adding/removing plugins
- Configure optional plugins

## Next Steps

That's about it - there's now a Deluge BitTorrent client running that is only able to reach the external Internet via an encrypted OpenVPN tunnel.  Add torrents to it manually via the Web UI at port 8112 or connect it to other clients such as Sonarr and Radarr for automated downloads!