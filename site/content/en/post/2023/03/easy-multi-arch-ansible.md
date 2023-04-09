---
title: "Easy Multi-Architecture Ansible"
date: 2023-03-25T04:20:47-05:00
draft: false
toc: false
publiclisting: true
hero: /images/posts/heroes/multi-arch-ansible.png
tags:
  - homelab
  - ARM
  - arm64
  - x86
  - x86_64
  - x86-64
  - i386
  - i686
  - aarch64
  - ansible
  - collections
  - roles
authors:
  - Ken Moini
---

> ARM can sometimes be a pain in the ARSE

---

Lately I've been collecting a variety of different computing architectures - from a 32-bit Motion Computing tablet that is super cool but that the Internet hates - to some new ARM servers powered by [Ampere Altra CPUs](https://www.servethehome.com/raspberry-pi-cluster-versus-ampere-altra-max-supermicro-arm-server/) in the [AVA](https://www.ipi.wiki/products/ava-developer-platform) and [AADP](https://www.ipi.wiki/products/ampere-altra-developer-platform) kits.  Oh, and I got one of those blue iMAC G3 systems for a little taste of nostalgia too.

Now, some of these systems I've been adding to my normal automation routines - the AVA Dev Kit runs RHEL so I just automate it the same for the most part.  There are a few differences however, even on the same system.

For instance, when adding my ARM 64 systems to my general system configuration Ansible Automation workflows, I found myself having to change out links to binaries and ISOs and the such that had `x86_64` hard-coded in the URLs that needed to be replaced with `aarch64`.  *Unless I was getting some Debian-based thing*, then I needed to replace it with `arm64`.

---

## The Birth of a Collection

So since multi-architecture automation is a thing to stay here for me and will only be expanding, I needed a way to easily figure out the relevant architecture information to use in my workflows.

To that end, I created a new Ansible Collection.  A buddy of mine, Tosin Akinosho, built an Ansible Collection and I thought that was pretty cool and figured it'd be a great way to port around some common architecture detection tasks.  It can detect a combination of:

- x86 32-bit
- x86 64-bit
- ARM 64-bit

For Debian and RHEL type of notations.  I don't have an AIX or Solaris system to test against *sooo...yeah...*

> Introducting kenmoini.kemo

***Clever, I know.***

My first, and a super simple general catch-all Ansible Collection, but something that lets one perform architecture detection and setting of some useful facts/variables in just 3 lines of YAML!

You can find the collection at https://github.com/kenmoini/ansible-collections

---

## Using the Collection

To use the collection and start detecting architectures yourself, you need to install the Collection, and then import the Role into your Playbook.

### Installing the Collection

You can either install the Ansible Collection with the command-line:

{{< code lang="bash" cmd="true" output="1" >}}
# Install the Collection if you're an Ansible CLI user
ansible-galaxy collection install kenmoini.kemo
{{< /code >}}

Alternatively, use the a `collections/requirements.yml` file in your repo if you're wanting to install multiple Collections/Roles, and/or use it in Ansible Tower/Controller:

{{< code lang="yaml" line-numbers="true" >}}
# your collections/requirements.yml file
---
collections:
  - name: kenmoini.kemo
  #- name: other.collections
{{< /code >}}

---

### Using the Collection

Simply import the `architecture_helper` Role into you Playbook, and you'll find 3 new facts/variables set, `detected_architecture`, `rpm_architecture`, and `deb_architecture`:

{{< code lang="yaml" line-numbers="true" >}}
---
- name: Example for kenmoini.kemo.architecture_helper
  hosts: some_host_pattern
  tasks:

    - name: Import Role
      import_role:
        name: kenmoini.kemo.architecture_helper

    - name: Debug set variables
      ansible.builtin.debug:
        msg:
          - "detected_architecture: {{ detected_architecture }}"
          - "deb_architecture: {{ deb_architecture }}"
          - "rpm_architecture: {{ rpm_architecture }}"
{{< /code >}}

Now when you download things such as OpenShift binaries, Ubuntu ISOs, etc, you can have a few easy to use variables that can adapt across Debian and RHEL based systems, on 32 and 64 bit architectures!