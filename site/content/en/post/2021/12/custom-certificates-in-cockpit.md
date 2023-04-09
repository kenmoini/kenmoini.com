---
title: "Custom Certificates in Cockpit"
date: 2021-12-21T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/cockpit-certificates.png
tags:
  - open source
  - oss
  - cockpit
  - red hat
  - tls
  - ssl
  - certificates
authors:
  - Ken Moini
---

> Getting really tired of these SSL warnings...

My goal over this holiday break is to remove self-signed certificates from any part of my network - even if it is with just a simple wildcard certificate that signs almost everything.

One of the most frequent run-ins with these self-signed certificates is with ***[Cockpit](https://cockpit-project.org/)*** - a web UI for Linux systems.  I use it for pretty much all of my Linux systems and it's one of the first things I enable when deploying a RHEL system, which most of mine are.

---

## Installing Cockpit

Cockpit is installed by default in RHEL 8, all that you need to do is enable it:

{{< code lang="bash" line-numbers="true" >}}
systemctl enable --now cockpit.socket
{{< /code >}}

On systems where it's not installed you can install it with the following:

{{< code lang="bash" line-numbers="true" >}}
## Debian/Ubuntu-based Systems
apt install cockpit

## RHEL-based systems
dnf install cockpit

## Don't forget to enable the service
systemctl enable --now cockpit.socket
{{< /code >}}

With that you can access the server at the system's IP address at port `9090` in your web browser - but then you'll see something like this because of the self-signed certificates:

{{< imgSet cols="1" name="bad-ssl" >}}
{{< imgItem src="/images/posts/2021/12/cockpit-self-signed-certificate-screen.png" alt="Ahhh! It's so angry!" >}}
{{< /imgSet >}}

---

## Replacing the Certificate

To get rid of the self-signed certificate "This is not secure" warning sign the certificates need to be replaced - the following assumes you have a server-type certificate for your the host name that you're wanting to access the Cockpit instance from.  It's helpful to have the IP for the host listed in the Certificate SAN as well.

Cockpit looks for certificates in the `/etc/cockpit/ws-certs.d` directory, sorts them alphabetically, and uses the last one.  You'll likely see something like the following files already in that directory:

{{< code lang="bash" line-numbers="true" >}}
$ ls /etc/cockpit/ws-certs.d
0-self-signed-ca.pem  0-self-signed.cert
{{< /code >}}

Those are the self-signed certificates and the authority that are generated automatically - remove them with `rm /etc/cockpit/ws-certs.d/0-self-signed*`

There are two files needed, a certificate and the key.  The certificate will be the server certificate PEM block appended by the intermediate certificate chain - so for me I do the following:

{{< code lang="bash" line-numbers="true" >}}
## Create the Certificate, Server + Intermediate Chain
cat ~/wildcard.kemo.labs.cert.pem > /etc/cockpit/ws-certs.d/99-wildcard.kemo.labs.cert
cat ~/wildcard.kemo.labs.ca-chain.pem >> /etc/cockpit/ws-certs.d/99-wildcard.kemo.labs.cert

# Copy over key
cp ~/wildcard.kemo.labs.key.pem /etc/cockpit/ws-certs.d/99-wildcard.kemo.labs.key

## Set Permissions
chown root:cockpit-ws 99-wildcard.kemo.labs.*

## Restart Cockpit
systemctl restart cockpit
{{< /code >}}

With the files in place, proper permissions, and the service restarted you should now see the Cockpit login screen without any self-signed certificate warning screens!

{{< imgSet cols="1" name="proper-ssl" >}}
{{< imgItem src="/images/posts/2021/12/cockpit-proper-ssl.png" alt="No more self-signed warning screens for me!" >}}
{{< /imgSet >}}
