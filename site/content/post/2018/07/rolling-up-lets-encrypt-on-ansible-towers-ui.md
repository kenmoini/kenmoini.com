---
title: "Rolling up Let’s Encrypt on Ansible Tower’s UI"
date: 2018-07-14T22:31:48-05:00
draft: false
publiclisting: true
aliases:
    - /blog/rolling-up-lets-encrypt-on-ansible-towers-ui/
hero: /images/posts/heroes/resized/resized-ansible-tower-letsencrypt.png
tags: 
  - ansible
  - centos
  - certbot
  - debian
  - epel
  - galaxy
  - guide
  - https
  - let's encrypt
  - nginx
  - red hat
  - role
  - ssl
  - tutorial
  - ubuntu
  - walkthrough
authors:
  - Ken Moini
---

The other day someone asked me what I do for fun.

"Fun" really has a few different definitions for me, and I’d say for most people.  It could be entertainment, guttural satisfaction, leisurely adventuring about, or maybe for some slightly compulsive people like me, accomplishing a task.  Something I’m kind of overly compulsive about is proper SSL implementation and PKI.

So this morning I was having LOADS of fun.  My fast just started to kick in with some of the good energy and ‘umph’ so I was feeling great.  Bumping that new Childish summertime banger, really grooving.  I just finished spinning up a new installation of Ansible Tower and logged in.  That’s when the Emperor lost his groove.

I’ve seen the screen plenty of times in the Ansible Tower Workshops and simply, almost reflexively skip past the big warning sign you see when you first log into an Ansible Tower server’s UI.  The big warning sign isn’t too crucial in the large scheme of things, but it really stuck out to me this time.  Maybe because this server is part of a larger permanent infrastructure play, but it really got to me and I HAD to install some proper SSL certificates.

{{< figure src="/images/posts/legacyUnsorted/sslWarning.png" caption="We all know what to do here, click Advanced and yadda-yadda…or shouldn’t we just fix the issue?" target="_blank" class="col-sm-12 text-center" >}} 

So let’s go over two different ways to fix this...

## Background

Ansible Tower uses Nginx (pronounced engine-x) as their HTTP server for the Web UI.  It’s not configured ‘normally’ like you’d see in most web hosting scenarios, there’s no site-available, mods-available, etc.  That’s good though because nothing else should really run on this server outside of Ansible Tower so the good guys at Ansible thought it’d be good to just stuff everything in the default nginx.conf file.

The certificate is self-signed and can be easily replaced.  Here are the lines from the nginx.conf file that matter for this scope, starting at line 42 as of today/this version:

{{< highlight bash >}}
# If you have a domain name, this is where to add it
server_name _;
keepalive_timeout 65;
 
ssl_certificate /etc/tower/tower.cert;
ssl_certificate_key /etc/tower/tower.key;
{{< /highlight >}}

## Method 1 – Let’s Encrypt

This is probably the more prevalent method nowadays.  It’s easy, free, no need to manage anything since ACME takes care of it.  If your Ansible Tower instance faces the publicly routable Internet, this is probably your go-to.  If it’s not able to reach the Let’s Encrypt ACME servers, you won’t be able to use Let’s Encrypt without some tunnel/proxy/cron tomfoolery, or their manual method which incurs extra steps.  Alternatively, skip to Method 2 which is how to install your own certificate from your own CA/PKI.

Remember a few lines up in the configuration snippet where it had a comment “# If you have a domain name, this is where to add it”?  Go ahead and do just that, edit the /etc/nginx/nginx.conf file and replace the underscore (“_”) with your FQDN.  Save, exit.

Go ahead and reload the nginx configuration

{{< highlight bash >}}
# systemctl reload nginx.service
{{< /highlight >}}

Next, let’s enable the repos we need to install Let’s Encrypt.  Here are some one-liners, some parts will still be interactive (adding the PPA, accepting GPG keys in yum, etc).  Installing a PPA/EPEL and enabling repos where needed, updating, and installing the needed packages.  Slightly interactive prompts.
Debian/Ubuntu

{{< highlight bash >}}
# add-apt-repository ppa:certbot/certbot && apt-get update && apt-get install python-certbot-nginx -y
{{< /highlight >}}

### Red Hat Enterprise Linux (RHEL)/CentOS in AWS

{{< highlight bash >}}
# rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && yum -y install yum-utils && yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional && yum update -y && yum -y install python-certbot-nginx
{{< /highlight >}}

### Red Hat Enterprise Linux (RHEL)/CentOS (Normal?)

{{< highlight bash >}}
# rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && yum -y install yum-utils && yum-config-manager --enable rhel-7-server-extras-rpms rhel-7-server-optional-rpms && yum update -y && yum -y install python-certbot-nginx
{{< /highlight >}}

And boom, just like that we….are almost there.  One more command and we should be set:

{{< highlight bash >}}
# certbot --nginx
{{< /highlight >}}

If the server_name variable in your nginx.conf was modified to point to your FQDN, nginx was reloaded, and all packages enabled properly, the Certbot/Let’s Encrypt command should give you the option of selecting “1: tower.example.com” and do so.  Important: Certbot will ask if you want to force all traffic to be HTTPS.  Ansible Tower already has this configuration in place, so just select “1” when asked about forcing HTTPS to skip that configuration change.

Navigate to your Ansible Tower Web UI, and you should have a “Secure” badged site.

{{< figure src="/images/posts/legacyUnsorted/secureTower.png" caption="Ansible Tower and Let’s Encrypt. That looks so good." target="_blank" class="col-sm-12 text-center" >}} 

## Method 2 – Manually replacing the SSL Certificate with your own

This is really easy to do actually.  All you have to do is place your certificate files on your Ansible Tower server (in /etc/ssh or /etc/certificates for example), and modify the nginx configuration to point to them.  You may recall the lines in the configuration from earlier...

{{< highlight bash >}}
ssl_certificate /etc/tower/tower.cert;
ssl_certificate_key /etc/tower/tower.key;
{{< /highlight >}}

Yes, there.  All you have to do is replace those two files, or preferably deposit your own and change the configuration to point to the new files.

Now, this only works under one of the following considerations...

1. Your certificate is from Comodo, VeriSign, etc.  A CA that’s generally in the root zone of most browser’s certificate store.
2. Your certificate is from a CA that is installed in your browser’s or device’s root CA store.  Typical of enterprises who manage their own PKI and deploy to their endpoints.

Basically, as long as the Certificate Authority (or CA) that signed your replacement certificate is in your CA root zone you should be golden, otherwise, you’ll see the same SSL Warning message displayed since your browser doesn’t recognize the CA’s identity and therefore does not trust anything signed by them.  If there’s an Intermediary CA, make sure to include the full certificate chain to establish the full line of trust.
Conclusion

Gee, that was fun, right?!

Well, I had fun at least.  If not fun, maybe someone needs to secure their Ansible Tower installation(s) and finds this useful and it brings along a sense of accomplishment or relief.

I have half a mind to make this into an Ansible Role…EDIT: Holy crap, I did make this into an Ansible Role. Has a couple neat tricks it does yeah.
