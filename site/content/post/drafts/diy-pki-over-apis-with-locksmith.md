---
title: "DIY PKI Over APIs with Locksmith"
date: 2021-12-01T04:20:47-05:00
draft: true
publiclisting: true
toc: false
hero: /images/posts/heroes/disconnected-ai-svc.png
tags:
  - x509
  - tls
  - ssl
  - openssl
  - locksmith
  - pki
  - self-hosted
  - privacy
  - open source
  - oss
  - homelab
  - containers
  - kubernetes
  - cloud
  - automation
authors:
  - Ken Moini
---

> So a CSR walks into a bar...

Today we'll be exploring everyone's second favorite topic: Public Key Infrastructure!

Almost every service that is deployed in any sort of semi-production manner will use some sort of encrypted communication, usually backed by x509 PKI - you may call this SSL or TLS, underneath it all using Certificates and Keys to identify parties and secure communication.

If you're like me, you're pretty tired of having to blast past self-signed SSL certificate warnings in your browser - how about creating a proper PKI chain to provide proper SSL/TLS encryption for different services?

## Calling a Locksmith

There are a few ways to handle x509 PKI, be that CFSSL or manual OpenSSL commands - there's also something called [Locksmith](https://github.com/kenmoini/locksmith) ***(shameless plug, I wrote Locksmith)***.

**Locksmith** allows you to manage x509 PKI via APIs - make an API call and you get a Certificate.

Being a Golang application it's super simple to deploy - for this example we'll deploy it as a SystemD-driven container service though there are many other [deployment options available](https://github.com/kenmoini/locksmith#deployment-options).

```bash
## Download the SystemD Service Unit File
sudo wget -O /etc/systemd/system/locksmith.service https://raw.githubusercontent.com/kenmoini/locksmith/main/init/caas-locksmith.service

## Create the Locksmith configuration directory
sudo mkdir -p /etc/locksmith/{cfg,pki}

## Download the service files
sudo wget -O /etc/locksmith/caas_start.sh https://raw.githubusercontent.com/kenmoini/locksmith/main/init/caas-locksmith-start.sh
sudo wget -O /etc/locksmith/caas_stop.sh https://raw.githubusercontent.com/kenmoini/locksmith/main/init/caas-locksmith-stop.sh
sudo wget -O /etc/locksmith/caas_vars.sh https://raw.githubusercontent.com/kenmoini/locksmith/main/init/caas-locksmith-vars.sh

## Modify the Service Variables
sudo nano /etc/locksmith/caas-vars.sh

## Set the executable bit
sudo chmod a+x /etc/locksmith/caas-*.sh

## Download the example config.yml
sudo wget -O /etc/locksmith/cfg/config.yml https://raw.githubusercontent.com/kenmoini/locksmith/main/configs/config.yml.example

## Modify the config.yml
sudo nano /etc/locksmith/config.yml

## Reload SystemD
sudo systemctl daemon-reload

## Pre-pull the container image
sudo podman pull quay.io/kenmoini/locksmith:latest

## Enable and Start the Service
sudo systemctl enable --now locksmith.service
```

The default API root is now accessible at `http://CONTAINER_IP:8080/locksmith/v1`

## Planning Your PKI

There are a few different ways to roll out PKI and it depends on your requirements, management workflow, etc.  This is an ideal set of basic chains and services required to support a robust PKI:

- ***A Root Certificate Authority*** - This is the head honcho, the who's who that signs all your other Intermediate Certificate Authorities.  Ideally you want some separation from Identity and Security in case a Private Key is compromised and having a highly secure known Root CA with subordinate Intermediate CAs that then sign for different classes of certificates is how you can easily do this.
- ***Intermediate Certificate Authorities*** - You want an Intermediate CA for different parts of your org/networks/services...you can split this up however you'd like but I like to have Intermediate CAs for any different network or major classification of a subset of services.  What this means is I have an Intermediate CA for my homelab, one for my public facing network services, etc.
- ***Signing Certificate Authorities*** - Your Root and Intermediate CAs shouldn't be certifying and signing anything for any individual service, and instead you should have a subordinate Signing Certificate Authority.  So my `Kemo Root` Root CA has `Kemo Labs` and `Kemo Network` Intermediate CAs, and there is for instance a `Kemo Network OpenVPN` Signing CA which provides OpenVPN Client certificates.
- ***Certificate Revocation Lists*** - CRLs are important as they allow the lookup of a PEM-encoded list of revoked certificates.  Revoking certificates is a common practice when there is a compromise or a certificate needs to be fully rotated.  This CRL needs to be accessible to your clients so they can query for revoked certificates before allowing the use of them.

## Creating a Root Certificate Authority

First thing we'll need to do is create a Root CA with Locksmith - since we're just working with an API we can do that simply via a cURL request:

```bash
#!/bin/bash

PKI_SERVER="locksmith.example.com:8080"

generatePatchData() {
cat << EOF
{
  "subject": {
    "common_name": "Example Labs Root Certificate Authority",
    "organization": ["Example Labs"],
    "organizational_unit": ["Example Labs Cyber and Information Security"],
    "country": ["US"]
  },
  "rsa_private_key_passphrase": "s0m3Ultr4S3cur#P455w0rd!",
  "expiration_date": [10, 0, 1],
  "san_data": {
    "email_addresses": ["certmaster@example.com"],
    "uris": ["https://ca.example.com:443/"]
  }
}
EOF
}

curl --request POST \
 --header "Content-Type: application/json" \
 --data "$(generatePatchData)" \
 http://$PKI_SERVER/locksmith/v1/root
```

> Fuck...the struct is messed up and the CRL endpoints don't reflect the proper data passed...need to fix Locksmith...