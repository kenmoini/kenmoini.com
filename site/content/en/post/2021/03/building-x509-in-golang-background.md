---
title: "Building x509 PKI in Golang - Background - 5 / 100 DoC"
date: 2021-03-15T04:20:47-05:00
draft: false
toc: false
publiclisting: true
aliases:
    - /blog/building-x509-in-golang-background/
hero: /images/posts/heroes/resized/resized-go-pki-background.png
tags:
  - ssl
  - pki
  - x509
  - golang
  - programming
  - rsa
  - security
  - certificates
  - keys
authors:
  - Ken Moini
---

> ***Part 1 of a small series into building a Public Key Infrastructure chain with Golang***

Damned near everything in my lab uses SSL and everything uses self-signed certificates which is really annoying.  I'll probably spend a year of my life simply clicking past the self-signed certificate warnings in browsers logging into my different services.

It's about time to set up a Certificate Authority - but not like I normally do via OpenSSL, it's just hard to manage in the long term.  Plus I forget which levers to pull in the right order in order to do things sometimes.  Yes, it's time to make PKI dummy-proof by writing a Golang app - that serves functions over RESTful HTTP APIs!

## Series Table of Contents

- [Background](https://kenmoini.com/blog/building-x509-in-golang-background/)
- [Directory Structure](https://kenmoini.com/blog/building-x509-in-golang-directory-structure/)
- [File Encryption](https://kenmoini.com/blog/building-x509-in-golang-file-encryption/)
- [Key Pairs](https://kenmoini.com/blog/building-x509-in-golang-key-pairs/)

## PKI Background

Ok so some fundamental information around how things work with x509 PKI, the most common PKI standard used by sites, clients, and more.

When you're using your bank's site, your communications are ***Encrypted*** with x509 SSL certificates *(hopefully...)*

Not only are they encrypted, but the ***Identity*** of your bank's server - this makes sure that *bank.com* is really *bank.com*.

You can ***Verify*** the Identity of the site and know that it's valid because that SSL Certificate is Signed by a Certificate Authority.

Certificate Authorities have the capability to create and sign certificates - there are a number of Root Certificate Authorities that pretty much everyone trusts, these are called the Root Certificate Authorities.  They're usually included in your operating system, browser, etc.

Now, Certificate Authorities can create and sign other sub-Certificate Authorities, or Intermediate Certificate Authorities, and maybe those Intermediate Certificate Authorities can create other sub-Intermediate Certificate Authorities, and so on.

You can verify the chain of Certificate Authorities and their Intermediates along the linked and signed Certificates up and down the chain from your Trusted Root CAs to their subordinates.

You can purchase an Intermediate Certificate Authority from a Trusted Root CA, but that is very costly.  You can also create your own Root Certificate Authority and explicitly add it to your systems Trusted Root store - then any certificates down chain would be trusted on those systems.

***The main take away is that PKI helps establish Identity and Trust for Authentication, Certification, and Encryption purposes through a chain of trust.***

## Keys

It's not just Certificates that makes up a PKI - there are Keys involved as well.

Before you can generate a Certificate, you need a Key Pair.

A Key Pair consists of a Private and a Public Key.  The Private Key is crucial to keep safe - anyone with this key can impersonate your identity, creating, signing, and revoking certificates.  The Public Key is derrived from your Private Key and is able to be public shared.

You may be familiar with Key Pairs for SSH log ins.  Your user on your local terminal generates a Key Pair with `ssh-keygen -t rsa`.  The Public Key is deposited on the remote systems you're going to access - when you log into those remote systems your SSH client uses your Private Key to generate the Public Key and securely sends it to the remote server, where if it matches the Public Key it has on file it allows log in.  This works because again, the Private Key being super secret, the only user who would have access to it would be the intended user, which is why it's seen as a bit more secure than just using passwords.

Before being able to generate a certificate, you need a key pair.  There is no identifying or personal information encoded in these keys, they're just random keys that are supposed to be held only by the intended user.  For Root CAs it's suggested to protect the Private Key with a passphrase and to keep it offline where it cannot be accessed over a network.

## Certificate Requests

Now that you have a Key Pair, you can go straight to creating Certificates, but it's ideal to use Certificate Requests as a precursor.

Certificate Requests are simply a definition of the Subject Information of the intended Certificate that will be generated - the "what" and "where" is being certified.

In the Subject data structure there are fields such as Common Name, Organization, Organizational Unit, Location, and so on that provide identity information.

In addition to the Subject information, you'd sign the Certificate Request with your Private Key - this provides the Identity of the Requester, the "who" is requesting certification.

From there, you pass the signed Certificate Request over to a signing Certificate Authority who will then generate a Certificate from the Certificate Request.

## Certificates

Certificates are the sum of a few parts:

- **From Cert Request** - What it is certifying (a server, a client, a new Certificate Authority, etc)
- **From Cert Request** - The details of what is being certified (server domain, client ID, their organization, where they're located, etc)
- **From Cert Request** - Identity of Requester, derrived from the hash of the Private Key
- **From Signing CA** - Who is Issuing the Certificate (the signing Certificate Authority)
- **From Signing CA** - How long the Certificate is valid for (start and end dates)
- **From Signing CA** - A unique incremented serial number
- **From Signing CA** - The capabilities being provided to the Certificate (server/client/authority/mail/S-MIME/etc)

You generated a Key Pair - made a Certificate Request, signed that with your Private Key.  Now you pass the signed Certificate Request to a Signing Certificate Authority.

The Signing Certificate Authority then extracts information from the Certificate Request and validates the request.  If the request is able to be signed, the Certificate Authority combines the extracted Subject information with its own Issuing information, and then signs it with its own Private Key.  The Certificate signed by the Certificate Authority is then transfered back to the requester to be used.

With that signed Certificate, the requester can then use it to secure communication on their server or authenticate as a client for example.

## Revocations

What if the Authority, Certificate, or Private Key, are compromised?  This is when you need to revoke those compromised certificates and keys and regenerate new ones.

Certificate Authorities have a function as part of the x509 Extensions called Certificate Revocation Lists - Certificate Revocation Lists are unique in that the Certificate Authority generates a CRL from a list of revoked certificate serial numbers.  With that group of revoked serial numbers, it creates a special kind of certificate encoding that data and signs it.  From there, you host that CRL online and with the defined extension in your Certificates clients can check Certificates against that Revocation List.

## Index Databases

There are a number of steps in creating a certificate and the different PKI workflows executes them in the proper order with the right bits.  One commonly overlooked part of that workflow is keeping track of certificates in a Certificate Authority's Index DB.

This Index DB is nothing fancy - it's just a tab-delimited file (`\t`) and has a standard format:

- State: "V" for Valid, "E" for Expired and "R" for revoked
- EndDate: Formatted as YYMMDDHHmmssZ (the "Z" stands for Zulu/GMT, so UTC time...I think...I standardize on Zeroed UTC datetimes)
- Date of Revocation: Same format as "Enddate"
- Serial: Serial of the certificate
- Path to Certificate: Can also be "unknown"
- Subject: Slash-delimited Subject of the certificate

This is an example index file:

{{< code lang="text" >}}
V	310316000000Z		01	unknown	/O=Example Labs/OU=Example Labs Cyber and Information Security/CN=Example Labs Root Certificate Authority
V	240316000000Z		02	unknown	/O=Example Labs/OU=Example Labs Cyber and Information Security/CN=Example Labs Intermediate Certificate Authority
R	240316000000Z	240318000000Z	03	unknown	/O=Example Labs/OU=Example Labs Cyber and Information Security/CN=Example Labs OpenVPN Server
V	240318000000Z		04	unknown	/O=Example Labs/OU=Example Labs Cyber and Information Security/CN=Example Labs OpenVPN Server
{{< /code >}}

This Index file is meant to be modified during the creation and revocation workflow and on a periodic basis to check for Expired Certificates and set a Valid certificate to an Expired certificate in the Index.

Overall it's great for a high-level glance of certificates in the PKI without having to thrash the drive and processor every time something or someone needs to query this information..

## Next Steps

Now, I'm not going to go down the rabbit hole of the whole x509 specification, Extensions, and so on - for the next few articles we'll be building a Golang app that generates a PKI chain to set up encrypted server communication.  I won't dive into the full details of every specially encoded OID and the functions will be minimally viable - for a more complete and feature-rich implementation of PKI in Golang over an API, see my application [Locksmith](https://github.com/kenmoini/locksmith).

In the next article we'll build the PKI file structure and generate Private Key pairs for our custom Root CA!