---
title: Blog it Out! - Getting Started
date: 2023-03-10T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/blog-it-out-getting-started.png
tags:
  - open source
  - oss
  - homelab
  - podman
  - red hat
  - rhel
  - ubi
  - docker
  - containers
  - automation
  - devops
  - gitops
  - developer
  - kubernetes
  - openshift
  - blog
  - blog it out
  - series
  - hugo
authors:
  - Ken Moini
---

> Steal This Blog!  Seriously.

So I have this blog here, and I'm going to show you how to rip it off.  Really.

Ok, please don't rip off my ***content*** because it's:

1. Trash
2. Mine
3. Not yours

The site layout and mechanics though, all fair game.  I won't just link you to the [repo for this site](https://github.com/kenmoini/kenmoini.com), I'll even teach you how to do it from *scratch-ish*, in fact that's what this blog series is all about!

## Blog It Out!

In this ***Blog it Out!*** series I'll tour you through the things you need and need to do in order to get a blog like this - it's really not hard, can be hosted almost anywhere, and it's a bit more secure than you'd think.

In the end, you'll get a fully automated and feature-rich blog, doing all the cool things with containers and Kubernetes, and more.  The series will (probably) go along a little like this:

- **Getting Started** - *(You are here!)*
- Rhymes and Reasons - What we're building, what we're not doing, and why we're doing or not doing any of it.
- Hugo-a-go-go - Setting up the basics of the blog, uploading to GitHub, and some common things to know
- Paint It Black - Themes and how to tame them
- Your First Article - A Hello World of sorts, learning up on Markdown
- Tupperware Time - Containing the blog, pushing to a container registry
- Making It Web Scale - Obligatory time to deploy this static site to a Kubernetes cluster
- Bleeping Bots - Automating the building and delivery with GitHub Actions
- The Million Dollar Blog - Enhancements, upgrades, and next steps

**Do you have to do all this?**  No.

**Can you just deploy the site on a small VPS running httpd/nginx?**  Totally, I'll even show you how.

**Is running a static site on a Kubernetes cluster dope?**  *You'll never feel more powerful.*

## Getting Started

So one thing I won't be getting too deep into in this series is setting up your developer environment because there are so many ways to do it and that's a rabit hole in and of itself.

What you need to come prepared with is:

- **A terminal**.  Either via your Mac terminal, Linux terminal, or via Windows Subsystem for Linux.  Please for the love of all things unholy, don't use Powershell.
- **A web browser**.  Ideally either Firefox or Chrome so you can leverage the DOM inspector and some other tools later on.
- **A GitHub account**.  Yeah, you could use GitLab instead but you're on your own with that one.  Just fucking get a GitHub account cause, surprise: every vendor works with bad agencies like ICE.
- **A Server or a Kubernetes cluster**.  You'll probably want to host this thing somewhere...while you could host it on any simple web server an S3 bucket, or even use GitHub Pages for free, *but a Kubernetes cluster is so much cooler*.  You can probably save some cost by not spinning it up until you have the container ready to rock and roll.  I would suggest either [DigitalOcean](https://m.do.co/c/9058ed8261ee) or [Linode](https://www.linode.com/lp/refer/?r=c4acc0a829d048727ced26c4920968c9bc6597fd).  *Note: those are referal links that benefit both parties.*
- **A Domain Name?** - I mean, you're on my site, KenMoini(dot)com...don't you want your own domain too?  I suggest a registrar like [NameCheap](https://namecheap.com).  This is optional if you're going to use something like GitHub Pages.

Most of that should be pretty low hanging fruit and you may already have it all ready to go.  

The series is comprised of short/sweet/simple, easy to digest articles - and the work that we'll step through should also be able to be completed in an hour or two.

> In the next article of this series, we'll explore why we're doing the things we'll be doing.
