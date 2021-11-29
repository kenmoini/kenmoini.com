---
title: "The Four Horsemen of Home Entertainment"
date: 2021-12-11T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/four-horsemen-home-entertainment.png
tags:
  - open source
  - oss
  - homelab
  - automation
  - radarr
  - sonarr
  - jackett
  - plex
authors:
  - Ken Moini
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

