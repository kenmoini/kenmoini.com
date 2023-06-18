---
title: Nu Mac - who dis?
date: 2023-06-17T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/nu-mac.png
photo_credit:
  title: Tuur Tisseghem
  source: https://www.pexels.com/photo/gray-device-with-apple-logo-on-white-surface-812262/
tags:
  - open source
  - oss
  - homelab
  - apple
  - silicon
  - m1
  - m2
  - macbook
  - mac
  - dotfiles
authors:
  - Ken Moini
---

> Tim Apple has so much of my money

It's no secret that I'm a big fan of Arm architectures.  However, if you told me 3 years ago that I'd be predominantly working on a Mac, I'd have laughed in your face.

Sure, I'd use one for work mostly cause the MacBook Pros more orgs have are rather well equiped - but my primary workstation for years has been a custom built Threadripper workstation and my laptop was a System76 rig that I had a love-hate relationship with.  *It felt like I had every starter Pokemon*.

Now I have:

- An iPhone Pro Max 13
- An iPhone Pro Max 14
- An M1 Max Mac Studio
- An M1 Ultra Mac Studio
- A 16" M1 Ultra MacBook Pro
- A 15" M2 Macbook Air
- An iPad Pro
- An Apple Watch 7
- An Apple Watch Ultra
- Two Apple TV 4Ks
- 4 HomePod Minis
- Two AirPod Pods
- An AirPod Max

The ecosystem and user experience is so well knit, and as far as tools go they're great for my productivity.

---

## Jiving to The New System Blues

The best, yet worst part of any new system is setting it up - there are endless possiblities, a fresh slate to paint upon, but with a crippling feeling that you'll forget to configure or install something that you need.  *Same sorta feeling you get when packing or checking out from a hotel room*.

I like having the same user experience on each system, and one of the reasons I use Git and a Remote SSH interface via VS Code is that I like to be able to immediately pick up my work from where I last left off - no matter what system I'm using.

Since it seems like I'll probably end up buying a few more of these Arm systems over the next few years, I've decided to write up the way that I make them feel like home, and I can go from the box to a useful system in less than an hour.

---

## New System Smell

First thing's first: you of course get through **the Out of the Box Setup Wizard** as quickly as possible - or at least I do so I can launch iCloud and sync down my images and **set my profile picture** to something proper...

{{< imgSet cols="1" name="avatar" >}}
{{< imgItem src="/images/posts/2023/06/awesome-avatar.jpg" alt="The coolest I've ever looked" >}}
{{< /imgSet >}}

From there I **smash that Update button** and make sure to get the latest OS and core apps installed.

Next I **unpin all the useless apps from the Dock** like Numbers, Pages, whatever the hell Freeform is, and all the other things I never use.

After making some room, I'll load up the App Store and **download all my previously purchased and downloaded applications** like Apple Remote Desktop, Microsoft Remote Desktop, and Flow, my focus/Pomodoro timer app.

---

## Software Shotgun

Now that the system is truely a clean slate with some of the Mac-based basics, I use the **[Ninite for Mac called MacApps](https://macapps.link/en/)** to quickly install a few core applications such as Firefox, Chrome, VSCode, Postman, Unarchiver, 1Password, Cyberduck, Viscosity, and VLC...and it all just takes a single command:

```bash
curl -s 'https://api.macapps.link/en/firefox-chrome-vscode-postman-unarchiver-1password-cyberduck-viscosity-vlc' | sh
```

Once that's installed I **log into 1Password** to access my password vault, use that to **log into Chrome**, which syncs my extensions and gets me logged into GMail, **download my Cyberduck and Viscosity licenses**, and add them to the apps.  Then I **import my VPN configs** into Viscosity to make sure I can connect back to my different networks when I'm out and about - again, just imported from iCloud so this is super simple.

The next step is to **sync my VSCode settings**, and I do that with my linked GitHub account so again, just have to log in and enter 2FA via my already logged in 1Password browser session.  All my VSCode extentions and settings sync down, then I just **grab my SSH Keys from** - you guessed it, 1Password, which means I can more or less start working as I would on any other system...a few notes on that later.

---

## Bespoke Button Presses

There are a few apps that I can't so simply download and install, a few more manual button pushes to get there - my standard list now is:

- [Microsoft Office](https://www.office.com/) because it's the standard and I use it for my business and things because you can't really trust Google to keep running services you rely on these days
- [OBS](https://obsproject.com/) for screen recording stuff in more complex ways than the built-in Cmd+Shift+5 recorder can
- [UTM](https://mac.getutm.app/) to run VMs in a nice interface because I'm a noob
- [espressoFlow](https://espres.so/pages/espressoflow) for my  little external monitor I use once a year
- [ZeroTier](https://www.zerotier.com/download/) because I like having another way to VPN back into my labs

Not too bad really - Office just takes logging into, and adding the system to a ZeroTier network is a simple log in and copy/paste/approval process as well.

---

## Dot Files & Homebrew

If you're an experienced Mac user, you may have noticed the absense of Homebrew, everyone's favorite package manager!

Honestly, I don't think it's the best - it's great, don't get me wrong, but there are some things it shouldn't manage the installs and update for, namely apps that have their own built-in self-update proceedures.

That's why I installed my browsers, VSCode, 1Password, etc with MacApps, they don't need a package manager just a quick way to get installed and that's exactly what it does.  For things like `git` and `wget` however, those things certainly benefit from a terminal-based package manager like Homebrew.

And as far as terminal goes, there's also some terminal settings that I like to apply - aliases, binaries, environmental variables, so on.  This is all done **[via Git in a repo called dotfile](https://github.com/kenmoini/dotfiles)**, and synced across all my systems with a few simple commands...also has the benefit of installing Homebrew and all the normal things I need installed with it.

```bash
# Clone the repo into the right place
git clone https://github.com/kenmoini/dotfiles.git ~/.dotfiles

# Install Homebrew and run brew installs
~/.dotfiles/scripts/brew-setup.sh

# For Mac OS X - it is safe to run and re-run
# Sets common configuration settings for the OS and installed applications
~/.dotfiles/scripts/mac-os-setup.sh

# Install Oh My ZSH!
~/.dotfiles/scripts/ohmyzsh-setup.sh

# Link all the files around to the right place
~/.dotfiles/scripts/bootstrap.sh
```

At this point I've got things installed like Golang, hidden files and scroll bars always shown, my shell configured, and more.

Synced "dotfiles" are not a new concept, and it's something I delayed on for a while but with multiple systems or for frequent reformat/reinstalls, it's incredibly valuable.

Since I use ZSH across all my systems, my dotfile repo also works on my Linux OSes - and those are configured usually in Git as well and automated with Ansible.

---

## What about the games?!

Yes yes, I didn't install Steam or Discord, even though it'd be two clicks on MacApps - truth is I don't get to play many games any more...I feel like that rabbit from Alice In Wonderland, so little time and whatnot.

Plus, each system is going to have a slightly different purpose - I do a lot of programming and writing, so this is mostly just my core apps and things.  My Mac Studios and MacBook Pro have Adobe Photoshop, DaVinci Resolve, and Handbrake installed since they're more goaled to media production.

The last thing to is clean up after everything, unmount the DMG images, move the stuff from the Downloads folder to the Trash, and empty the bin.

---

> Then it's time to get to work