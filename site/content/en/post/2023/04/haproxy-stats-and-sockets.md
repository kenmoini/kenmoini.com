---
title: HAProxy Stats, Sockets, and Stick Tables
date: 2023-04-08T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/haproxy-stats-sockets.png
photo_credit:
  title: Photo by Fatih Guney
  source: https://www.pexels.com/photo/cat-near-fisherman-on-galata-bridge-16077016/
tags:
  - open source
  - oss
  - homelab
  - red hat
  - rhel
  - automation
  - devops
  - gitops
  - developer
  - kubernetes
  - openshift
  - haproxy
  - sockets
  - stats
  - load balancer
  - proxy
authors:
  - Ken Moini
---

> The "f" in "HAProxy" stands for "fun"

Today I figured I'd write this up since I've had to find this HAProxy config stuff a few times now and it's always been a trial and error sort of thing - the last article I read on enabling HAProxy stats literally said it "100% works" in the title, published in 2022, annnnd - *did not work*.  So here's my own version that probably won't work in a month or two.

In this article I'll share some config on how to enable some extra functions in HAProxy to provide stats for the load balancer, an administrative socket for local operations against the live HAProxy instances, and how to use that socket to clear out Stick Tables, disable Frontends, etc.

## Installing HAProxy

Not going to emphasize this part since it's pretty easy - it's a package called `haproxy`.  Install it if you haven't already - alternatively you can run the container image instead and mount things if you like an extra layer of headaches.

```bash
# Install HAProxy, EL
dnf install haproxy -y

# Install HAPRoxy, Deb
apt install haproxy -y

# Set some basic config in /etc/haproxy/haproxy.cfg

# Enable HAProxy
systemctl enable --now haproxy
```

## Configuring the Statistics Endpoint

In case you want some information on backends, frontends, servers on the backends, requests to the frontends, responses to the clients, status of the servers, etc - then you can enable the statistics endpoint for the server.

There are a few conflicting ways on how to do it that you'll see online - ultimately, you just need to set a listener for the port you want the statistics to be served on (default is 1936), and set some `stats` specific configuration there:

```
# global config up here
# default config also maybe up here

listen stats
    # bind sets the port and interface/IP
    bind    *:1936
    # HTTP/L7 mode is required
    mode    http
    # Assume the global log settings
    log     global
    # There probably aren't that many things that are supposed to be listening for maxconn
    maxconn 10

    # Set the required timeouts
    timeout connect         4s
    timeout client          20s
    timeout server          20s

    # enable the stats module
    stats   enable

    # Obfuscate the version
    stats   hide-version

    # Refresh interval for the HTTP site
    stats   refresh         30s

    # Enable reporting of a host name on the statistics page
    stats   show-node

    # Enable reporting additional information on the statistics page
    stats   show-legends

    # Set some basic user:pass auth
    stats   auth            notadmin:securePassword
    stats   auth            othernotadmin:3xt4aSecurePassword

    # Configure where the HTTP URL should serve from
    stats   uri             /haproxy?stats

# backend/frontend config down here maybe
```

You can read more about [all the other `stats` configuration parameters here](https://docs.haproxy.org/2.7/configuration.html#4.2-stats%20admin), though that should be a really good starting point.  You've got the basic needed settings, enabling of the stats module, and some good fundamentals for keeping it secure.  You should be able to do a `curl -u 'notadmin:securePassword' http://localhost:1936/haproxy?stats` and see some output.

## Enabling an Administrative Socket

You could serve the statistics endpoint via a system socket and [interact with it via `socat`](https://www.haproxy.com/documentation/hapee/latest/api/runtime-api/show-stat/) - but that's not useful since your stats may be scraped by something like your observability tool, which is why it's available via HTTP.

However, what is very useful is enabling an administrative system socket to interact with the HAProxy instance to disable/enable frontends, healthchecks, servers, or to clear stick tables.

To enable the administrative system socket, just drop it into your `global` section - alternatively, you could also place it on a `frontend` to make more atomic administrative sockets:

```
# Maybe your global section looks like this...
global
    log         127.0.0.1 local2 debug
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     40000
    user        haproxy
    group       haproxy
    daemon

    # Enable a global administrative socket
    stats       socket  /run/haproxy/admin.sock mode 660 level admin
    stats       timeout 10s
```

The key part of the `global` section are the last two lines - again, you could put this in a `frontend` instead for more atomic control of load balanced services and their administrative sockets.

Wherever you do put the socket, make sure to create the parent directory and properly chown/chmod it:

```bash
# Create the runtime HAProxy directory
mkdir -p /run/haproxy/

# Give it the proper ownership and permissions
chown root:root /run/haproxy/
chmod 775 /run/haproxy/
```

## Using the Administrative Socket

Now that there's an administrative socket enabled, you can use it with something like `socat` to interact with it.

You can query the socket endpoint like so:

```bash
# Get help information
echo "help" | sudo socat stdio /run/haproxy/admin.sock

# Get load balancer information and statistics
echo "show info;show stat" | sudo socat stdio /run/haproxy/admin.sock
```

You can read more about the Runtime API here: https://www.haproxy.com/documentation/hapee/latest/api/runtime-api/

### Clearing Stick Tables

In case you're using a fail-over pattern that directs traffic to a primary server, failing over to a secondary and keeping the traffic there until manually reset, your `backend` may look something like this:

```
backend https
    stick-table type ip size 2 nopurge
    stick on dst
    server       cloudserver {{ cloud_server_endpoint }}:80 check on-error mark-down observe layer7 error-limit 1
    server       localserver {{ local_server_endpoint }}:80 check backup
```

In this example, your stick-table name would be the same as the backend so to clear it and reset the traffic back to the cloudserver, you'd run:

```bash
# Clear the https backend stick table
echo "clear table https" | sudo socat stdio /run/haproxy/admin.sock
```

### Disable a Backend Server

If you're needing to test traffic patterns resolving to different servers in a backend list, you can simply disable the servers:

```bash
# Disable the cloudserver from the https backend example above
echo "disable server https/cloudserver" | sudo socat stdio /run/haproxy/admin.sock

# or, enable the cloudserver from the https backend example above
echo "enable server https/cloudserver" | sudo socat stdio /run/haproxy/admin.sock
```

## Bonus - Example Repo

In case you're in the market for a reference repo that handles all this HAProxy stuff, automates it with Ansible, and with some keepalived goodness for HA HAProxy, then look no further: https://github.com/kenmoini/ansible-ha-ha-haproxy
