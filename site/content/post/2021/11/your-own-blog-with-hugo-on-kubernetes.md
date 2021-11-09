---
title: "Your Own Git-driven Blog with Hugo and Kubernetes"
date: 2021-11-08T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/your-own-blog.png
tags:
  - homelab
  - containers
  - kubernetes
  - git
  - cloud
  - dns
  - hugo
  - blogging
  - ingress-nginx
  - cert-manager
  - automation
  - github actions
authors:
  - Ken Moini
---

> We lost the Golden Age of the Internet somewhere between GeoCities and Facebook - and Xanga was so much better the LiveJournal

There are so many people doing really cool things that just need a place to live and be shared from - of course there's the usual Mediums, Dev.to, and Hashinode...which really is a tragic name because I think it's just some weird new Hashicorp product and couldn't bring myself to even publish a single article there.  Speaking of articles published elsehwere, I should probably import my Dev.to posts to this blog...

Anywho - what if you want to forgo having your content on some other platform, hosting it yourself without having to go through all the tedium of something like WordPress?  Ask yourself the following questions:

- Can you use and write in Asciidoc or Markdown?
- Is most of the content static, outside of maybe something like Comments?
- Do you want to be able to deploy your blog on VMs or in containers, maybe even onto Kubernetes without much funny business?

***If so, then [Hugo](https://gohugo.io/) is for you!***

Follow along for a step-by-step tutorial on how I built this very blog and how you can too - just make sure to change your answers a bit so it doesn't look exactly like mine, eh?

## What is Hugo?

[Hugo](https://gohugo.io/), much like [Jekyll](https://jekyllrb.com/) and many of its ilk, is a Static Site Generator - meaning it takes content from Asciidoc or Markdown and turns it into static HTML with the needed CSS and JavaScript.  No databases, no extra runtimes, just serve it via any HTTP server.

This works out for more situations than you'd think of initially - 

Static sites also have the benefit of a smaller surface area for attacks - no Drupal or PHP to exploit, fewer plugins to XSS, no unstanitized inputs streamed into a database.  Note that you're likely to have some Javascript on the site, and you can still use this as the frontend in a classic 3-tier architecture

## Building a new Hugo site

## Finding & Using a Theme

## General Configuration & Settings

## Basic Theme Modifications

## Adding Spice - Analytics