---
title: Node Archiver in 2026
date: 2026-02-22T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/node-archiver.png
photo_credit:
  title: Mahmoud Ramadan
  source: Pexels
tags:
  - node
  - nodejs
  - npm
  - javascript
  - archiver
  - compression
  - zip
  - tar
  - library
  - security
  - open source
authors:
  - Ken Moini
---

> I guess I'm a package maintainer now

So it's no secret that software ecosystem has some problems - when you build an application with Golang, Python, NodeJS, Java, etc you're likely pulling in a few dozen or hundred external libraries to perform various functions.  After all, why would you write from scratch a function that tells you if a [number is even](https://www.npmjs.com/package/is-even) if you can pull in a package from some random stranger off the Internet?

That particular package is one of my favorites because it pulls in its own dependency package called `is-odd`, which in turn pulls in `is-number`.  So even if you're defining a few dependencies, you likely end up with a mess of extra ones that you weren't aware of.

The root of this problem is summed up as something we call the **"Software Supply Chain"** or all the things from all the places that make up an application.  There are a few challenges in maintaining a clean supply chain such as Licensing, not that any one ever pays attention to those - very low risk of that random dude in Nebraska pressing charges for violating a GPL.  Licensing has caused quite a stir in the last few years with various mainstream software packages such as Mongo, Redis, Minio, Elastic, etc refining their licenses to prevent large organizations from taking the software and turning an unfair profit with them.

The biggest problem with the Software Supply Chain though is vulnerability management.  Every day we find new vulnerabilities in software that were previously unknown, undisclosed, or slipstreamed in by a malicious actor.  This isn't even accounting for things like maintainer take overs where a once safe and popular package was given to someone else who found benefit in adding in a crypto stealer.

Unraveling the dependency tree is a challenge - sometimes it's not as easy as just updating a package.  That package may have its own dependencies which are locked to vulnerable versions, or even worse not maintained.

This is a story of that latter case...

---

## Node Archiver

I've been building an [application for simple inventory management](https://github.com/kenmoini/tote-sonar) - it has a feature that lets you export and import your data in a nice archived package.  The foundational functions were complete, user testing passed, everything seemed great.  However, when pushing it up to GitHub and enabling GitHub Actions and Dependabot, I found some serious vulnerabilities in one of the dependencies: [node-archiver](https://github.com/archiverjs/node-archiver), a rather popular.

After [exploring the dependency graph](https://npmgraph.js.org/?q=archiver) I found a number of downstream packages that were vulnerable and needed to be updated - namely around minimatch, glob, tar, and a few others.  Looking at the GitHub Issues online, it seems like I wasn't the only one to make the observation - there are [numerous Issues raised](https://github.com/archiverjs/node-archiver/issues) about different CVEs that affect the archiver package.

There are [multiple Pull Requests](https://github.com/archiverjs/node-archiver/pulls) to patch versions in order to address the security issues, however the maintainer seems to be MIA - the repository has Dependabot and Renovate set up, but automatic merges are disabled (I don't enable them either).

So there is no simple fix to the vulnerabilities like just updating versions because there's no new version that is patched, and it doesn't seem that there's going to be an update made to it any time soon.

---

## Kemo Archiver

So this is where I said ***"how hard could it be?"*** - to maintain a NodeJS package that is.

Evidently, not that hard really - the trickiest part is getting the package up to NPM, bit of a chicken-egg thing there but once you have the initial package created it can easily be updated via CI/CD.

I've created [a fork of the original archiver package](https://github.com/kenmoini/node-archiver), but with the key security patches needed to address the existing CVEs.  I've also included the Renovate and Dependabot to keep things up to date, or at the very least give some visbility into issues before they become so widespread.

You can find the NPM registry page here: https://www.npmjs.com/package/kemo-archiver

It should be a simple drop-in replacement for the original Archiver package, and you can find examples on how to use it with the documentation.

In the years the original Archiver package has languished there have been a few other forks of the package - most seem to address the same issues, I could have probably used one of those but I didn't want to go from a "trusted" yet vulnerable source to another fork by some random dude in Russia.

Am I more trustworthy?  *Probably not, but at least you can count on me not doing stupid stuff like including weird files or credential jackers.* 