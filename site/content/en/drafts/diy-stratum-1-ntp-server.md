---
title: "DIY Stratum 1 NTP + PTP Server"
date: 2021-11-14T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/diy-ntp-server.png
tags:
  - homelab
  - raspberry pi
  - rpi
  - linux
  - gps
  - gpsd
  - adafruit
  - ntp
  - ptp
  - network time
  - dns
authors:
  - Ken Moini
---

> Look at the time, look at the time, look at the time

I hate being late to things - unless it's a party then one must be fashionably late to arrive and surprisingly early to leave.

The only thing being late yourself is when your systems are late - proper time syncronization is pretty crucial.  So I set out to deploy my own Stratum 1 Network Time Server, without spending more than about $200.

## Overview

Time is not something that most people think of since it's such as low-level foundational technology - computers after all are just glorified programable calculator watches.

Your computers normally reach out to pools of Network Time Protocol (NTP) servers on the internet, there are plenty of options out there to choose from.  This provides easy NTP syncing but the accuracy isn't as good as it could be and it requires a network connection.

So in a disconnected or datacenter environment you'd normally see a slew of different options to provide NTP services locally and to act as a source-of-truth for time from [rackable](https://www.microsemi.com/product-directory/enterprise-network-time-servers/4117-syncserver-s600) [appliances](https://www.ntp-time-server.com/ntp-time-server-appliance/network-time-server-appliance-with-dual-time-source.html) to the latest PCIe cards [made and open-sourced](http://www.opentimeserver.com/) by...Facebook, of all organizations...

These NTP appliances, cards, and servers still need a source for time - usually this is done via GPS/GLONASS, radio broadcasts, or even atomic references.  Those references are considered to be Stratum 0 reference clock - then local time servers are called Stratum 1 that provides NTP/PTP services to Stratum 2 clients and devices.

You can read more about [Stratums and general NTP architecture](https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_strata) all over so I won't bother regurgitating the same notions - let's go about building the Stratum 1 NTP/PTP server.

---

## Target Build

For this deployment we'll be using a Raspberry Pi 3 B+ paired with a [GPS Breakout Board](https://www.adafruit.com/product/746) from Adafruit.  There are a couple of other things such as a [proper RPi-compatible PSU](https://www.amazon.com/gp/product/B00L88M8TE/), SD Card, CR1220 coin cell to keep the RTC running, some wires, some sort of enclosure, and other odds and ends - eventually, you'll be left with something that looks like this:

***INSERT IMAGE OF GPS APPLIANCE***

## Wiring the Boards

With everything in hand, you can now connect the GPS breakout board to the Raspberry Pi - I connected the board via UART as such:

| Rasperry Pi            | GPS |
|------------------------|-----|
| Pin 7, GPIO 4 (GPCLK0) | PPS |
| Pin 2, 5v              | VIN |
| Pin 6, Ground          | GND |
| Pin 8, GPIO 14 (TXD)   | RX  |
| Pin 10, GPIO 15 (RXD)  | TX  |

---

## Raspberry Pi Setup

So this should be pretty general for setting up a Raspberry Pi, you'll image Raspbian to an SD Card, boot it up, and then run some configuration - this is what I did:

- Set Language and Locale
- Set Timezone
- Set a new password for the ***pi*** user
- Expand the filesystem
- Set a Static IP and Hostname
- Disable Wifi and Bluetooth
- Enable SSH
- Disable GUI, boot to the text log in prompt
- Enable I2C and SPI interfaces
- Disable the Serial port, [enable UART](https://learn.adafruit.com/adafruit-nfc-rfid-on-raspberry-pi/freeing-uart-on-the-pi)
- Update all system packages
- Install needed packages
- Bind to Red Hat Identity Management for proper log ins

There are a few ways to do most of that and this is some of how I did it:

{{< code lang="bash" command-line="true" >}}
############################################ Set password for pi user
passwd pi

############################################ Expand the Filesystem
raspi-config --expand-rootfs

############################################ Enable SSH
systemctl enable --now ssh

############################################ Disable Wifi and Bluetooth

## Add `dtoverlay=disable-wifi` and `dtoverlay=disable-bt` to `/boot/config.txt`
cat << EOF >> /boot/config.txt 
## Disable Wifi
dtoverlay=disable-wifi

## Disable Bluetooth
dtoverlay=disable-bt
EOF

## Disable unneeded services
systemctl disable hciuart.service
systemctl disable bluealsa.service
systemctl disable bluetooth.service

############################################ Update system packages
apt-get update && apt-get upgrade -y

## Install FreeIPA Client for RH IDM
apt-get install freeipa-client -y

## Install GPSd and the client library
apt-get install gpsd gpsd-clients -y

## Stop & Disable GPSd daemon
systemctl stop gpsd.socket
systemctl disable gpsd.socket

############################################ Perform misc config via raspi-config
raspi-config

############################################ Reboot
reboot
{{< /code >}}