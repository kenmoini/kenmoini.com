---
title: "New Year, New Fedora WSL Distro - 1 / 100 DoC"
date: 2021-01-01T21:02:47-05:00
draft: false
toc: false
aliases:
    - /blog/new-year-new-wsl/
hero: /images/posts/heroes/new-fedora-wsl.png
tags:
  - new years
  - 100 days of code
  - 100doc
  - windows
  - microsoft
  - windows subsystem for linux
  - wsl
  - fedora
  - containers
  - developer
  - powershell
  - bash
  - automation
  - github
authors:
  - Ken Moini
---


> ***By hell or high water, I will do this 100 Days of Code this year...not to say I didn't produce code/content last year, I just didn't hit a good stride of writing about it...***

I'm building an automated Kubernetes cluster on Fedora CoreOS and in order to boot FCOS you need to construct some YAML, then you use a binary to convert into formatted JSON, which is then fed to the FCOS machine when booted like a cloud-init input.

Funny thing - I develop mostly on my main Windows workstation, which has VS Code and Windows Subsystem for Linux that passes an Ubuntu WSL interface which evidently is too old to run that binary in order to convert the YAML to JSON which leaves me stuck in my development and testing of this automation.  Yay!

{{< center >}}![Side Quests, Side Quests everywhere](/images/posts/legacyUnsorted/k8sRunningAwayBalloon.jpg){{</ center >}}

Guess it's time to make a new WSL distro, and since I know the binary I'm trying to use works on Fedora, `fcct` for anyone who's wondering, I'll build a new Fedora 33 WSL distro.

I've taken the liberty to also automate most of the steps required to set up a pretty solid Fedora 33 WSL distro, and should make it pretty easy for anyone who wants to get up and running quickly.

#### You can find all the resources at this GitHub repository: [wsl-helper on GitHub by Ken Moini](https://github.com/kenmoini/wsl-helper)

## 1. Create the base WSL distribution instance

From that repo linked right above, find the `setup_fedora_wsl_distro.ps1` file and run it on the Windows system you want to deploy Fedora 33 to - if you'd like to do that automatically, run the following line in an Administrative Powershell terminal window:

```powershell
$ScriptFromGitHub = Invoke-WebRequest "https://raw.githubusercontent.com/kenmoini/wsl-helper/main/setup_fedora_wsl_distro.ps1"; Invoke-Expression $($ScriptFromGitHub.Content)
```

That Powershell script doesn't do too much magic:

- Creates temporary working directories
- Downloads needed xz extraction tool
- Downloads Fedora 33 system root base volume, from official container image source on GitHub
- Decompress the base volume
- Adds the base volume to a new WSL distribution called `Fedora33`
- Cleans up after itself by deleting temporary files
 
You can also download that Powershell script and modify before running with the following one-liner:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kenmoini/wsl-helper/main/setup_fedora_wsl_distro.ps1" -OutFile ".\setup_fedora_wsl_distro.ps1"
```

Then you could also optionally pass the `-reset` and/or `-keepCache` switches to the Powershell script which will either reset everything and start from scratch, or keep the local temporary files cached.  The combination of those two switches via `.\setup_fedora_Wsl_distro.ps1 -reset -keepCache` will allow automatic & quick development/testing of new bootstraping assets in case you are modifying the scripts.

***Quick note on WSL 1 vs WSL 2:*** WSL 2 is technically a tiny little VM running on a thin hypervisor in Windows - if you use VMWare Workstation like I do, WSL 2 will not work.

## 2. Configure the new Fedora33 WSL distro

Now that we have the base vanilla Fedora33 distribution added to WSL, we need to configure it.  This is where it's very much a per-developer thing, tasks such as adding a user, if you need Python or GOLANG installed, ZSH as your shell, etc configuration.

Thankfully, I've got most of that set up in an automated script that lets you flip switches on/off to quickly install things such as PHP+Composer, and/or GOLANG, and/or NodeJS, etc!

At the Powershell terminal, run the following commands to download the configuration script to your Fedora33 WSL distro and subsequently run it:

```powershell
wsl -d Fedora33 curl -sSL -o /opt/wsl_setup.sh https://raw.githubusercontent.com/kenmoini/wsl-helper/main/configure_wsl_fedora.sh
wsl -d Fedora33 bash /opt/wsl_setup.sh
```

This will launch the interactive script, prompting you for input to:

- Add a user
    - Option for adding to sudoers/wheel
- Install:
    - Language packs
    - The "Development Tools" package group
    - GOLANG
    - Kubernetes and OpenShift binaries, auto-completion for Bash
    - NodeJS + NPM + YARN
    - PHP + Composer
    - Python 3 + PIP
    - Ansible + Auto-completion (Depends on Python 3 option)
    - ZSH + OhMyZSH + thefuck + Powerline fonts (Depends on Python 3 option)

Otherwise, on every run of that script it will update the WSL distro, install a COPR for WSL Utilities and install it, install basic packages and language packs.  If a user is provided it will be set as the default user for the WSL distro, and if ZSH is also enabled the shell for that user will be changed to ZSH.

## 2.5. Bonus Steps

### Setting the Fedora33 WSL distro as the default

If you open WSL with the `wsl` command, then it loads your default WSL distro - if you want that default distro to be the new Fedora33 distro we just created, run the following Powershell command:

```powershell
wsl --set-default Fedora33
```

***Note*** that you will need to figure out how to move your files across distros, and can access the other distros on your system with a combination of `wsl -l -v` and `wsl -d DISTRO_NAME_HERE`

## 3. Wrapping it up

Now that I have a new and updated Fedora 33 WSL distro, I can test my objective with Fedora CoreOS Config Transpiler (fcct, the binary that wasn't working earlier due to an old version of glibc6 in the Ubuntu WSL distro).  I ran the following command at the Powershell terminal to jump into a Fedora33 distro shell:

```powershell
wsl -d Fedora33
```

With that, ran the following in the Bash terminal to test `fcct`:

```bash
$ sudo curl -o /usr/local/bin/fcct -sL https://github.com/coreos/fcct/releases/download/v0.8.0/fcct-x86_64-unknown-linux-gnu
$ sudo chmod +x /usr/local/bin/fcct

$ cat <<EOF >>ignition_test.yaml
variant: fcos
version: 1.2.0
EOF

$ fcct ignition_test.yaml
{"ignition":{"version":"3.2.0"}}
```

{{< center >}}![AWWWWYEAH](/images/posts/legacyUnsorted/yesbitchyes.gif){{</ center >}}

w00t!  *Now, what was I doing with that fcct thing again...?*  Working with computers involves a lot of side quests, it's like Fallout/Skyrim but without the fun of being irradiated into a Ghoul or slaying dragons and joining a Thieves Guild.

#### You can find all the resources at this GitHub repository: [wsl-helper on GitHub by Ken Moini](https://github.com/kenmoini/wsl-helper)

There are some additional resources in that repo that help make things work, such as the `~/.zshrc` file and other glue.  I suggest checking it out, forking it, making it your own, contributing changes, whatever you'd like, that's Open-Source, baby!