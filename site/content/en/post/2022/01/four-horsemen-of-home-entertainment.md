---
title: "Movie Night Done Right"
date: 2022-01-22T04:20:47-05:00
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
  - jackett
  - plex
  - ubuntu
authors:
  - Ken Moini
---

> PLEX GO NOM NOM NOM

Today's exercise will be in getting Plex up and running with a few piratey pals - swabbing the deck will be Bazarr, Sonarr, Radarr, and Jackett.

Surprisingly enough, this time there are no containers being deployed - all installed into an Ubuntu VM.  So many transgressions in one article.

---

## Ubuntu VM Set Up

This part is pretty easy - just [download the Ubuntu ISO](https://ubuntu.com/download/server), install it onto your system or hypervisor however you'd like.

Once installed do the following:

- Install the latest updates: `sudo apt update && sudo apt upgrade -y`
- Install some helpful and/or needed packages: `sudo apt install -y cockpit ufw openssh-server nano unzip wget curl python3-dev python3-pip python3-distutils`
- Create a system group for Plex: `addgroup --gid 997 --system plex`
- Create a home directory for Plex: `mkdir -p /var/lib/plexmediaserver`
- Create a system user for Plex: `adduser --gid 997 --uid 997 --system --shell /usr/sbin/nologin --home /var/lib/plexmediaserver plex`

All the services will run with this Plex system group and user which will simplify file system permissions, which is also the same reason why I'm not running things in a set of containers, on top of it not playing nicely with how things are mounted from NFS shares.

In case you're also attaching a large NFS share for all your various media files, you can add something like the following to your `/etc/fstab` file:

```bash
## Create the directory to mount the NFS Share to
mkdir -p /mnt/Media

## Add the mount to the bottom of the /etc/fstab file
echo "nfs.example.com:/Media   /mnt/Media    nfs    rw,relatime   0   0" >> /etc/fstab

## Mount everything that isn't already mounted
mount -a
```

### Firewall Setup

Ubuntu uses `ufw` as the firewall compared to `firewalld` in RHEL-based systems - go ahead and setup the firewall requirements for the different services:

```bash
## Set all incoming to be denied by default
sudo ufw default deny incoming

## Allow Outgoing Connections
sudo ufw default allow outgoing

## Allow SSH Port
sudo ufw allow 22

## Allow Cockpit Port
sudo ufw allow 9090

## Allow Bazarr Port
sudo ufw allow 6767

## Allow Radarr Port
sudo ufw allow 7878

## Allow Sonarr Port
sudo ufw allow 8989

## Allow Jackett Port
sudo ufw allow 9117

## Allow Plex port
sudo ufw allow 32400

## Enable the Firewall
sudo ufw enable
```

---

## Jackett

### Installing Jackett

Another extremely easy thing to install - download the GitHub Release, extract, run.

```bash
cd /opt

wget https://github.com/Jackett/Jackett/releases/download/v0.20.68/Jackett.Binaries.LinuxAMDx64.tar.gz

tar zxvf Jackett.Binaries.LinuxAMDx64.tar.gz
rm Jackett.Binaries.LinuxAMDx64.tar.gz

chown -R plex:plex Jackett/

cd Jackett/

./install_service_systemd.sh

systemctl status jackett
```

### Set up Jackett Indexers

---

## Radarr

---

## Sonarr

---

## Bazarr

### Installing Bazarr

```bash
## Install needed packages
sudo apt-get install -y python3-dev python3-pip python3-distutils unzip wget

## Create the Bazarr directory and enter it
sudo mkdir -p /opt/bazarr
cd /opt/bazarr

## Download the latest Bazarr release
wget https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip

## Unzip Bazarr and remote the zip afterwards if successful
unzip bazarr.zip && rm bazarr.zip

## Install Python modules
sudo python3 -m pip install -r requirements.txt

## Set permissions
sudo chown -R plex:plex /opt/bazarr

## Create a SystemD Service Unit
sudo cat > /etc/systemd/system/bazarr.service<<EOF
[Unit]
Description=Bazarr Daemon
#After=syslog.target network.target
After=syslog.target network.target sonarr.service radarr.service

[Service]
WorkingDirectory=/opt/bazarr/
User=plex
Group=plex
UMask=0002
Restart=on-failure
RestartSec=5
Type=simple
ExecStart=/usr/bin/python3 /opt/bazarr/bazarr.py
KillSignal=SIGINT
TimeoutStopSec=20
SyslogIdentifier=bazarr
ExecStartPre=/bin/sleep 30

[Install]
WantedBy=multi-user.target
EOF

## Reload SystemD Units
sudo systemctl daemon-reload

## Start Bazarr
sudo systemctl enable --now bazarr
```

---

## Plex

