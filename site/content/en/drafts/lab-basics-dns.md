---
title: Lab Basics - DNS Mastery
date: 2022-11-18T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/lab-basics-dns.png
tags:
  - red hat
  - open source
  - oss
  - homelab
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
  - dns
  - zones
  - bind
  - named
  - dnsmasq
  - gozones
authors:
  - Ken Moini
---

> Of course I couldn't kick off a series on "Lab Basics" without first talking about DNS.

There are multiple types of DNS servers that do different yet similar things and talk to each other in and out of authoritative and recursive resolution of records.

In many labs you'll find people get started with messing with DNS by introducing something like [Pi-Hole](https://pi-hole.net/) to their networks.  Pi-Hole lets you block network requests to known bad domains such as ad networks, malware, and other nefarious domains.  Essentially it acts as a local recursive DNS server that will resolve and cache requests - if a request matches a known bad domain, it will return a `NXDOMAIN` response to the client, thus terminating the network request in most cases.

Pi-Hole can also act as a DHCP server, provide some limited functionality for serving custom records, but it's not very flexible - it does blocking of domains exceptionally well, but you'll find the need for another more authoritative DNS server to provide records for your lab.

In my lab I use something called [Go-Zones](https://github.com/kenmoini/go-zones) - it takes in a YAML file defining the Zone(s) and their records, creates the needed BIND/named configuration and zone files, then serves them up in a container.  It's very simple, lightweight, and easy to use.

## Mapping DNS Services



## Deploying Pi-Hole

You can deploy Pi-Hole in a number of different ways, some decide to run it on a dedicated Raspberry Pi, others run it as a VM - I suggest running it as a container.

You can leverage the [Ansible Automation provided by this repo](https://github.com/kenmoini/lab-pihole), or you can run it manually:

{{< code lang="bash" line-numbers="true" >}}
# Create a Service Unit file
cat <<EOF > /etc/systemd/system/pihole.service
[Unit]
Description=Pi-Hole Container
After=network-online.target
Wants=network-online.target

[Service]
ExecStop=/opt/consvc/pihole/scripts/servicectl.sh stop
ExecStart=/opt/consvc/pihole/scripts/servicectl.sh start
ExecReload=/opt/consvc/pihole/scripts/servicectl.sh restart

TimeoutStartSec=300
Type=forking
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

## Create the control scripts
mkdir -p /opt/consvc/pihole/scripts
mkdir -p /opt/consvc/pihole/volumes/etc-pihole
mkdir -p /opt/consvc/pihole/volumes/etc-dnsmasq.d

cat <<EOF > /opt/consvc/pihole/scripts/servicectl.sh
#!/bin/bash

set -x

export CONTAINER_NAME="pihole"

###################################################################################
# EXECUTION PREFLIGHT
###################################################################################

## Ensure there is an action arguement
if [ -z "$1" ]; then
  echo "Need action arguement of 'start', 'restart', or 'stop'!"
  echo "${0} start|stop|restart"
  exit 1
fi


################################################################################### SERVICE ACTION SWITCH
case $1 in

  ################################################################################# RESTART/STOP SERVICE
  "restart" | "stop" | "start")
    echo "Stopping container services if running..."

    echo "Stopping ${CONTAINER_NAME} container..."
    /usr/bin/podman kill ${CONTAINER_NAME}

    echo "Removing ${CONTAINER_NAME} container..."
    /usr/bin/podman rm -f -i ${CONTAINER_NAME}
    ;;

esac

case $1 in

  ################################################################################# RESTART/START SERVICE
  "restart" | "start")
    sleep 3

    echo "Starting container services..."

    # Deploy ${CONTAINER_NAME} container
    echo -e "Deploying ${CONTAINER_NAME}...\n"

    /usr/bin/podman create \
      --name ${CONTAINER_NAME} \
      --hostname pihole \
      --network bridge0 \
      --ip 192.168.42.10 \
      -e ServerIP=192.168.42.10 \
      -e VIRTUAL_HOST=pi-hole.example.com \
      -e ADMIN_EMAIL=you@example.com \
      -e WEBPASSWORD=yourPasswordHere \
      -p 53/tcp -p 80/tcp -p 443/tcp \
      -e PIHOLE_DNS_=1.1.1.1;1.0.0.1 \
      -e TEMPERATUREUNIT=f \
      -e TZ=America/New_York \
      -e PIHOLE_UID=0 \
      -e DNSMASQ_USER=root \
      -m 1g --cpus 1 \
      -v "/opt/consvc/pihole/volumes/etc-pihole:/etc/pihole:z" \
      -v "/opt/consvc/pihole/volumes/etc-dnsmasq.d:/etc/dnsmasq.d:z" \
      docker.io/pihole/pihole:latest

    /usr/bin/podman start ${CONTAINER_NAME}

    ;;

esac
EOF
{{< /code >}}