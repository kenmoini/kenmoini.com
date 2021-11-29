---
title: "Quick and Dirty - PKI"
date: 2021-12-01T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/quick-n-dirty-pki.png
tags:
  - x509
  - tls
  - ssl
  - openssl
  - openvpn
  - pki
  - privacy
  - open source
  - oss
  - homelab
  - cloud
  - automation
authors:
  - Ken Moini
---

> easy-rsa is not so easy...

I'm so tired of having to click past self-signed certificates so with the 2 hours I have free let's see if I can whip up some x509 PKI for the lab and similar things.

***WARN:*** This is more of a brain-dump for how I do PKI in some of my networks - there are likely gaps in some of the article.  It expands upon the concepts and configuration by [Jamie Nguyen](https://jamielinux.com/docs/openssl-certificate-authority/index.html), [my OpenVPN automation](https://github.com/kenmoini/ansible-openvpn-server/blob/main/tasks/setup_openvpn.yaml), and [Roll Your Own Network](https://roll.urown.net/ca/index.html).

---

## PKI Chain

So today I'll be creating a few Certificate Authorities in a chain roughly like:

- **ACME Root Certificate Authority** - A highly secure and offlined Root CA that will create Intermediate Certificate Authorities that will then handle other processes for different organizations.
  - **ACME Network Intermediate Certificate Authority** - The Intermediate CA for things in the ACME Network namespace, mostly for private services since public services are signed by Let's Encrypt
    - **ACME Network Web Service Signing Certificate Authority** - The Signing CA that will create the certificates used by web services
      - ***.acme.network HTTPS Server Certificate** - The Wildcard Server Certificate used by a web servers at acme.network
    - **ACME Network VPN Service Signing Certificate Authority** - The Signing CA that will create the certificates used by VPN Clients and Servers
      - **ACME Network Canadian OpenVPN Server Certificate** - The Server Certificate used by the Canadian OpenVPN Server
      - **ACME Network Canadian OpenVPN Server, Client Certificate** - The Client Certificate for a user to to connect to the OpenVPN Server

You could add additional Intermediate CAs for other parts of the the overall organization, such as ACME Labs, ACME Studios, etc.  You can also chain Intermediate CAs along as you'd like, but generally want to keep the signing of end-use certificates to Signing CAs.

---

## Generate a Root CA

Let's create the Root CA first which will then create the subordinate CAs.

Kick things off by creating a PKI root (as the root user):

```bash
mkdir -p /root/pki/root-ca/{certs,crl,newcerts,private,intermediates}
chmod 700 /root/pki/root-ca/private
```

### Skeleton Files

A few files are used to keep track of the certificate index, serial numbers, etc - create them as so:

```bash
## Create the Index
touch /root/pki/root-ca/index.txt

## Initiate the starting Serial Number
echo 1000 > /root/pki/root-ca/serial
```

### Root CA Configuration File

OpenSSL uses configuration files to set defaults and save settings in between operations.

Create a file called `/root/pki/root-ca/openssl.cnf` with something along the lines of the following:

```ini
# OpenSSL root CA configuration file.
# Copy to `/root/pki/root-ca/openssl.cnf`.

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = /root/pki/ca
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# The root key and root certificate.
private_key       = $dir/private/ca.key.pem
certificate       = $dir/certs/ca.cert.pem

# For certificate revocation lists.
crlnumber         = $dir/crlnumber
crl               = $dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 7500
preserve          = no
policy            = policy_root

[ policy_root ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_intermediate ]
# The intermediate CAs should only sign signing certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_signing ]
# Allow the signing CAs to sign a more diverse range of certificates.
# See the POLICY FORMAT section of `man ca`.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

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
stateOrProvinceName_default     = New York
localityName_default            = New York
0.organizationName_default      = ACME Corp
organizationalUnitName_default  = ACME Corp InfoSec
emailAddress_default            = infosec@acme.com

[ v3_ca ]
# Extensions for a Root CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for an Intermediate CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_signing_ca ]
# Extensions for a Signing CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ user_cert ]
# Extensions for client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ crl_ext ]
# Extension for CRLs (`man x509v3_config`).
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates (`man ocsp`).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
```

### Root CA RSA Private Key

Next let's create a new RSA Private Key for the Root CA - protect this Private Key, otherwise your whole chain is compromised.  Make sure to give it a good pass phrase as well:

```bash
## Generate the private key
openssl genrsa -aes256 -out /root/pki/ca/private/ca.key.pem 4096

## Set the permissions
chmod 400 /root/pki/ca/private/ca.key.pem
```

### Root CA Certificate

With the configuration and private key in place we can make the Root CA Certificate which will provide the identification of the Root CA:

```bash
## Change directories to make it easier
cd /root/pki/ca

## Create the Root CA Certificate
openssl req -config openssl.cnf \
  -key private/ca.key.pem \
  -new -x509 -days 7500 -sha256 -extensions v3_ca \
  -out certs/ca.cert.pem

## Set the permissions on the certificate
chmod 444 certs/ca.cert.pem
```

My output looked something like this:

```plain
[root@raza ca]# openssl req -config openssl.cnf \
>   -key private/ca.key.pem \
>   -new -x509 -days 7500 -sha256 -extensions v3_ca \
>   -out certs/ca.cert.pem
Enter pass phrase for private/ca.key.pem:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [US]:
State or Province Name [New York]:North Carolina
Locality Name [New York]:Raleigh
Organization Name [ACME Corp]:Kemo Network      
Organizational Unit Name [ACME Corp InfoSec]:Kemo Network InfoSec
Common Name []:Kemo Network Root Certificate Authority
Email Address [infosec@acme.com]:certmaster@kemo.network
```

Verify the Root CA certificate with the following command if you'd like:

```bash
openssl x509 -noout -text -in certs/ca.cert.pem | less
```

---

## Create the Intermediate Certificate Authorities

The Intermediate Certificate Authorities are very similar to the Root CA - they don't sign any individual Certificate Requests, they provide structure and schema to lower subordinate Signing CAs.

### File Structure & Skeleton Files

Organize subordinate CAs into a slugged format of their CommonName - so `Kemo Labs Intermediate Certificate Authority` is transformed into a path-friendly `kemo-labs-intermediate-certificate-authority`.

```bash
## Shotgun both Intermediate CA directories
mkdir -p /root/pki/ca/intermediates/{kemo-labs-intermediate-certificate-authority,kemo-network-intermediate-certificate-authority}/{certs,crl,csr,newcerts,private,signing}

## Set the permissions too
chmod 700 /root/pki/ca/intermediates/{kemo-labs-intermediate-certificate-authority,kemo-network-intermediate-certificate-authority}/private

## Create the Indexes
touch /root/pki/ca/intermediates/{kemo-labs-intermediate-certificate-authority,kemo-network-intermediate-certificate-authority}/index.txt

## Create the initial Serial files
echo 1000 > /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/serial
echo 1000 > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/serial

## Create the Certificate Revocation List initial Serial
echo 1000 > /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/crlnumber
echo 1000 > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/crlnumber
```

### OpenSSL Configuration File

Like the Root CA, the subordinate CAs also need an OpenSSL configuration file so make the following Intermediate CA OpenSSL configuration under any Intermediate CA's directory:

```ini
# OpenSSL intermediate CA configuration file example for an ICA CN="Kemo Labs Intermediate Certificate Authority".
# Copy to `/root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/openssl.cnf`.

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
# Make sure to change this base dir for every intermediate CA
dir               = /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# The root key and root certificate.
private_key       = $dir/private/intermediate.key.pem
certificate       = $dir/certs/intermediate.cert.pem

# For certificate revocation lists.
crlnumber         = $dir/crlnumber
crl               = $dir/crl/intermediate.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 3750
preserve          = no
policy            = policy_intermediate

[ policy_root ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_intermediate ]
# The intermediate CAs should only sign signing certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_signing ]
# Allow the signing CAs to sign a more diverse range of certificates.
# See the POLICY FORMAT section of `man ca`.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_intermediate_ca

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
stateOrProvinceName_default     = New York
localityName_default            = New York
0.organizationName_default      = ACME Corp
organizationalUnitName_default  = ACME Corp InfoSec
emailAddress_default            = infosec@acme.com

[ v3_ca ]
# Extensions for a Root CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for an intermediate CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_signing_ca ]
# Extensions for a signing CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ user_cert ]
# Extensions for client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ crl_ext ]
# Extension for CRLs (`man x509v3_config`).
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates (`man ocsp`).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
```

### Generate the Intermediate CAs Private Keys

Since we have two Intermediate CAs there are two Private Keys to generate in their own paths:

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates

## Create the first Private Key
openssl genrsa -aes256 \
  -out kemo-labs-intermediate-certificate-authority/private/intermediate.key.pem 4096

## Create the second Private Key
openssl genrsa -aes256 \
  -out kemo-network-intermediate-certificate-authority/private/intermediate.key.pem 4096

## Set permissions
chmod 400 kemo-labs-intermediate-certificate-authority/private/intermediate.key.pem
chmod 400 kemo-network-intermediate-certificate-authority/private/intermediate.key.pem
```

### Create the Intermediate CA Certificates & CSRs

Now we can create the Certificates for the Intermediate CAs - very similar to the process before when creating the Root CA Certificate, except this time we'll create a Certificate Request identifying the ICAs, which will then be signed by the Root CA creating the desired Certificate.

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates

## Create the first CSR - reference the ICA OpenSSL Config file
openssl req -new -sha256 \
 -config kemo-labs-intermediate-certificate-authority/openssl.cnf \
 -key kemo-labs-intermediate-certificate-authority/private/intermediate.key.pem \
 -out kemo-labs-intermediate-certificate-authority/csr/intermediate.csr.pem

## Create the second CSR - reference the ICA OpenSSL Config file
openssl req -new -sha256 \
 -config kemo-network-intermediate-certificate-authority/openssl.cnf \
 -key kemo-network-intermediate-certificate-authority/private/intermediate.key.pem \
 -out kemo-network-intermediate-certificate-authority/csr/intermediate.csr.pem
```

With the Intermediate CA Certificate Signing Requests (CSRs) created, we can now sign them with the Root CA:

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates

## Sign the first Certificate Signing Request
openssl ca -config /root/pki/ca/openssl.cnf -extensions v3_intermediate_ca \
  -days 3650 -notext -md sha256 \
  -in kemo-labs-intermediate-certificate-authority/csr/intermediate.csr.pem \
  -out kemo-labs-intermediate-certificate-authority/certs/intermediate.cert.pem

## Sign the second Certificate Signing Request
openssl ca -config /root/pki/ca/openssl.cnf -extensions v3_intermediate_ca \
  -days 3650 -notext -md sha256 \
  -in kemo-network-intermediate-certificate-authority/csr/intermediate.csr.pem \
  -out kemo-network-intermediate-certificate-authority/certs/intermediate.cert.pem

## Set permissions
chmod 444 kemo-labs-intermediate-certificate-authority/certs/intermediate.cert.pem
chmod 444 kemo-network-intermediate-certificate-authority/certs/intermediate.cert.pem
```

### Verify Certificate Chain

You can do a discount-double-check on the signed chain so far:

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates

openssl verify -CAfile /root/pki/ca/certs/ca.cert.pem \
  kemo-labs-intermediate-certificate-authority/certs/intermediate.cert.pem

openssl verify -CAfile /root/pki/ca/certs/ca.cert.pem \
  kemo-network-intermediate-certificate-authority/certs/intermediate.cert.pem
```

---

## Signing Certificate Authorities

We're almost ready to sign and create certificates for use by clients and servers - we just need to create the Signing Certificate Authorities.

### File Structure & Skeleton Files

Touch a few things, echo a couple others...

```bash
## Make the directories for the Signing CAs
mkdir -p /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/{certs,crl,csr,newcerts,private}

mkdir -p /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/{kemo-network-web-service-signing-certificate-authority,kemo-network-vpn-service-signing-certificate-authority}/{certs,crl,csr,newcerts,private}

## Set permissions
chmod 700 /root/pki/ca/intermediates/{kemo-labs-intermediate-certificate-authority,kemo-network-intermediate-certificate-authority}/signing/*/private

## Create the Indexes
touch /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/index.txt

touch /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/index.txt

touch /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/index.txt

## Create the initial Serial files
echo 1000 > /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/serial

echo 1000 > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/serial

echo 1000 > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/serial

## Create the Certificate Revocation List initial Serial
echo 1000 > /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/crlnumber

echo 1000 > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/crlnumber

echo 1000 > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/crlnumber

```

### OpenSSL Configuration File

The Signing CAs have pretty much the same sort of OpenSSL configuration, only changing a few variables is all really:

```ini
# OpenSSL Signing CA configuration file example for an SCA CN="Kemo Labs Web Service Signing Certificate Authority".
# Copy to `/root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/openssl.cnf`.

[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
# Make sure to change this base dir for every signing CA
dir               = /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# The Signing CA key certificate.
private_key       = $dir/private/signing.key.pem
certificate       = $dir/certs/signing.cert.pem

# For certificate revocation lists.
crlnumber         = $dir/crlnumber
crl               = $dir/crl/signing.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 1875
preserve          = no
policy            = policy_signing

[ policy_root ]
# The root CA should only sign intermediate certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_intermediate ]
# The intermediate CAs should only sign signing certificates that match.
# See the POLICY FORMAT section of `man ca`.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = supplied

[ policy_signing ]
# Allow the signing CAs to sign a more diverse range of certificates.
# See the POLICY FORMAT section of `man ca`.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# Options for the `req` tool (`man req`).
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_signing_ca

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
stateOrProvinceName_default     = New York
localityName_default            = New York
0.organizationName_default      = ACME Corp
organizationalUnitName_default  = ACME Corp InfoSec
emailAddress_default            = infosec@acme.com

[ v3_ca ]
# Extensions for a Root CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions for an intermediate CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_signing_ca ]
# Extensions for a signing CA (`man x509v3_config`).
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ user_cert ]
# Extensions for client certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ server_cert ]
# Extensions for server certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ crl_ext ]
# Extension for CRLs (`man x509v3_config`).
authorityKeyIdentifier=keyid:always

[ ocsp ]
# Extension for OCSP signing certificates (`man ocsp`).
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
```

### Generate the Signing CA Private Keys

Just as with all the other CAs we need to set up some Private Keys:

```bash
## Change directories to make commands more digestible
cd /root/pki/ca/intermediates

## Create the Private Keys
openssl genrsa -aes256 \
  -out kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/private/signing.key.pem 4096

openssl genrsa -aes256 \
  -out kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/private/signing.key.pem 4096

openssl genrsa -aes256 \
  -out kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/private/signing.key.pem 4096

## Set permissions
chmod 400 kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/private/signing.key.pem
chmod 400 kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/private/signing.key.pem
chmod 400 kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/private/signing.key.pem
```

### Generate Signing CA CSRs

Now we need some CSRs to be signed by the Intermediate CAs:

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority

## Create the CSR - reference the Signing CA OpenSSL Config file
openssl req -new -sha256 \
 -config openssl.cnf \
 -key private/signing.key.pem \
 -out csr/signing.csr.pem

## Change directory to make commands more digestible
cd /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority

## Create the CSR - reference the Signing CA OpenSSL Config file
openssl req -new -sha256 \
 -config openssl.cnf \
 -key private/signing.key.pem \
 -out csr/signing.csr.pem

## Change directory to make commands more digestible
cd /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority

## Create the CSR - reference the Signing CA OpenSSL Config file
openssl req -new -sha256 \
 -config openssl.cnf \
 -key private/signing.key.pem \
 -out csr/signing.csr.pem
```

### Sign the CSRs

Now that the Signing CAs CSRs are generated we can sign them by the Intermediate CAs and then we're off to signing actual certificates to use!

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority

## Sign the Signing CA CSR with the Intermediate CA - reference the Intermediate CA OpenSSL Config
openssl ca -config openssl.cnf -extensions v3_signing_ca \
  -days 1875 -notext -md sha256 \
  -in signing/kemo-labs-web-service-signing-certificate-authority/csr/signing.csr.pem \
  -out signing/kemo-labs-web-service-signing-certificate-authority/certs/signing.cert.pem
  
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority

## Sign the Signing CA CSR with the Intermediate CA - reference the Intermediate CA OpenSSL Config
openssl ca -config openssl.cnf -extensions v3_signing_ca \
  -days 1875 -notext -md sha256 \
  -in signing/kemo-network-web-service-signing-certificate-authority/csr/signing.csr.pem \
  -out signing/kemo-network-web-service-signing-certificate-authority/certs/signing.cert.pem
  
## Sign the Signing CA CSR with the Intermediate CA - reference the Intermediate CA OpenSSL Config
openssl ca -config openssl.cnf -extensions v3_signing_ca \
  -days 1875 -notext -md sha256 \
  -in signing/kemo-network-vpn-service-signing-certificate-authority/csr/signing.csr.pem \
  -out signing/kemo-network-vpn-service-signing-certificate-authority/certs/signing.cert.pem
```

---

## Generating Certificate Authority Chains

Your different services will likely need to pass along the CA Chain in addition to their own certificates so now that the Root > Intermediate > Signing CA Chain is created we can create it:

```bash
## Cat out the signing > intermediate > root CA certificate files into a chain
cat /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/certs/signing.cert.pem \
 /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/certs/intermediate.cert.pem \
 /root/pki/ca/certs/ca.cert.pem > /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/certs/ca-chain.cert.pem
 
cat /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/certs/signing.cert.pem \
 /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/certs/intermediate.cert.pem \
 /root/pki/ca/certs/ca.cert.pem > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/certs/ca-chain.cert.pem
 
cat /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/certs/signing.cert.pem \
 /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/certs/intermediate.cert.pem \
 /root/pki/ca/certs/ca.cert.pem > /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/certs/ca-chain.cert.pem

## Set permissions
chmod 444 /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/certs/ca-chain.cert.pem
chmod 444 /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-web-service-signing-certificate-authority/certs/ca-chain.cert.pem
chmod 444 /root/pki/ca/intermediates/kemo-network-intermediate-certificate-authority/signing/kemo-network-vpn-service-signing-certificate-authority/certs/ca-chain.cert.pem
```

---

## Generating Server Certificates

Now we're onto the final stretch!  That OpenSSL VPN Server can now finally have an x509 Certificate - those web services can now be deployed with HTTPS!

### Creating a Wildcard SSL Certificate

So I'm doing things the lazy way and I'm just going to create a wildcard certificate for my main services - this just lets me manage fewer certificates is all really.

The process for creating an SSL Certificate for `*.kemo.labs` is pretty simple: create a private key, a Certificate Signing Request with the domain as the CommonName, sign the CSR with the Kemo Labs Web Signing CA, and then package up the CA Chain and Certificate & Key Pair.

```bash
## Change directory to make commands more digestible
cd /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority

## Create a password-less key to prevent Apache/HAProxy/Nginx from prompting for pass phrase on startup (add -aes256 to add a pass phrase)
openssl genrsa -out private/wildcard.kemo.labs.key.pem 4096

## Set permissions
chmod 400 private/wildcard.kemo.labs.key.pem

## Create a CSR - reference the Signing CA OpenSSL Config file
openssl req -new -sha256 -config openssl.cnf \
 -key private/wildcard.kemo.labs.key.pem \
 -out csr/wildcard.kemo.labs.csr.pem

## Sign the CSR with the Signing CA
openssl ca -config openssl.cnf \
  -extensions server_cert -days 375 -notext -md sha256 \
  -in csr/wildcard.kemo.labs.csr.pem \
  -out certs/wildcard.kemo.labs.cert.pem

## Set permissions
chmod 444 certs/wildcard.kemo.labs.cert.pem

## Verify the certificate and chain
openssl verify -CAfile certs/ca-chain.cert.pem certs/wildcard.kemo.labs.cert.pem
```

### Bundling for HAProxy

Now that the wildcard certificate is created we can bundle everything for use with HAProxy:

```bash
## Concatenate the key then certificate chain
cat /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/private/wildcard.kemo.labs.key.pem \
/root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/certs/wildcard.kemo.labs.cert.pem \
/root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/certs/ca-chain.cert.pem > /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/bundle_haproxy-wildcard.kemo.labs.pem

## Set permissions
chmod 444 /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/bundle_haproxy-wildcard.kemo.labs.pem
```

## Adding to the System Root CA Store

Before you can really use the generated Certificates you'll need to add the CA Chain to your system Root CA stores - basically add the ca-chain.cert.pem files to your system store.

```bash
## RHEL 8 Systems
cp /root/pki/ca/certs/ca.cert.pem /usr/share/pki/ca-trust-source/anchors/kemo-network-root-ca.pem

cp /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/certs/intermediate.cert.pem /usr/share/pki/ca-trust-source/anchors/kemo-labs-ica.pem

cp /root/pki/ca/intermediates/kemo-labs-intermediate-certificate-authority/signing/kemo-labs-web-service-signing-certificate-authority/certs/signing.cert.pem /usr/share/pki/ca-trust-source/anchors/kemo-labs-web-sca.pem

update-ca-trust
```