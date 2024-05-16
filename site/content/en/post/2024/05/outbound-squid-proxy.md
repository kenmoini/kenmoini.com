---
title: "Outbound Squid Proxy"
date: 2024-05-16T00:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/squid-proxy.png
photo_credit:
  title: Pexels
  source: https://www.pexels.com/photo/a-glass-window-with-ocean-view-under-the-white-clouds-8891027/
tags:
  - open source
  - oss
  - homelab
  - red hat
  - rhel
  - fedora
  - podman
  - kubernetes
  - metallb
  - squid
  - proxy
  - outbound
  - disconnected
  - openshift
  - curl
  - dnf
  - rhsm
authors:
  - Ken Moini
---

> Aww, you guys made me ink!

---

Working with a wide variety of customers gives me a lot of different environments to learn from - some of which I have to replicate.  Being able to reproduce systems in my lab gives me the ability to be a better architect, learn new technologies, and debug issues.

One of the services I've kept running in my lab is an Outbound Proxy - *reminds of of the good ol' days of running CGI scripts to get around library and school network filters.*

In enterprise networks you may have a network segment that is generally disconnected from the Internet, and the only way to access the WAN is through the use of an Outbound Proxy.  Outbound Proxies come in all shapes and sizes, and many of them perform a key function of doing ~~SSL Man-in-the-Middl-~~, *erm* I mean TLS Re-encryption.  This allows the network operators to ~~snoop on~~, *sorry*, I mean inspect traffic even if they're going to encrypted sites.

Outbound proxies can also perform other functions such as caching of data for faster serving to multiple clients, logging of traffic flows, and troubleshooting network connections.

In this article I'll be going over how to run a Squid Outbound Proxy with TLS Re-encryption - it's basically a walkthrough of this repo: https://github.com/kenmoini/lab-squid-proxy

While you could simply do a `dnf install squid` and configure things that way for the service on a local system, I'll also be demonstrating this via containers in Podman and Kubernetes.

---

## PKI Generation

In order for Squid to perform TLS Re-encryption you need to provide it with a Certificate Authority that can be used to sign certificates on the fly.  What Squid will do is dynamically create SSL Certificates for sites that are requested - eg if you go to `https://github.com` it won't show up with the actual certificate GitHub uses, it'll have a certificate signed by the Squid CA.  Since you have the private key that CA uses, it's trivial to decrypt and inspect the traffic of secure connections this way.

Now, in an ideal world, this would probably be an Intermediate Certificate Authority of a more privately secured Root CA, or even a leaf CA of an Intermediate CA.  Without going down the PKI rabbit hole too deep, for these purposes we'll create a new Root CA that will service Squid's use.  There are a few ways you could do this, with StepCA, Vault, etc - let's keep it simple and just use OpenSSL commands to generate a simple Root CA:

```bash
# Make a new directory to house the simple CA
mkdir -p /opt/.squid-ca/{certs,newcerts,private}
cd /opt/.squid-ca

# Create an Index file
touch ./index.txt

# Create a Serial file
[ ! -f ./serial ] && echo 1000 > ./serial

# Generate a Private Key
openssl genrsa -out ./private/root-ca.key.pem 2048

# Create an OpenSSL Configuration File
cat << EOF > root-ca-openssl.cnf
# OpenSSL Root CA configuration file.

[ ca ]
# 'man ca'
default_ca        = CA_default

[ CA_default ]
# Directory and file locations.
dir               = $(pwd)
certs             = \$dir/certs
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

# The root key and root certificate.
private_key       = \$dir/private/root-ca.key.pem
certificate       = \$dir/certs/root-ca.cert.pem

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 3650
preserve          = no
copy_extensions	  = copy
policy            = policy_root

[ policy_root ]
# The root CA should only sign certificates that match these policies.
# See the POLICY FORMAT section of 'man ca'.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the 'req' tool ('man req').
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_root_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = US
stateOrProvinceName_default     = North Carolina
localityName_default            = Raleigh
0.organizationName_default      = Prestige Worldwide
organizationalUnitName_default  = InfoSuck
emailAddress_default            = madmin@pw.rocks

[ v3_root_ca ]
# Extensions for a Root CA ('man x509v3_config').
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical, CA:true
keyUsage                = critical, digitalSignature, cRLSign, keyCertSign

EOF

# Create a self-signed Root Certificate
openssl req -config ./root-ca-openssl.cnf \
    -key ./private/root-ca.key.pem \
    -new -x509 -days 7500 -sha256 -extensions v3_root_ca \
    -out ./certs/root-ca.cert.pem \
    -subj "/CN=Squid Root CA"

# Set some permissions
chmod 700 ./private
chmod 400 ./private/root-ca.key.pem
chmod 444 ./certs/root-ca.cert.pem
```

With that we have a "simple" Root CA - this will be used in either deployment mode, as a SystemD service, Podman container, or Kubernetes Deployment.

Before doing any of that though, we need to add the Root CA Certificate to the system's trusted store, and any other system that will be accessing the Internet via the Squid Proxy.  Instructions for doing so on a variety of systems can be found here: https://kenmoini.com/post/2024/02/adding-trusted-root-certificate-authority/

For quick reference, this is how you'd do it on Fedora/RHEL and Debian/Ubuntu systems:

```bash
#=============================================== Fedora/RHEL
## Copy your Root CA to the sources path
sudo cp certs/root-ca.pem /etc/pki/ca-trust/source/anchors/

## Update the Root CA Trust Bundles
sudo update-ca-trust

#=============================================== Debian/Ubuntu
## Copy your Root CA to the sources path
sudo cp certs/root-ca.crt /usr/local/share/ca-certificates/

## Update the Root CA Trust Bundles
sudo update-ca-certificates
```

Before I trigger my InfoSec friends, ideally you'd extend the Root CA with an Intermediate CA, or even a further leaf Signing CA, that way you could control your PKI chain a bit more securely but that entails much more configuration that I'll post about in my PKI Primer article coming soon.  In case you're already running a robust PKI and want to use a non-Root CA, this will be handy information: https://wiki.squid-cache.org/ConfigExamples/Intercept/SslBumpWithIntermediateCA

---

## Squid Configuration Files

With the Root CA created, we can now start to create the various configuration files needed for Squid.  In the following example the different configuration stanzas are broken out into separate files for easier maintenance.  It all starts with the primary entrypoint configuration file that globs all the others together:

```bash
# /etc/squid/squid.conf

#
# Recommended minimum configuration:
#

include /etc/squid/conf.d/*
```

From there we can start to break out the other configuration components in their own files.  First up is the ACL configuration that sets what networks and target ports are allowed to use the Squid Proxy.

```bash
# /etc/squid/conf.d/00_acls.conf
# https://www.squid-cache.org/Doc/config/acl/

# Example rule allowing access from your local networks.
# Adapt to list your (internal) IP networks from where browsing
# should be allowed
acl localnet src 0.0.0.1-0.255.255.255  # RFC 1122 "this" network (LAN)
acl localnet src 10.0.0.0/8             # RFC 1918 local private network (LAN)
acl localnet src 100.64.0.0/10          # RFC 6598 shared address space (CGN)
acl localnet src 169.254.0.0/16         # RFC 3927 link-local (directly plugged) machines
acl localnet src 172.16.0.0/12          # RFC 1918 local private network (LAN)
acl localnet src 192.168.0.0/16         # RFC 1918 local private network (LAN)
acl localnet src fc00::/7               # RFC 4193 local private network range
acl localnet src fe80::/10              # RFC 4291 link-local (directly plugged) machines

acl SSL_ports port 443          # https
acl SSL_ports port 6443         # k8s API
acl SSL_ports port 8443         # Alt SSL
acl SSL_ports port 9443         # Other Alt SSL
acl SSL_ports port 9090         # cockpit

acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http

acl CONNECT method CONNECT
```

Next we have an access map - this extends the ACL definitions with what is allowed and denied to networks and ports.

```bash
# /etc/squid/conf.d/05_access-map.conf
# https://www.squid-cache.org/Doc/config/http_access/

#
# Recommended minimum Access Permission configuration:
#
# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Only allow cachemgr access from localhost
http_access allow localhost manager
http_access deny manager

# We strongly recommend the following be uncommented to protect innocent
# web applications running on the proxy server who think the only
# one who can access services on "localhost" is a local user
http_access deny to_localhost

# Example rule allowing access from your local networks.
# Adapt localnet in the ACL section to list your (internal) IP networks
# from where browsing should be allowed
http_access allow localnet
http_access allow localhost

# And finally deny all other access to this proxy
http_access deny all
```

The following configuration file defines what ports Squid should listen on and the configuration of those ports.  Port 3128 provides TLS Re-encryption where Port 3129 just proxies connections without any TLS Re-encryption.  This can be handy for debugging the operation of Squid.  There are also some general connectivity configuration parameters used for things such as request header manipulation and IPv4 preference.

```bash
# /etc/squid/conf.d/10_listening.conf
# https://www.squid-cache.org/Doc/config/http_port/

# SSL MitM config
http_port 3128 ssl-bump \
  cert=/etc/squid/certs/squid-ca.pem \
  generate-host-certificates=on dynamic_cert_mem_cache_size=16MB

# no SSL MitM
http_port 3129

# Misc general configuration
visible_hostname proxy.kemo.labs
dns_v4_first on
forwarded_for on
```

As an extension of the ACL configuration, we can set how Squid will operate SSL termination and re-encryption.  This is where you can exclude sites from being re-encrypted which helps in certain situations when some applications or clients don't accept proxy configuration, have client-side certificate pinning, or for mTLS connections *(many thanks to Sam Richman for that info!)*  This exclusion is also usually needed when running as a transparent proxy and you find connections randomly breaking due to certificate pinning and the like.

In the following example you can see some commented out lines where I previously excluded requests going to GitHub from being re-encrypted which was needed in older versions of Red Hat Advanced Cluster Management due to how the Application controller didn't work with proxies:


```bash
# /etc/squid/conf.d/20_ssl-mitm-acl.conf
# https://www.squid-cache.org/Doc/config/acl/

sslcrtd_program /usr/lib64/squid/security_file_certgen -s /etc/squid/certs/ssl_db -M 64MB
sslproxy_cert_error allow all
tls_outgoing_options flags=DONT_VERIFY_PEER
always_direct allow all

# Splicing Exclusions
#acl noBumpSites dstdomain .github.com

# SSL Inspection/Splicing/Bumping Steps
acl step1 at_step SslBump1
ssl_bump peek all
ssl_bump bump all
#ssl_bump splice noBumpSites
ssl_bump splice all
ssl_bump stare all
```

Squid can log connections, if they're terminated properly, their response codes, etc - you can also configure how the logs are formatted and rotated:

```bash
# /etc/squid/conf.d/30_logging.conf
# https://wiki.squid-cache.org/SquidFaq/SquidLogs

logfile_rotate 3

logformat squid-cs %{%Y-%m-%d %H:%M:%S}tl %3tr %>a %Ss/%03>Hs %<st %rm %>ru %un %Sh/%<a %mt "%{User-Agent}>h" "SQUID-CS" %>st %note

cache_log /var/log/squid/cache.log
access_log /var/log/squid/access.log
cache_store_log /var/log/squid/cache_store.log
```

Another capability that Squid has is to act as a cache for files that are frequently requested.  This can be helpful for storing static files closer to clients in the networks and speeds up requests.  This same caching function can also be used to replace data in requests, such as replacing all requested images with a different images...*good times at [PhreakNIC](https://phreaknic.info/), good times*.

Anywho, since we're not worried about caching, this is some example configuration that disables the Squid cache - if you want to enable caching then you'll likely need to do so via adaption: https://wiki.squid-cache.org/ConfigExamples/DynamicContent/Coordinator

```bash
# /etc/squid/conf.d/40_caching.conf
# http://www.squid-cache.org/Doc/config/cache_dir/

# Uncomment and adjust the following to add a disk cache directory.
#cache_dir ufs /var/spool/squid 1000 16 256

# Disables all caching
cache deny all

# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid

# Add any of your own cache refresh_pattern entries if enabled
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
```

You can now pass those configuration files to Squid and run it in a variety of ways.

Squid really is a useful tool that can do more than what I have configured here - to find some more examples, this is a great starting point: https://wiki.squid-cache.org/ConfigExamples/

---

## Squid Package Installation

Now if you want to just do things the "easy way" you could just install and enable the Squid package and be on your way - assuming you're on a Fedora/RHEL system you can run:

```bash
# Install the system package
dnf install squid

# Enable the service
systemctl enable --now squid

# Allow ports on the firewall
firewall-cmd --add-port=3128/tcp --permanent
firewall-cmd --add-port=3129/tcp --permanent
firewall-cmd --reload
```

*But that's not sexy - running it as a container would be so much cooler.*

---

## Squid in a Podman Container

In the repo linked above, you can find a variety of resources to run Squid via Podman or on Kubernetes.  The built container is located at https://quay.io/kenmoini/squid-proxy and is built for both x86_64 and Arm64 CPU architectures.

In either case, you'll likely want to fork the repo into your own, then modify a few things, namely adding the Root CA Certificate to the trusted store located in the `container_root/etc/pki/ca-trust/source/anchors` folder.  However, if you've already added the Root CA to your system's trusted root store, you can volume mount that into the container instead.

The configuration files are also baked into the container, but you can also override them with a volume mount pointing to a directory on your local container host system.

Personally I'm not a fan of the Podman SystemD generator, it's kind of buggy and not easy to mutate.  So for this I created a little initialization script that is run by a SystemD service.  The SystemD unit file looks like this:

```bash
# /etc/systemd/system/container-squid.service

[Unit]
Description=Squid Proxy Container Services
After=network-online.target
Wants=network-online.target

[Service]
TimeoutStartSec=15
ExecStop=/opt/service-containers/squid-proxy/scripts/service_init.sh start
ExecStart=/opt/service-containers/squid-proxy/scripts/service_init.sh stop
ExecReload=/opt/service-containers/squid-proxy/scripts/service_init.sh restart

TimeoutStartSec=20
Type=forking
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

With that SystemD unit file in place, make sure to run `systemctl daemon-reload`.

Before enabling/starting the service, we need to make the initialization script that it calls - it looks a little like this:

```bash
#!/bin/bash

# /opt/service-containers/squid-proxy/scripts/service_init.sh

set -x

CONTAINER_NAME="squid-proxy"
CONTAINER_VOLUME_ROOT="/opt/service-containers/${CONTAINER_NAME}"
CONTAINER_IMAGE="quay.io/kenmoini/squid-proxy:latest"
CONTAINER_RESOURCE_LIMITS="-m 1024m"

CONTAINER_NETWORK_NAME="lanBridge"
CONTAINER_IP_ADDRESS="192.168.42.31"
CONTAINER_PORTS="-p 3128 -p 3129"

CERT_VOLUME="-v /etc/squid/certs:/etc/squid/certs"
CONFIG_VOLUME="-v /etc/squid/conf.d:/etc/squid/conf.d"
TRUSTED_ROOT_VOLUME="-v /etc/pki/ca-trust/extracted/pem:/etc/pki/ca-trust/extracted/pem"

################################################################################### EXECUTION PREFLIGHT
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

    echo "Killing ${CONTAINER_NAME} container..."
    /usr/bin/podman kill ${CONTAINER_NAME}

    echo "Removing ${CONTAINER_NAME} container..."
    /usr/bin/podman rm -f -i ${CONTAINER_NAME}
    ;;

esac

case $1 in

  ################################################################################# RESTART/START SERVICE
  "restart" | "start")

    echo "Pulling container image..."
    podman pull ${CONTAINER_IMAGE}

    echo "Starting container services..."

    # Deploy container
    echo -e "Deploying ${CONTAINER_NAME}...\n"
    podman run -dt \
    --name ${CONTAINER_NAME} \
    ${CONTAINER_RESOURCE_LIMITS} \
    --network "${CONTAINER_NETWORK_NAME}" --ip "${CONTAINER_IP_ADDRESS}" ${CONTAINER_PORTS} \
    ${CERT_VOLUME} \
    ${CONFIG_VOLUME} \
    ${TRUSTED_ROOT_VOLUME} \
    ${CONTAINER_IMAGE}

    ;;

esac
```

You'll want to make sure to modify the bridged IP address and network assigned to the container.  Alternatively you could modify to use the container host's networking and just map the ports.

Now that script (and the previous Squid Listening configuration file) references a `/etc/squid/certs` path that needs to be created and populated with the Root CA - the format for Squid's Re-encryption CA is the Certificate PEM with the Private Key PEM appended.  The following should create it properly:

```bash
# Make the needed directories
mkdir -p /etc/squid/certs

# Concatenate the Certificate and Private Key
cat /opt/.squid-ca/certs/root-ca.cert.pem /opt/.squid-ca/private/root-ca.key.pem /etc/squid/certs/squid-ca.pem
```

Once that's all in place you can run `systemctl enable --now container-squid` to start things up!

---

## Squid on Kubernetes

I used to run Squid as a Podman container, however I now run it on my little BeeLink Kubernetes cluster so I can perform host maintenance easier while keeping all my services online.

In the repo you'll find a `deployment` folder with all the needed manifest objects along with a Kustomization file: https://github.com/kenmoini/lab-squid-proxy/tree/main/deployment

It's pretty simple and a relatively standard Kubernetes deployment - you've got a Namespace, a PVC for cache, the Squid configuration files are provided via the ConfigMap, the External Secrets Operator is used to pull the Squid Root CA securely from a Vault. All that is mapped to a Deployment and exposed with a LoadBalancer type Service via MetalLB which allows the Pod to be exposed on the LAN via a specific IP address.  In case you're not using the configuration based log rotation, there's also an available CronJob object that will connect to the Squid Pod and perform a log rotation to prevent it filling the host file system.

To use it you'll want to fork the repo and make some modifications to those YAML manifest, namely the IP address that is provided by the MetalLB Service.  You may want to mount the host trusted root store as well, or bake it into your own version of the container image.

---

## Using the Squid Proxy

So it's running - now what?

From here you'd use another system to connect to the Squid proxy and configure it to use it as an Outbound Proxy.  This is typically done on Linux via the `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` environment variables, though there are some things like `dnf` that have proxy configuration set in a file.

There are also `http_proxy`, `https_proxy`, and `no_proxy` variables available as well - depending on what binary/runtime is being used, it may use one or the other casing.  There's a great article here called ["We need to talk: Can we standardize NO_PROXY?"](https://about.gitlab.com/blog/2021/01/27/we-need-to-talk-no-proxy/) that goes into the details of that a little more.

Personally I just export both cases and call it a day:

```bash
export HTTP_PROXY="http://192.168.42.31:3128"
export HTTPS_PROXY="http://192.168.42.31:3128"
export NO_PROXY=".kemo.labs,.kemo.network,localhost,127.0.0.1"

export http_proxy="http://192.168.42.31:3128"
export https_proxy="http://192.168.42.31:3128"
export no_proxy=".kemo.labs,.kemo.network,localhost,127.0.0.1"
```

You'll notice that both the HTTP_PROXY and HTTPS_PROXY parameters are going to the `http` protocol on the Squid Proxy's IP address - this is normal and how most proxies work.  Also you could for all intents and purposes create a DNS A record pointing to that IP and use that instead of the IP - that's just a preference is all really.

With those environmental variables set, you should be able to do something like `curl https://kenmoini.com` and get the HTML output of the page.

If you're seeing a `curl: (60) SSL certificate problem: unable to get local issuer certificate` message then you can run `curl -k https://kenmoini.com` to verify the Squid proxy is operating properly - the `-k` switch just tells curl to ignore SSL validation.  If this works then it means you need to add that Squid Root CA Certificate (not the Private Key!) to your system's trusted root stores - again, those instructions can be found in [my article here](https://kenmoini.com/post/2024/02/adding-trusted-root-certificate-authority/).

### DNF Configuration

In order to have `dnf` use the proxy, you need to set some configuration in `/etc/dnf/dnf.conf`:

```bash
# cat /etc/dnf/dnf.conf
[main]
gpgcheck=False
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False
proxy=http://192.168.42.31:3128
sslverify=False
```

If you're using RHEL then you also need to pass the proxy configuration to the RHSM configuration in `/etc/rhsm/rhsm.conf`:

```bash
# cat /etc/rhsm/rhsm.conf 
# Red Hat Subscription Manager Configuration File:

# Unified Entitlement Platform Configuration
[server]
# Server hostname:
hostname = subscription.rhsm.redhat.com

# Server prefix:
prefix = /subscription

# Server port:
port = 443

# Set to 1 to disable certificate validation:
insecure = 1

# an http proxy server to use
proxy_hostname = 192.168.42.31

# The scheme to use for the proxy when updating repo definitions, if needed
# e.g. http or https
proxy_scheme = http

# port for http proxy server
proxy_port = 3128

# user name for authenticating to an http proxy, if needed
proxy_user =

# password for basic http proxy auth, if needed
proxy_password =

# host/domain suffix blocklist for proxy, if needed
no_proxy = .cluster.local,.kemo.labs,.kemo.network,.svc,.svc.cluster.local,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.0.0/16,192.168.70.0/23
```

That RHSM configuration will bake it into all the managed repo files when a `dnf update` is run.

### OpenShift Configuration

*This article wouldn't be complete without some OpenShift hints!*

In Red Hat OpenShift you can configure the Outbound Proxy via the Cluster Proxy object - you'll need to provide the Squid Root CA Certificate to the cluster as a ConfigMap.  THe instructions can be found here: https://docs.openshift.com/container-platform/4.15/networking/enable-cluster-wide-proxy.html

That's if your cluster is already up and running - *what about during installation?*

Outbound Proxy configuration can also be set via the Assisted Installer or via the traditional `install-config.yaml` manifest.  The Squid Root CA Certificate is included in the `additionalTrustBundle` part of the specification, and the proxy configuration is provided under the `proxy.{http,https,no}Proxy` specification.  More on that here: https://docs.openshift.com/container-platform/4.15/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-configure-proxy_installing-platform-agnostic

Now, not all Operators will consume the cluster-wide outbound proxy configuration.  In some instances you need to set additional configuration for those and other workloads to use the Squid proxy.  This is typically done by adding proxy environmental variables to the Pods - for the cluster-wide trusted root CA bundle, you can create a ConfigMap and mount it to your containers with something like this:

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: trusted-ca
  labels:
    config.openshift.io/inject-trusted-cabundle: 'true'
data: {}
```

That label will have OpenShift dynamically inject all the system and additional trusted Root CA as a bundle into the `.data['ca-bundle.crt']` key of the ConfigMap.  This is then mounted to the container, the location of which is dependant on whatever OS base image the container uses.  For a Fedora/RHEL/UBI based image the Deployment would look something like this:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mirror-server
spec:
  # other parts of the spec omitted for brevity
  template:
    spec:
      volumes:
        - name: trusted-ca
          configMap:
            name: trusted-ca
            items:
              - key: ca-bundle.crt
                path: tls-ca-bundle.pem
      containers:
        - name: mirror-server
          image: quay.io/kenmoini/go-http-mirror:latest
          env:
              - name: HTTP_PROXY
                value: "http://192.168.42.31:3128"
              - name: http_proxy
                value: "http://192.168.42.31:3128"
              - name: HTTPS_PROXY
                value: "http://192.168.42.31:3128"
              - name: https_proxy
                value: "http://192.168.42.31:3128"
              - name: NO_PROXY
                value: ".kemo.labs,.kemo.network,.svc.cluster.local,.cluster.local,.svc,10.128.0.0/14,127.0.0.1,172.30.0.0/14,192.168.0.0/16"
              - name: no_proxy
                value: ".kemo.labs,.kemo.network,.svc.cluster.local,.cluster.local,.svc,10.128.0.0/14,127.0.0.1,172.30.0.0/14,192.168.0.0/16"
          volumeMounts:
            - mountPath: /etc/pki/ca-trust/extracted/pem
              name: trusted-ca
              readOnly: true
```

---

And there you have it - a crash course in running an Outbound Proxy for disconnected networks...*or ya know, other reasons.*

You can also use the Squid proxy for a variety of other services, even with your web browser if you want.  Some web browsers have their own Proxy configuration, some rely on the operating system level configuration.

Squid is a versatile service and this only really scratches the surface of what you can configure - back in the day we used it to snoop on unencrypted connections that were passing credentials and would post them to the Wall of Shame...*those were the days*.  Anywho, have phun!