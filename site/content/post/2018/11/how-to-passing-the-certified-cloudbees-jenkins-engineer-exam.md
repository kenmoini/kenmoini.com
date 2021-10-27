---
title: "How-to: Passing the Certified Cloudbees Jenkins Engineer exam"
date: 2018-11-01T22:31:48-05:00
draft: false
aliases:
    - /blog/how-to-passing-the-certified-cloudbess-jenkins-engineer-exam/
hero: /images/posts/heroes/resized/resized-how-to-ccje-exam.png
tags: 
  - ccje
  - certification
  - certified
  - cje
  - cloudbees
  - cloudbees certified jenkins engineer
  - continuous delivery
  - continuous deployment
  - continuous integration
  - devops
  - engineer
  - FOSS
  - jenkins
authors:
  - Ken Moini
---

Well, add another notch in my tool belt, I recently became a CCJE or CCJPE or whatever they’ll call it in a few months.
Basically, that means I’ve attained the recognition of being a [Certified Cloudbees Jenkins Engineer](https://www.cloudbees.com/jenkins/jenkins-certification).

## What the frack?

{{< figure src="/images/posts/legacyUnsorted/devOpsSoHot.png" class="col-sm-12 text-center" >}}

If you haven’t heard of DevOps, it’s basically the new way of doing software development.  Ok, it’s not that new, but it’s now something that can’t be avoided.  Agility is king and that agility can make or break whole industries, tenured titans, and define how we as a society work.  Ok, maybe it doesn’t have quite that crucial of an effect and reach, but if you don’t know, now you kinda know and go out there and read some books and stumble around Wikipedia for a while on the DevOps side of things.  Actually, you should start your search with [Jenkins](https://en.wikipedia.org/wiki/Jenkins_(software))...

**Jenkins** is pretty much the king of the DevOps CI/CD automation/orchestration world.  Very versatile, long-running history, most used CI/CD platform out there, the list of flatteries goes on.

{{< figure src="/images/posts/legacyUnsorted/jenkinsSprawl_trans-711x1024.png" class="col-sm-12 text-center white-bkg" >}}

[Cloudbees](https://www.cloudbees.com/) is the company behind Jenkins and they provide two certification options: **Certified Jenkins Engineer (CJE)** which is for the open-source centric part of Jenkins, and then there’s the one I obtained which is called **Certified Cloudbees Jenkins Engineer (CCJE)** which is everything from the CJE with an extra 30 questions over the enterprise version of Jenkins, [Cloudbees Core](https://www.cloudbees.com/products/cloudbees-core).  Both exams are multiple choice, either 60 or 90 question over a 60 or 90 minute time period.  Taking and passing the Certified Cloudbees Jenkins Engineer (CCJE) exam will also cover and count for the content covered in the CJE exam.  Considering the company I work for just won [Public Sector Partner of the Year](https://www.cloudbees.com/press/second-annual-devops-world-awards-program-honors-jenkins-contributors-and-devops-innovators) from Cloudbees I decided to go for the gusto and go for the bigger, badder, DevOps-y-er CCJE exam to get what I feel to be a two-for-one, or maybe more closely to...ah whatever, you get the idea, it’s mo betta.

Most of what I’ve mentioned is all listed online in the [Jenkins Certification page](https://www.cloudbees.com/jenkins/jenkins-certification) of the Cloudbees site, and even more is available on their site regarding the exams so there haven’t been any real secrets given about the exam.  I also can’t really say too much regarding the specifics of the exam, no-cheat/no-tell NDA and all.  What I can tell you about is my experience with studying and preparing for the exam.

## Study Material

First, let’s start with some resources that I used to help me study...

- **Take a look, it’s in a book** – I never appreciated Reading Rainbow as much as I should have, but thankfully I read [physical books] more than ever now; thanks LeVar!
I’d highly recommend [Jenkins 2.x Continuous Integration Cookbook (Third Edition)](https://amzn.to/2XXOZWM).  Great way to bootstrap getting your hands dirty with Jenkins and some of the best practices available.  Knowing these best practices and how they relate to the enterprise product Cloudbees Core (or Cloudbees Jenkins Enterprise as referred to before) is extremely important for the CCJE as it is focused on the enterprise.  Of course, the enterprise product isn’t covered in the open-source centric CJE, but best practices are still great to know so you can easily map how things should interact.

- **From the Horse’s Mouth** – While I was working for Red Hat I was fortunate enough to have access to a [Red Hat Learning Subscription](https://fiercesw.com/shop/red-hat/red-hat-learning-subscription) which is pretty much all the training Red Hat produces, in addition to labs, practice exams, and so on.  It really set me with an appreciation of vendor produced training since it’s usually the best available resource and comes from the source.  Cloudbees has something called [Cloudbees University](https://standard.cbu.cloudbees.com/) that has a lot of great free resources and for ***ONLY $300*** offers their training course which is 2-days worth of content in a self-paced format and it even comes with a lab VM ready to rock and roll!  Considering a lot of other vendor training options are more expensive, this is probably the best $300 you can spend on technical training.

- **YouTube** – This is kind of an obvious source for some training but it’s sometimes more miss than hit.  I found a great resource that goes over most of the key points of the CJE and CCJE exams.  It’s done by a channel called [DevOps Library](https://www.youtube.com/channel/UCOnioSzUZS-ZqsRnf38V2nA/videos) and they have [a playlist with some wonderful content](https://www.youtube.com/playlist?list=PL6TwUbrFsOuN-db811WkXF1hwGTexiiOH), it’s a little dated but it’s largely still applicable to not only Jenkins but also the exam.

- **Other blogs** – Some of these were a little older (hell, one is about the exam *BETA*) but with everything else gave a little bit more color to the experience and some other tips to help with studying for the exam...
  - A bit older but the experience told and the study resources are gold: https://www.selikoff.net/2016/02/27/jeannes-experiences-with-the-jenkins-certification-beta-exam/
  - Seems a bit more updated and gives some more color to the enterprise portion... https://github.com/smartrus/certified-jenkins-engineer-study-guide/blob/master/certified-jenkins-engineer.md
  - CJE 2017 content but still good – https://muralibala.gitbooks.io/cloudbees-certified-jenkins-engineer-2017/content/

## Before the SCANTRON

Ok, it’s not really on a SCANTRON but I couldn’t help but show my age.

There were a few other things I’d suggest to potential exam goers.

- **Install the projects and the products** – Install Jenkins, a few times, and a couple different ways if you can.  Then install Cloudbees Core, you can request a trial license from within the installer.  Get your hands dirty.
- **Learn the architecture** – Learn how masters, agents, the file system, and all the other components work together.  This includes learning some of the more popular plugins and what they deliver.  Basic *nix admin skills are good to have as well.
- **Create jobs/pipelines and run builds** – There’s some confusing terminology and sometimes a word can mean multiple things depending on what part of Jenkins you’re using.  Best way to get over that is to actually start building jobs and pipelines.  It also brings that actual “AHA!” or “AWESOME!” moment when you see everything just magically working together to form a CI/CD workflow.
- **Buy the $300 training from Cloudbees University** – Why?  It’s cheap, has a great ROI, and it comes with a lab VM to run in Virtualbox (via Vagrant) that has everything you need pretty much set-up and ready to rock and roll, IN ADDITION TO the best CJE/CCJE training you can get.  This means no need to waste time setting up Docker, LDAP, Jenkins masters/agents, reverse proxy, etc and more time for learning.
- **Review the official Jenkins Certification site** – [This page](https://www.cloudbees.com/jenkins/jenkins-certification) has a lot of great information that can help you along the way.  You’ll find the Study Guides (important!), some FAQs such as passing scores, longevity (forever), along with a bunch of other great detail regarding the exam offerings.

## Do the damn thing

That’s all I got really, and pretty much all I can say without getting in trouble!

{{< figure src="/images/posts/legacyUnsorted/Dqx7YhSV4AAy7g3-1024x768.jpg" class="col-sm-12 text-center" >}}

This is the combination of resources and study material I used to pass the CCJE.  I can’t really say how you should go about studying, everyone learns best differently but hopefully there’s something in here that can help you.  I learn best with multiple ways aggregated together.  Over two days I wrote about 30 pages of notes in addition to watching those videos a few times, flipping through the training slides back and forth, and reading the documentation and training material...oh and doing the labs.  So as you can tell, it takes a lot for me to learn something...

After the study session, I had a great night’s sleep, hit the gym in the morning, dined on a salad and some local [to Denver] charcuterie, all washed down with a few local [to Denver] brews.  Then I walked into the testing center, this was hosted in a Community College, which was super weird to walk through in my Halloween costume.  About 40 minutes later, I had passed the exam!

Will this all work for you?  Probably not.

Will some of it?  Yes, and that’s all that matters.

Is this a piss-poor "how-to"? More than likely.

## Good luck, and get to integrating and deploying, LIKE A BOSS!