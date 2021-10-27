---
title: "Secure Homelab Ingress with HAProxy and Let's Encrypt"
date: 2021-10-09T04:20:47-05:00
draft: false
toc: false
listed: true
aliases:
    - /blog/homelab-haproxy-ingress-with-letsencrypt/
hero: /images/posts/heroes/resized/resized-homelab-ingress.png
tags:
  - homelab
  - haproxy
  - let's encrypt
  - certbot
  - ssl
  - nginx
  - httpd
  - containers
  - docker
  - docker hub
  - podman
  - automation
  - devops
authors:
  - Ken Moini
---

> ***When did the Honey-Do list get so technical?***

Recently I've built a new NAS, and before I could even transfer my own data over it was already being claimed for other uses.

One of these uses was for a place where we could upload and share files, sort of like a private Dropbox of sorts.  So I chose the [NextCloud](https://nextcloud.com/) platform for that which so far so good I guess.

Now, in my lab I have my own DNS serving a private internal TLD that isn't routable anywhere else - normally my VPN is how I access the resources from other networks.

The audience at hand might not have been happy with the operational requirements of accessing things via a VPN so I needed to expose this service somehow and do so decently securely - this is a step-by-step of how I did that with a few containers running HAProxy, Nginx, and Let's Encrypt.

## External Network Setup

### Domain Registration

First thing is I needed a publically routable domain - meaning something you get from like NameCheap or something.  For this I have my personal domain, `kenmoini.com`

### Set Domain's Name Servers

With the domain registered, I could now specify which Authoritiative Name Servers host the domain zone file - meaning who is the DNS provider.  This could be something like AWS Route53 or even the usually free DNS service offered by most domain registrars - personally I'm using the DigitalOcean DNS service which is where I generally keep my DNS managed since it's pretty responsive, has a nice API, and allows wildcards which oddly enough isn't allowed by every provider...

So in my case, I tell Namecheap that DigitalOcean's nameservers `ns{1..3}.digitalocean.com` are serving the domain zone.  With that, it's time to go setup the domain zone and configure some DNS records.

### Setup DNS Records

Wherever you're managing your DNS zone file and the records it houses, in my case DigitalOcean, you'll want to:

1. Create a Zone, often just a process of 'adding the domain' to the DNS service
2. Create a few ***A records***, in my case it was:
  - `nextcloud.kenmoini.com` with a value pointing to my lab external IP
  - `lab-apps.kenmoini.com` with a value pointing to my lab external IP
  - `*.lab-apps.kenmoini.com` with a value pointing to my lab external IP

With those 3 services I can direct people on the public Internet to the NextCloud instance I serve here locally in my lab, a landing page (`lab-apps`) of other applications and services offered, and then a wildcard subdomain of that (`*.lab-apps`) to easily redirect any other applications I want to expose in my lab without having to make a new A record for each of them.

## Internal Network Setup

### Reserve an IP for the Ingress Pod

So there are a few containers that are going to be run via [Podman](https://podman.io/), most of them in a Pod and this Pod needs an IP address, ideally a static IP address - in my network my DHCP server serves `192.168.42.100-250`, which means that I just manage the IPs at `192.168.42.2-99`.  For my network I chose to set reserved IPs and DNS for the Ingress Pod set to `192.168.42.28`

### Set Firewall Rules

With the domain and DNS in place, we are technically able to route traffic to the internal network however with any semi-decent router you'll have a basic firewall in place - for my network I just told my Unifi Dream Machine Pro to route ports `443`, `80`, and `8080` to the Ingress Pod IP at `192.168.42.28`.

## Podman Setup

So you could run this on Docker, or if you don't want to worry about some bullshit license changes and proprietary shit daemons running on your system you may want to look at [Podman](https://podman.io/).

You can install Podman and the variety of companion tools with the following command on a RHEL-based system:

```bash
sudo dnf install -y podman buildah skopeo
```

### Podman Networking

So the default Podman network is based on NAT - I use a Bridged network via macvlan to pipe IPs from my main routed network directly to my Pods.  You can do the same with the following configuration:

```json
{
  "cniVersion": "0.4.0",
  "name": "{{ bridgeName }}",
  "plugins": [
      {
        "type": "bridge",
        "bridge": "{{ bridgeDevice }}",
        "ipam": {
            "type": "host-local",
            "ranges": [
                [
                    {
                        "subnet": "{{ bridgeSubnet }}",
                        "rangeStart": "{{ bridgeRangeStart }}",
                        "rangeEnd": "{{ bridgeRangeEnd }}",
                        "gateway": "{{ bridgeGateway }}"
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
```

Just make sure to change out everything in the double squiggly-brackets, such as `{{ bridgeName }}` and so on - I use the following configuration saved at `/etc/cni/net.d/lanBridge.conflist`:

```json
{
  "cniVersion": "0.4.0",
  "name": "lanBridge",
  "plugins": [
      {
        "type": "bridge",
        "bridge": "containerLANbr0",
        "ipam": {
            "type": "host-local",
            "ranges": [
                [
                    {
                        "subnet": "192.168.42.0/24",
                        "rangeStart": "192.168.42.2",
                        "rangeEnd": "192.168.42.245",
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
```

## Deploying the Pod

Let's create a few directories on our container host:

```bash
mkdir -p /opt/service-containers/ingress/{scripts,nginx-templates,haproxy,webroot,certs}
```

I like to use SystemD to run my container services and ensure they're run at boot and so on.  Let's start with the actual service unit file:

#### /etc/systemd/system/caas-ingress.service

```ini
[Unit]
Description=Homelab Ingress
After=network-online.target
Wants=network-online.target

[Service]
TimeoutStartSec=15
ExecStop=/opt/service-containers/ingress/scripts/service_stop.sh
ExecStart=/opt/service-containers/ingress/scripts/service_start.sh

Type=forking
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

With that SystemD unit file in place you can run `systemctl daemon-reload` to make it accessible - however you'll note that the start and stop scripts still haven't been made yet.

#### /opt/service-containers/ingress/scripts/service_stop.sh

```bash
#!/bin/bash

set -x

source /opt/service-containers/ingress/scripts/service_vars.sh

echo "Killing container..."
/usr/bin/podman pod kill $POD_NAME

echo "Removing container..."
/usr/bin/podman pod rm $POD_NAME -f -i
```

All that script does is source a shared variable file then stop and remove a named Pod.

***Let's take a look at the shared variable file to see what else we're working with...***

#### /opt/service-containers/ingress/scripts/service_vars.sh

```bash
#!/bin/bash

POD_NAME="ingress"
NETWORK_NAME="lanBridge"
IP_ADDRESS="192.168.42.28"
CONTAINER_PORTS="-p 80/tcp -p 443/tcp -p 8080/tcp"
RESOURCE_LIMITS="-m 2048m"

POD_VOLUME_ROOT="/opt/service-containers/${POD_NAME}"

HAPROXY_CONTAINER_IMAGE="haproxy:latest"
NGINX_CONTAINER_IMAGE="nginx:latest"

HAPROXY_VOLUME_MOUNTS="-v ${POD_VOLUME_ROOT}/haproxy:/usr/local/etc/haproxy:ro -v ${POD_VOLUME_ROOT}/certs:/usr/local/etc/certs:ro"
NGINX_VOLUME_MOUNTS="-v ${POD_VOLUME_ROOT}/webroot:/usr/share/nginx/html -v ${POD_VOLUME_ROOT}/nginx-templates:/etc/nginx/templates"
```

A few key points...

- `POD_NAME` is just the name of the Pod holding all the containers and the prefix applied to the container names
- `NETWORK_NAME` is the name of the Podman network (not the filename, the `.name` in the JSON spec
- `IP_ADDRESS` is the static IP address being assigned to the Pod
- `CONTAINER_PORTS` are just the ports being exposed
- `RESOURCE_LIMITS` so things can't run errant
- `POD_VOLUME_ROOT` provides a base directory for other references
- `HAPROXY_CONTAINER_IMAGE` provides the source of the HAProxy image...ideally you'd have this mirrored so that you don't have to rely on Docker Hub and their dumb pull limits...
- `NGINX_CONTAINER_IMAGE` is just a regular ol' Nginx image really - I should change this to a Red Hat UBI-based one soon...
- `HAPROXY_VOLUME_MOUNTS` will define the directories with the HAProxy configuration and certificates mounted to the HAProxy container
- `NGINX_VOLUME_MOUNTS` provides the directories that Nginx needs to serve the HTTP01 responses for the Certbot container

***These variables are provided to the `service_start.sh` script as such...***

#### /opt/service-containers/ingress/scripts/service_start.sh

```bash
#!/bin/bash

set -x

source /opt/service-containers/ingress/scripts/service_vars.sh

${POD_VOLUME_ROOT}/scripts/service_stop.sh

sleep 3

echo "Checking for stale network lock file..."
FILE_CHECK="/var/lib/cni/networks/${NETWORK_NAME}/${IP_ADDRESS}"
if [[ -f "$FILE_CHECK" ]]; then
    rm $FILE_CHECK
fi

rm nohup.out

## Check for seeded certificate
if [[ ! -f ${POD_VOLUME_ROOT}/certs/default.pem ]]; then
  sh ${POD_VOLUME_ROOT}/seed-cert.sh
fi

# Create Pod and deploy containers
echo -e "Deploying Pod...\n"
podman pod create --name "${POD_NAME}" --network "${NETWORK_NAME}" --ip "${IP_ADDRESS}" ${CONTAINER_PORTS}

sleep 3

# Deploy Nginx
echo -e "Deploying Nginx...\n"
nohup podman run -dt --pod "${POD_NAME}" ${NGINX_VOLUME_MOUNTS} -e "NGINX_PORT=8080" --name "${POD_NAME}-nginx" $NGINX_CONTAINER_IMAGE

sleep 3

# Deploy HAProxy
echo -e "Deploying HAProxy...\n"
nohup podman run -dt --sysctl net.ipv4.ip_unprivileged_port_start=0 --pod "${POD_NAME}" ${HAPROXY_VOLUME_MOUNTS} --name "${POD_NAME}-haproxy" $HAPROXY_CONTAINER_IMAGE
```

Something to note there is the `-e NGINX_PORT=8080` environmental variable definition provided to the Nginx container - this is passed to a Template that's defined as such:

#### /opt/service-containers/ingress/nginx-templates/default.conf.template

```config
server {
    listen       ${NGINX_PORT};
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
```

This just changes the port of the Nginx container to 8080 so that it doesn't conflict with the HAProxy port 80 - you can extend this to additionally apply other Nginx configuration options.

***Now we need to create our HAProxy configuration...***

#### /opt/service-containers/ingress/haproxy/haproxy.cfg

```config
global
  log stdout format raw local0
  daemon

  # Default ciphers to use on SSL-enabled listening sockets.
  # For more information, see ciphers(1SSL).
  ssl-default-bind-ciphers kEECDH+aRSA+AES:kRSA+AES:+AES256:RC4-SHA:!kEDH:!LOW:!EXP:!MD5:!aNULL:!eNULL

defaults
  log     global
  mode    http
  option  httplog
  option  dontlognull
  timeout connect 10s
  timeout client 30s
  timeout server 30s

frontend http
  bind *:80
  mode http
	
  # if this is an ACME request to proof the domain ownder, then redirect to nginx-certbot server
  acl is_well_known path_beg -i /.well-known/
  use_backend letsencrypt if is_well_known
	
  # else redirect the traffic to https
  redirect scheme https code 301 if !is_well_known !{ ssl_fc }

frontend https
  bind *:443 ssl crt-list /usr/local/etc/haproxy/crt-list.cfg
  http-response set-header Strict-Transport-Security "max-age=16000000; includeSubDomains; preload;"

  acl host_cloud hdr(host) -i nextcloud.kenmoini.com
  
  use_backend nextcloud if host_cloud

  default_backend mybackend

backend letsencrypt
  server letsencrypt 192.168.42.28:8080 check init-addr none

backend mybackend
  server backend1 172.17.0.1:5000
  http-request add-header X-Forwarded-Proto https if { ssl_fc }

backend nextcloud
  server nextcloud1 192.168.42.25:80
  acl url_discovery path /.well-known/caldav /.well-known/carddav
  http-request redirect location /remote.php/dav/ code 301 if url_discovery
  http-request add-header X-Forwarded-Proto https if { ssl_fc }
```

This HAProxy configuration does a few things:

- Sets global and default configuration
- Defines the HTTP frontend that it will listen on at port 80.  There is an ACL that is defined if the request path beings with `/.well-known/` which is used to redirect to the backend called letsencrypt, which is actually just Nginx on port 8080 with the proper directories piped in and out of it and the certbot container.
- Defines the HTTPS frontend that will terminate SSL for us with the crt-list of certificates and matching domains.  There is an ACL that will match based on the request host being `nextcloud.kenmoini.com` and redirect to the nextcloud backend.
- Defines three backends, one for letsencrypt (the Nginx container), another one for a default mybackend service, and the last for nextcloud with a few extra ACL definitions that allow NextCloud to run properly.

The crt-list is just a text file that looks something like this:

#### /opt/service-containers/ingress/haproxy/crt-list.cfg

```text
/usr/local/etc/certs/default.pem
```

The first line is a default certificate for any unmatched SSL Termination requests.  The following lines should be a path to a certificate file, the capabilities, and the domain to match.

You can create the default.pem certificate file with something like this:

#### /opt/service-containers/ingress/seed-certificate.sh

```bash
#!/bin/bash

openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -keyout default.key -out default.crt

cat default.key default.crt > ./certs/default.pem

rm default.key default.crt
```

Run that, providing a wildcard `*` as the Common Name when prompted.

Next we'll need some way to generate certificates for our own domains, such as the `nextcloud.kenmoini.com` domain - this is where Certbot comes into play.  Before we generate certificates we need the Pod running so let's do that:

```bash
systemctl start caas-ingress
```

With the Pod started we can create a new certificate for the different domains/services we want to serve securely - this script does so in a pretty easy fashion:

#### /opt/service-containers/ingress/create-certificate.sh

```bash
#!/bin/bash

set -e

echo "Starting create new certificate..."
if [ "$#" -lt 2 ]; then
    echo "Usage: ...  <domain> <email> [options]"
    exit
fi

DOMAIN=$1
EMAIL=$2
OPTIONS=$3

TARGET_DIR="/opt/service-containers/ingress"

podman run --rm \
  -v $TARGET_DIR/letsencrypt:/etc/letsencrypt \
  -v $TARGET_DIR/webroot:/webroot \
  certbot/certbot \
  certonly --webroot -w /webroot \
  -d $DOMAIN \
  --email $EMAIL \
  --non-interactive \
  --agree-tos \
  $3

# Merge private key and full chain in one file and add them to haproxy certs folder
function cat-cert() {
  dir="${TARGET_DIR}/letsencrypt/live/$1"
  cat "$dir/privkey.pem" "$dir/fullchain.pem" > "./certs/$1.pem"
}

# Run merge certificate for the requested domain name
cat-cert $DOMAIN
```

This script will run a certbot container, generate the needed certificates, and stuff them somewhere we can use with HAProxy.  I ran it as such: 

```bash
cd /opt/service-containers/ingress
./create-certificate.sh nextcloud.kenmoini.com ken@kenmoini.com
```

With it created we can add the entry to our crt-list from earlier, which should look like this now:

```text
/usr/local/etc/certs/default.pem
/usr/local/etc/certs/nextcloud.kenmoini.com.pem [alpn h2 ssl-min-ver TLSv1.2] nextcloud.kenmoini.com
```

Restart the HAProxy container and it should pick up the new certificate and config:

```bash
podman restart ingress-haproxy
```

Since Certbot/Let's Encrypt provides only 90 day certificates there needs to be a way to renew the certificates, ideally automatically - stuff this script as an entry in your crontab that runs every 30 days or so:

#### /opt/service-containers/ingress/renew-certificates.sh

```bash
#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#cd $DIR

TARGET_DIR="/opt/service-containers/ingress"
cd $TARGET_DIR

echo "$(date) About to renew certificates" >> /var/log/letsencrypt-renew.log
podman run \
       -i \
       --rm \
       --name certbot \
       -v $TARGET_DIR/letsencrypt:/etc/letsencrypt \
       -v $TARGET_DIR/webroot:/webroot \
       certbot/certbot \
       renew -w /webroot

echo "$(date) Cat certificates" >> /var/log/letsencrypt-renew.log

function cat-cert() {
  dir="${TARGET_DIR}/letsencrypt/live/$1"
  cat "$dir/privkey.pem" "$dir/fullchain.pem" > "./certs/$1.pem"
}

for dir in ${TARGET_DIR}/letsencrypt/live/*; do
  if [[ "$dir" != *"README" ]]; then
    cat-cert $(basename "$dir")
  fi
done

echo "$(date) Reload haproxy" >> /var/log/letsencrypt-renew.log
podman restart ingress-haproxy

echo "$(date) Done" >> /var/log/letsencrypt-renew.log
```

Add a line like this to your Crontab to schedule this every 15 days at 4AM: `0 4 */15 * * /opt/service-containers/ingress/renew-certificates.sh >/dev/null 2>&1`

> ***Now there's an SSL secured ingress into the home lab network, with additional domains being a simple couple of commands away!***