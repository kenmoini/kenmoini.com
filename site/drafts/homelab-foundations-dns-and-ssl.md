---
title: "Homelab Foundations - DNS and SSL"
date: 2021-12-05T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/dns-pki-and-more.png
tags:
  - open source
  - oss
  - containers
  - automation
  - nameserver
  - dns
  - records
  - domain
  - registrar
  - namecheap
  - godaddy
  - bind
  - named
  - reverse proxy
  - haproxy
  - load balancer
  - ingress
authors:
  - Ken Moini
---

> This is a compendium of how to go from Zero to Hero when it comes to DNS in and out of a homelab.

DNS is usually only thought of when something goes down - it's easy to mess up, sometimes hard to get right, and the smallest thing can cause chaos but it underpins most of our modern comforts and technologies.  This same sentiment also applies to PKI, or otherwise expressed as SSL/TLS - the foundation of our identity and security.

![https://imgs.xkcd.com/comics/dependency.png](XKCD probably wasn't writing about DNS, but it applies)

This blog entry will be a long series into how I handle Domains, DNS, and PKI/TLS/SSL Certificates.  This is not the only way to do it, it's probably not the best way to do it, likely not all up to the most enterprise-grade and secure method, but it's very robust and works very well in and outside of my different networks - hopefully it can help serve your use case as well.

# Expectations

I won't detail every RFC spec, or every technology that can service the needs for what is implemented - but you will learn enough to be able to maybe find alternative Authoritative DNS servers like dnsmasq or Knot, in case BIND/named doesn't meet your needs.

This also won't guide through every way to do something - for instance, in places where containers are used the deployment will be run with Podman so if you are still a Docker user (for whatever forsaken reason) then you'll need to adapt the words `podman` to `docker` in some of the commands displayed.

So if those are all the things this won't be about, what are we actually looking at?

- **Architecture Overview**
  See how it all fits together

- **Public TLDs - Buying Your First Domain**
  While you don't need a public domain name, any proper technologist has at least a few.  Drop a few bucks for yourname.com or master-blaster420.com - whatever floats your boat
- **DNS Basics - Creating a Zone and Records**
  You have a Domain, now to tell it where to tell users where to go to know where to go with a DNS server
- **Deploying A Web Page**
  Obviously now you want to have your very own cool-person website like mine, right?  ...right?!
- **Adding DNS Records for the Web Page**
  With one simple A Record, you too can serve traffic from your domain to your cool-person website!
- **Encrypting Stuff and Things on the Web**
  Since there's very important information on your blog you should secure it with SSL - automated from Let's Encrypt for free!

- **Look Ma - No Ads!  Deploying a Recursive DNS Server with Pi-Hole**
  Before jumping into a DIY DNS server add some network-wide ad-blocking with a Pi-Hole DNS Server
- **Zoned Out and In a BIND - Adding an Authoritative DNS Server**
  Add another layer to the DNS stack and host zones internally
- **Looking out on the Split Horizon**
  How can DNS work inside and outside the networks harmoniously?
- **Go-Zones - DNS as YAML**
  What's more fun than running experimental software for crucial systems?

- **DIY PKI - Authorities and Certificates**
  We can't all be our own boss - but we can be our own Certificate Authority!
- **PKI over API - Locksmith**
  OpenSSL via the shell can be so...manual.  Instead, use Locksmith with cURL!

---

# Architecture Overview

There aren't many moving pieces to DNS and SSL - it's mostly an integration thing for both of those technologies.  Running these sort of services is pretty simple and costs very little to do so.



---

# Public TLDs - Buying Your First Domain

---

# DNS Basics - Creating a Zone and Records

---

# Deploying a Web Page

---

# Adding DNS Records for the Web Page

---

# Encrypting Stuff and Things on the Web

---

# Look Ma - No Ads!  Deploying a Recursive DNS Server with Pi-Hole

---

# Zoned Out and In a BIND - Adding an Authoritative DNS Server

---

# Looking out on the Split Horizon

---

# Go-Zones - DNS as YAML

---

# DIY PKI - Authorities and Certificates

