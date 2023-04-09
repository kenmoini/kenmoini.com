---
title: "Wrangling Bluetooth in RHEL & CentOS 7"
date: 2018-05-15T22:31:48-05:00
draft: false
publiclisting: true
aliases:
    - /blog/wrangling-bluetooth-on-rhel-and-centos/
hero: /images/posts/heroes/resized/resized-bluetooth-rhel.png
tags: 
  - audio
  - bluetooth
  - bluez
  - bt
  - centos
  - galago pro
  - headphones
  - headset
  - linux
  - pulseaudio
  - red hat
  - rhel
  - system76
authors:
  - Ken Moini
---

I recently started as the Lead Solution Architect at Fierce Software. It’s been an excellent experience so far and I’m excited to be working with such a great team. At Fierce Software we help Public Sector entities find enterprise ready open source solutions. Our portfolio of vendors is deliberately diverse because in today’s enterprise multi-vendor, multi-vertical solutions are commonplace. No one’s running all Cisco network gear, Cisco servers, annnnd then what’s after that? They don’t have a traditional server platform, even they partner with Red Hat and VMWare for that. We help navigate these deep and wide waters to find your Treasure Island (no affiliation).

{{< figure src="/images/posts/legacyUnsorted/20180514_161602-1024x768.jpg" target="_blank" class="col-sm-12 text-center img-responsive" caption="These cards are Fierce..." >}}

Starting a new role also comes with some advantages such as a new work laptop. I’ll be traveling regularly, running heavy workloads such as Red Hat Satellite VMs, and balancing two browsers with a few dozen tabs each (with collab and Spotify in the background). Needless to say, I need a powerful, sturdy, and mobile workhorse with plenty of storage.

A few years ago that would have been a tall order, or at the very least an order that could get you a decent used Toyota Camry. Now this is possible without breaking the bank and while checking all the boxes.

Enter System76’s 3rd generation Galago Pro laptop. Sporting a HiDPI screen, 8th generation Intel Core i7, an aluminum body, backlit keyboard, and plenty of connectivity options. This one is configured with the i7-8550U processor for that extra umph, 32GB of DDR4 RAM, Wireless AC, a 500gb m.2 NVMe drive, and an additional 250GB Samsung SSD. That last drive replaced a configured 1TB spinner that I toss in an external enclosure and replaced with a spare SSD I had around. Great thing about System76’s Galago Pro is that it’s meant to be modified so that 250GB SSD I put in will later be replaced with a much larger SSD.

At configuration you have the option of running Pop!_OS or Ubuntu. Being a Red Hat fan boy, I naturally ran RHEL Server with GUI. Why RHEL Server instead of Desktop or Workstation? Mostly because I have a Developer Subscription that can be consumed by a RHEL Server install, and it can run 4 RHEL guest VMs as well. If you’ve ever used enterprise-grade software on commodity, even higher-end commodity hardware, you might have an idea of where this is going...

## Problem Child

One of the benefits of Red Hat Enterprise Linux is that it is stable, tested, and certified on many hardware platforms. System76 isn’t one of those (yet). One of the first issues is the HiDPI screen, not all applications like those extra pixels. There are some workarounds, I’ll get to that in a later post. System76 provides drivers and firmware updates for Debian-based distributions so some of their specialized configuration options aren’t available naturally. These are some issues I’ll be working on to produce and provide a package to enable proper operation of Fedora/RHEL based distributions on the Galago Pro. More on that later...

The BIGGEST issue I had was with Bluetooth. This is not inherent to System76 or Red Hat. It’s actually (primarily) a BlueZ execution flag issue and I’ll get to that in a moment...

Essentially my most crucial requirement is for my Bluetooth headset to work. We use telepresence software like Google Hangouts and Cisco WebEx all day long to conduct business and a wired headset is difficult to use and especially when mobile. I spent probably half a day trying to get the damned thing working.

I attempted to connect my headset with little success, it kept quickly disconnecting. I paired the Galago Pro to one of my Amazon Echos and it worked for a few minutes then began distorting and skipping. I plugged in a USB Bluetooth adapter, blacklisted the onboard one, still had the same issues. Must be a software thing...

## Have you tried turning it on and off again?

Part of the solution? Buried in an Adafruit tutorial for setting up BlueZ on Raspbian on a Raspberry Pi…
Give up and search Google for “best linux bluetooth headset” and you get a whole lot of nothing. Comb through mail-lists, message boards, and random articles? Nowhere and nada.
Give me enough time and I can stumble through this Internet thing and piece together a solution though.

{{< figure src="/images/posts/legacyUnsorted/20180515_144856-1024x768.jpg" target="_blank" class="col-sm-12 text-center img-responsive" caption="The plaintiff, a hot shot SA determined to have his day in wireless audio; the defendant, an insanely stable platform" >}}

Essentially I’ll (finally) get to the short part of how to fix your Bluetooth 4.1 LE audio devices in RHEL/CentOS 7. Probably works for other distros? Not sure, don’t have time to test. All you have to do is enable experimental features via a configuration change….and set a trust manually…and if you want higher quality audio automatically, create a small file in /etc/bluetooth/...

## Step 1 – Experimental Features

So you want to use your nice, new, BLE 4.1 headset with your RHEL/CentOS 7 system…that low energy stuff is a little, well…newer than what is set by default so we just need to add a switch to the Bluetooth service execution script to enable those “fresh” and “hot” low energy features...

{{< code lang="bash" command-line="true" >}}
sudo nano /lib/systemd/system/bluetooth.service
{{< /code >}}

Enable the experimental features by adding –experimental to the ExecStart line, for example the configuration should look like:

{{< code lang="ini" line-numbers="true" >}}
...
[Service]
Type=dbus
BusName=org.bluez
ExecStart=/usr/local/libexec/bluetooth/bluetoothd --experimental
NotifyAccess=main
...
{{< /code >}}

Save the file and then run the following commands:

{{< code lang="bash" command-line="true" >}}
sudo systemctl daemon-reload
sudo systemctl restart bluetooth
{{< /code >}}

## Step 2 – Set Trust

So you’ll find that some of the GUI tools might not coordinate a Bluetooth device pair/trust properly…it only has to manage between the service, BlueZ daemon, and Pulseaudio (!), what is so difficult about that?
Let’s just take the headache out of it and load up bluetoothctl, list my devices, and set a manual trust. This is assuming you’ve at least paired the BT device with the GUI tools, but it might vibrate oddly or disconnect quickly after connecting. There are ways to setup pairing via bluetoothctl as well, but the help command and manpages will go into that for you.

{{< code lang="bash" command-line="true" output="3" >}}
sudo bluetoothctl
> devices
  Device XX:XX:XX:XX:XX:XX
> trust XX:XX:XX:XX:XX:XX
{{< /code >}}

## Step 3 – Create /etc/bluetooth/audio.conf

So now we have it paired, trusted, and the newer BLE 4.1 features enabled. If your BT headset also includes a microphone for call functionality, you might find the headset auto-connecting to the lower quality HSP/HFP profile. We want that tasty, stereo sound from the A2DP profile. Let’s tell the BlueZ daemon to auto-connect to that A2DP sink.

{{< code lang="bash" command-line="true" >}}
$ sudo echo "AutoConnect=true" > /etc/bluetooth/audio.conf
$ sudo systemctl restart bluetooth.service
{{< /code >}}

Now, turn off and on your headset, it should auto-connect, and your Bluetooth 4.1 LE headphones should work all fine and dandy now with high(er) fidelity sound!