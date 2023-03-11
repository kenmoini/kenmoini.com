---
title: Blog it Out! - Rhymes and Reasons
date: 2023-03-11T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/blog-it-out-rhymes-and-reasons.png
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

> I often need to explain why I do the things I do

So if you've ever looked at blogging, or have in the past there are probably a lot of questions you may have like:

- What blog platform?
- Do I need to manage a server?
- Will there be coding?

So let's address these questions...

---

## What blog platform?

There are plenty of choices out there for you to choose from when it comes to what to run your blog on, such as self-hosted WordPress, the WordPress SaaS, Blogger/Blogspot, Medium, Jekyll, Hugo, and so much more.  Each has its own specific use case and its own trade offs:

- **[Self-hosted WordPress](https://wordpress.org/)** - A great option if you're comfortable with managing a LAMP stack and keeping that stuff up to date.  WordPress offers a very flexible platform.
- **[WordPress SaaS](https://wordpress.com/)** - In case you don't want to get in the SysAdmin game, but still want to use WordPress...just drop in your credit card and you're off to the races.
- **[Blogger/BlogSpot](https://www.blogger.com/)** - This is a free blog service that has been around for decades, a classic.  Really nice if you don't care about many customizations and just want something that works and is no/low cost.
- **[Medium](https://www.medium.com)** - Medium is interesting cause on one hand it's free, you can get some decent outreach because it shares your articles across the network, and so your content is more easily discoverable from other writers in adjacent topics...however, the ownership rights of the content may not fully be yours.
- **[Jekyll](https://jekyllrb.com/)** - Jekyll has a great community and is a long-standing static site generator, however you need Ruby installed on your system which is not a runtime dependency I personally care for.
- **[Hugo](https://gohugo.io/)** - Hugo also has a great community, is a storied static site generator, and is just a binary that runs on any platform with little to no dependencies.  ***It's also what runs this site and what we'll be using.***

There are plenty of other great options out there too such as [Wix](https://www.wix.com), [SquareSpace](https://www.squarespace.com), and [Webflow](https://www.webflow.com) in the don't-make-me-think SaaS department, to something that's very flexible and feature-rich like [Ghost](https://ghost.org/) if you're not afraid of getting your hands dirty.  They all have their benefits and their trade offs when it comes to features, labor, resources, etc - it really just depends on your use case.

---

## Do I need to manage a server?

So if you plan on hosting your blog on the Internet, you'll...*well*, need a place to host it.

You would typically do that with a server of sorts - nowadays this would normally be something like a small VPS, or **Virtual Private Server**, which is basically just a VM running in someone's cloud that you get root access to.  You log in, install things, configure them, start services, and you got yourself a server...to keep patched, and updated, and secure, and backed up, *and and and...*

The great thing about leveraging a static site generator like Hugo is that you end up with files that can be served with a simple web server.  This means you could also just drop these files in an S3 bucket, put some cloud-y CDN caching layer in front of it and essentially get a site hosted for little to no money.

For totally free you could even just drop it in a repo configured to serve static content via GitHub Pages - this gets you something like `https://your-user-name.github.io/repo-name-here/` with the files being served from the root of the repo or a `docs/` folder.

Alternatively, *as a complete foil to this*, you could also put it all in a **lightweight container** running some basic web server like Apache HTTPd or NGINX and run it on a dozen services that run containers from Google Cloud Run to Red Hat OpenShift.

We'll step through how to:

- Run a development server for local and live testing
- Serving it with a simple web server
- Build it into a container image
- Deploy it to a Kubernetes cluster
- Host it on GitHub Pages

This way you can deploy your blog to a platform that can fit your budget and level of effort you want to exert.

---

## Will there be coding?

***That depends.***  The content itself, your blog articles and web pages, by large are going to be in [Markdown](https://www.markdownguide.org/) format which isn't really coding.  So if you find a theme that you love that has everything you want in just the right way...or you just don't care to do any mods, then there really is no coding involved.

However, if you want to add something that your selected theme doesn't have out of the box like search capabilities, or want to adjust a button, change styling, etc then yeah, there's going to be some coding involved.

The good news is that the only coding that's involved is stuff like HTML, CSS, and JavaScript - *stuff that you may remember from theming your MySpace profile*.

There will be some miscelaneous things that we'll build that feel like coding like a Dockerfile and some YAML for GitHub Actions but each step and line will be detailed.

> In the next article of this series, we'll get our hands dirty and get going with Hugo!
