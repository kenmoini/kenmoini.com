---
title: "Goodbye Google, Hello Plausible"
date: 2021-11-08T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/plausible-analytics.png
tags:
  - plausible
  - google
  - analytics
  - self-hosted
  - privacy
  - open source
  - oss
  - homelab
  - containers
  - kubernetes
  - git
  - cloud
  - blogging
  - automation
authors:
  - Ken Moini
---

> Google knows more about you than you know about yourself

So, let me start by saying I'm not anti-Google - I just happen to run a [Pi-Hole](https://pi-hole.net/) which blocks Google Analytics throughout my network.  This means that when I navigate the Internet, I'm a ghost as far as Apple, Facebook, and Google's advertisment and analytics networks are concerned.

This all works brilliantly except for a few, *minor* points:

- If you have a site, *like this one*, Google Analytics is useful for finding out what content is driving your traffic and from where, what sources, etc - because of Pi-Hole I'm a ghost even on my own site with Google Analytics, not showing up in any way.
- There are a bunch of other nerds out there who also run Pi-Hole or other forms of DNS deny-lists - since I write mostly for *said nerds*, it's likely I'm losing visibility into a large segment of my visitors.
- You still get tracked with cookies more than likely anyway
- Google Analytics collects ***a lot*** of data and it's ***a lot*** of extra Javascript - you can read more about that here: https://plausible.io/privacy-focused-web-analytics

We can solve for all these pain points by self-hosting our own analytics and there are plenty of options to choose from - the one I found to be easy to deploy, feature complete, privacy-focused, and with a nice user interface was [Plausible Analytics](https://plausible.io/).

---

## Plausible Analytics

[Plausible Analytics](https://plausible.io/) is an analytics platform that is open-source, privacy-focused, and lightweight that can be self-hosted or consumed via their managed cloud service offering.

{{< imgSet cols="1" name="plausible-analytics" >}}
{{< imgItem src="/images/posts/2021/11/privacy-focused-web-analytics.png" alt="I wish this was my dashboard..." >}}
{{< /imgSet >}}

Since we can self-host it, it's going to load on most systems, even those with DNS deny-lists such as Pi-hole - `analytics.carls-car-shop.com` is not likely to be in any of those lists.

The privacy offered by it is top notch - it uses no cookies and is fully compliant with GDPR, CCPA and PECR regulations right out of the box.  This basically means it collects very very little user data and leaves no trace on their systems to track them around.

I also do enjoy that it's open-source - anywho, let's get to deploying things.

---

## Plausible Deployability

Since it's able to run as a [self-hosted service](https://github.com/plausible/hosting) we can drop it into some containers and go.  Thankfully they provide the containers already built so it's mostly just configuration and doing things in the right order.

To deploy Plausible Analytics we need to run a few things:

- A [ClickHouse](https://clickhouse.com/) OLAP database
- A PostgreSQL database
- Use of some SMTP service
- The [Plausible service](https://github.com/plausible/hosting)

For this instance we'll be deploying it onto a Kubernetes cluster with nginx-ingress and cert-manager already set up.  The Ingress objects below will use a cert-manager ClusterIssuer that uses Let's Encrypt's ACME DNS01 solver via DigitalOcean's DNS service.

As far as SMTP goes, we'll be using [SendGrid](https://sendgrid.com/) since it's free/extremely cheap, easy to use, with the capability to verify a whole domain for sending messages.  [Getting Started with SendGrid SMTP](https://docs.sendgrid.com/for-developers/sending-email/getting-started-smtp) is outside the scope of this article, but it's not difficult as long as you can set some DNS records.

---

## Configuring Plausible Analytics

Plausible uses a random 64-character secret key which will be used to secure the app.  The snippet below uses an inline `openssl` command to generate this secret.

In order to have Plausible work with everything there needs to be a bit of configuration set - you can read about all the configuration options available here: https://plausible.io/docs/self-hosting-configuration

The ones that are important are the following:

```bash
## Create an environment configuration file

cat <<EOF > plausible-config.env 
ADMIN_USER_EMAIL="you@example.com"
ADMIN_USER_NAME="somelUser"
ADMIN_USER_PWD="reallyRandomAndSecurePassword"
BASE_URL="https://analytics.example.com"
SECRET_KEY_BASE="$(openssl rand -base64 64 | tr -d '\n')"

MAILER_EMAIL="noreply@example.com"
SMTP_HOST_ADDR="smtp.sendgrid.net"
SMTP_HOST_PORT="465"
SMTP_HOST_SSL_ENABLED="true"
SMTP_USER_NAME="apikey"
SMTP_USER_PWD="yourSendGridOrWhateverSMTPPassword"
EOF
```

That environment variable file will be used via a Kubernetes Secret.

---

## Kubernetes Kick Off

Assuming you're authenticated to a Kubernetes cluster, start by creating a new Namespace, a Secret, and the rest of the services - you won't need a separate Plausible deployment for every website since it is multi-tenant.

```bash
## Create namespace
kubectl create namespace plausible-analytics

## Create Secret from environment variable configuration file
kubectl create secret generic plausible-config --from-env-file=plausible-config.env  --dry-run=client -o yaml > plausible-config-secret.yaml

## Apply configuration Secret
kubectl apply -f plausible-config-secret.yaml -n plausible-analytics

## Deploy the ClickHouse DB
kubectl apply -f https://raw.githubusercontent.com/kenmoini/kenmoini.com/main/deploy/supporting/plausible-analytics/02-clickhouse.yaml -n plausible-analytics

## Deploy the PostgreSQL DB - note: default credentials are used
kubectl apply -f https://raw.githubusercontent.com/kenmoini/kenmoini.com/main/deploy/supporting/plausible-analytics/02-db.yaml -n plausible-analytics

## Deploy the Plausible Analytics Service
kubectl apply -f https://raw.githubusercontent.com/kenmoini/kenmoini.com/main/deploy/supporting/plausible-analytics/03-plausible.yaml -n plausible-analytics
```

With that you should now have the Plausible Analytics service running on the cluster and all that's needed is to expose it to the Internet via an Ingress of some sort.

When exposing the Plausible Analytics service, make sure to set the [reverse proxy configuration](https://plausible.io/docs/self-hosting#2-reverse-proxy).  My Kubernetes ingress-nginx looks something like this:

```yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: plausible-analytics
  labels:
    app: plausible-analytics
    app.kubernetes.io/name: plausible-analytics
    app.kubernetes.io/part-of: plausible-analytics
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-dns-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Forwarded-For: $proxy_add_x_forwarded_for";
spec:
  tls:
    - hosts:
        - analytics.example.com
      secretName: analytics-example-com-tls
  rules:
    - host: analytics.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: plausible
                port:
                  number: 8000
```

---

## That New Dashboard Smell

The next part is extremely simple - access whatever route you set for your Ingress, such as https://analytics.example.com, log in, and add a site.

{{< imgSet cols="3" name="site-creation" >}}
{{< imgItem src="/images/posts/2021/11/plausible-add-site.png" alt="Add a site" >}}
{{< imgItem src="/images/posts/2021/11/plausible-get-snippet.png" alt="Take the Javascript and add it to your site" >}}
{{< imgItem src="/images/posts/2021/11/plausible-waiting-on-hit.png" alt="Waiting for that first guest..." >}}
{{< /imgSet >}}

With a site added, maybe one called mysite.com, you'll be given a bit of JavaScript to add to your site that looks like this:

```javascript
<script defer data-domain="mysite.com" src="https://analytics.example.com/js/plausible.js"></script>
```

---

> After a while you should start to see some analytics and statistics rolling in!