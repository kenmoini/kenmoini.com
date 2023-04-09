---
title: "NextCloud in Nine Minutes - Quickstart"
date: 2021-11-26T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/nextcloud-nine-minutes.png
tags:
  - homelab
  - cloud
  - nextcloud
  - storage
  - libvirt
  - kvm
  - qemu
  - dns
  - freeipa
  - ldap
  - smtp
  - sendgrid
authors:
  - Ken Moini
---

> I am so tired of deploying NextCloud...

I have ***STRUGGLED*** for the last few months when it comes to my storage.

I set out to deploy a proper NAS - *custom built!*  It came with *custom problems!*

In the end, I bit the bullet and just bought a QNAP NAS and am retooling the custom NAS into a computation node.

Since I've gone through storage configurations like mad I've had to redeploy a few things, like ***[NextCloud](https://nextcloud.com/)*** and tried a number of different ways to do so - this is the way I deploy with minimal effort in the fastest method possible.

---

## Create a VM

I love putting things in containers but honestly it's just so much easier in a VM so just make a small 4GB 2Core VM and call it day - I choose to run Ubuntu 20.04 LTS.

Make sure to configure the VM with a static IP, which is really easy to do during installation.

---

## Out of the Box Configuration

Just some basic steps, updates and whatnot:

{{< code lang="bash" line-numbers="true" >}}
## Switch to root
sudo -i

## Set a hostname
hostnamectl set-hostname nextcloud.example.com

## Update system software
apt update
apt upgrade -y

## Install needed packages like the NFS client
apt install -y nfs-common

## Reboot
systemctl reboot
{{< /code >}}

You may also need to set some file/user/group permissions to access certain data served by NextCloud - data is accessed by the `www-data` user/group which will need read (and write maybe) access to the files being served by NextCloud.

---

## Mount NFS Storage

Before installing NextCloud attach the NFS storage to the VM host - assuming you have the ACLs and exports in place for the host to access the data:

{{< code lang="bash" line-numbers="true" >}}
NFS_HOST="deep-thought.kemo.labs"
NFS_SHARE="/nextcloud"
MOUNT_PATH="/mnt/nextcloud_data"

## Create the mount path
mkdir -p $MOUNT_PATH

## See if the NFS Stores are accessible
showmount -e $NFS_HOST

## Mount the NFS Store via /etc/fstab
cp /etc/fstab /etc/fstab.bak-$(date +%s)
echo "${NFS_HOST}:${NFS_SHARE}   ${MOUNT_PATH}    nfs    rw,relatime   0   0" >> /etc/fstab

## Mount everything
mount -a

## Test the mount
ls -al ${MOUNT_PATH}
{{< /code >}}

Note that you can't mount NFS directories inside of a NextCloud Data Directory - you can mount an NFS store, then configure NextCloud to use a folder in that mounted path as the base Data Directory in the `config/config.php` file.  NextCloud acts funny with NFS...

---

## Installing NextCloud

There are a few ways to do so - the Snap is a pain, just do it the old fashioned way with the Production Installation Script:

{{< code lang="bash" line-numbers="true" >}}
## Switch to root
sudo -i

## Download the script
wget https://raw.githubusercontent.com/nextcloud/vm/master/nextcloud_install_production.sh

## Set executable permissions
chmod a+x nextcloud_install_production.sh

## Run the script
./nextcloud_install_production.sh
{{< /code >}}

{{< imgSet cols="4" name="nextcloud-installer" >}}
{{< imgItem src="/images/posts/2021/11/production-nextcloud-installer.png" alt="Say hello to the text user interface of the NextCloud installer!" >}}
{{< imgItem src="/images/posts/2021/11/additional-apps-for-nextcloud.png" alt="Some suggested additional applications to install" >}}
{{< imgItem src="/images/posts/2021/11/onlyoffice-integrated-nextcloud.png" alt="If using behind a reverse proxy it's suggested to use OnlyOffice" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-script-printout.png" alt="You can access the menus presented by the installer to reconfigure the server with the displayed commands" >}}
{{< /imgSet >}}

With that installation script you'll find that the rest of the process is largely automated with the completion of a few prompts - even adding the `ncadmin` user and group with sudo permissions.

It will prompt you to reboot and you'll need to log in again with the same user to continue the process - in this case that's root so once it reboots just log in and then `sudo -i` to continue the installation process.

---

## Configuring NextCloud

Before starting we'll need to set a little configuration - this is done via a `/var/www/nextcloud/config/config.php` file - the following suggested modifications will assume/do the following:

- Add SMTP mailing with domain-verified SendGrid
- Add a flag for NextCloud to monitor for file system changes
- Add headers for positioning behind a Reverse Proxy
- Override paths and protocols for use behind a Reverse Proxy
- Redefine trusted domains that the NextCloud instance can be accessed from
- Redefine the JPEG Quality
- Redefine log rotation and timezone
- Redefine the dataDirectory (where files are stored)

{{< code lang="php" line-numbers="true" >}}

// ...
// =============================================
// Add the following:

  'filesystem_check_changes' => 1,

  // Reverse proxy stuff
  'trusted_proxies' => 
  array (
    0 => '162.192.162.33',
    1 => '192.168.42.0/24',
  ),
  'forwarded_for_headers' => 
  array (
    0 => 'HTTP_X_FORWARDED',
    1 => 'HTTP_FORWARDED_FOR',
  ),
  'overwritehost' => 'cloud.example.com',
  'overwriteprotocol' => 'https',

  // SMTP Settings
  'mail_from_address' => 'no-reply',
  'mail_smtpmode' => 'smtp',
  'mail_sendmailmode' => 'smtp',
  'mail_domain' => 'example.com',
  'mail_smtpsecure' => 'ssl',
  'mail_smtpauthtype' => 'LOGIN',
  'mail_smtpauth' => 1,
  'mail_smtphost' => 'smtp.sendgrid.net',
  'mail_smtpport' => '465',
  'mail_smtpname' => 'apikey',
  'mail_smtppassword' => 'yourSendGridAPIKey',
// ...

// =============================================
// Change the following:

  // Where can access be provided from
  'trusted_domains' => 
    array (
      0 => 'localhost',
      1 => '192.168.42.25', // The IP of the NextCloud instance
      2 => 'nextcloud',
      3 => 'cloud.example.com',
      4 => 'nextcloud.example.com',
    ),
  'overwrite.cli.url' => 'https://cloud.example.com/',
  'jpeg_quality' => '75',
  'log_rotate_size' => '10485760',
  'logtimezone' => 'America/New_York',

  'datadirectory' => '/mnt/nextcloud_data/data',
// ...
{{< /code >}}

Changes are automatically picked up and used without further intervention.

---

## Apache Virtual Hosts

The automation can sometimes fail when setting the Apache HTTPd Virtual Hosts files - reset them with a quick combo of:

{{< code lang="bash" line-numbers="true" >}}
## Disable all VirtualHosts
a2dissite *.conf

## Disable SSL
a2dismod ssl

## Enable HTTP VirtualHost
a2ensite nextcloud_http_domain_self_signed.conf
{{< /code >}}

This allows for positioning the Nextcloud server behind an [HAProxy Reverse Proxy](https://kenmoini.com/post/2021/10/homelab-haproxy-ingress-with-letsencrypt/) for instance.

---

## LDAP Users with Red Hat Identity Management (FreeIPA)

This was extremely difficult to find out how to set up, especially via LDAPS - here is a cheat sheet for all the things you need to do to get LDAP via FreeIPA/RH IDM working in NextCloud:

1. Log into the NextCloud Web UI as an admin
2. Enable the LDAP Application Plugin
3. Configure the following in Settings > LDAP/AD Integration:

#### Server Tab:

- **Server Host:** `ldap(s)://idm.example.com` - if using LDAPS then it will not validate the connection with a self-signed certificate unless "Turn off SSL certificate validation" is checked in the ***Advanced*** tab of this page.
- **Server Port:** `389` for LDAP, `636` for LDAPS
- **[Bind] User DN:** `uid=admin,cn=users,cn=accounts,dc=example,dc=com`
- **[Bind] User Password:** Give it the password and click *Save Credentials*
- **Base DN:** `dc=example,dc=com`
- Check the box that says **Manually enter LDAP filters**

#### Users Tab:

- **LDAP Query:** `(objectclass=*)`

#### Login Attributes Tab:

- **LDAP Query:** `(&(objectclass=*)(uid=%uid))`

#### Groups Tab:

Limiting to 4 groups:

- **LDAP Query:** `(&(|(cn=nextcloud)(cn=nextcloudadmins)(cn=labadmins)(cn=admins)))`

{{< imgSet cols="4" name="ldap-settings" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-server.png" alt="The basic connection information for the LDAP server." >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-users.png" alt="You may want to narrow down the objectClass since a wildcard is rather broad" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-login-attributes.png" alt="You want to ensure the objectClass matches a certain type and the uid is being aligned" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-groups.png" alt="This example filters to limit to a set of 4 groups" >}}
{{< /imgSet >}}

#### Advanced Tab, Connection Settings:

- **Configuration Active:** Checked
- **Turn off SSL certificate validation:** Checked if self-signed

#### Advanced Tab, Directory Settings:

- **User Display Name Field:** `displayname`
- **Base User Tree:** `cn=users,cn=accounts,dc=example,dc=com`
- **Group Display Name Field:** `cn`
- **Base Group Tree:** `cn=groups,cn=accounts,dc=example,dc=com`
- **Group-Member association:** uniqueMember

#### Advanced Tab, Special Attributes:

- **Email Field:** `mail`
- **User Home Folder Naming Rule:** `cn`

{{< imgSet cols="3" name="ldap-settings-advanced" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-advanced-connection.png" alt="Ensure the configuration is active" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-advanced-directory.png" alt="Provide some schema definitions for the directory" >}}
{{< imgItem src="/images/posts/2021/11/nextcloud-ldap-advanced-special.png" alt="Make sure the user attributes align" >}}
{{< /imgSet >}}

With all that you should be able to test the connection assuming little deviation from the default FreeIPA schema.

---

## Additional NextCloud Configuration

There are a few things to set up before forgetting:

- Set an email for the default admin user under **Settings > Personal > Personal info** or else test messages won't work
- Run by the **Settings > Administration > Overview** page to make sure everything is in tip-top shape - it'll run some basic scans of the configuration and security specifications
- Maybe disable Public Uploads in the **Settings > Administration > Sharing** section
- Increase the password requirements or enforce two-factor authentication and enable anti-virus scans in **Settings > Administration > Security**
- Set a Name and Slogan in **Settings > Administration > Theming**
- Setup Group Folders in **Settings > Administration > Group Folders**

---

## More like, "Next cloud!"

With some of those basics you should be able to share access to this robust and very usable NextCloud instance with users - keep in mind if you configured users via LDAP they need some way to set the password of that user so if that LDAP server isn't accessible externally then you may need to use the internal NextCloud user store.