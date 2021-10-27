---
title: "How-to: Passing the Amazon Web Services Solution Architect Exam"
date: 2019-07-21T17:41:38-05:00
toc: false
publiclisting: true
aliases:
    - /blog/how-to-passing-the-amazon-web-services-solution-architect-exam/
hero: /images/posts/heroes/resized/resized-passing-aws-sap.png
tags: 
  - amazon
  - amazon web services
  - aws
  - certification
  - training
  - how to
  - exam
  - solution architect
  - cloud practitioner
authors:
  - Ken Moini
---

In my line of work it's easy to hit a few roadbumps and lose momentum.  Burn-out can set in quickly and Imposter Syndome is hard to defeat at times.  I've found a few tricks to manage these issues:

1. **Get decent sleep** - I used to drink Jolts and pull all-nighters like it was the cool thing to do in my youth.  Now that system doesn't quite work that well and it's far from sustainable.  You need at least 6 hours of sleep - some say 8 but I feel much more rested at 6.

2. **Stop eating like a garbage person** - I'm not gonna lie, I love me some fast-food hamburgers there's just something viceral about it, something that takes me back to my childhood with each bite of "food" that wouldn't decay out in the open for months...yikes.  On the other hand, I feel like a champ after having a primarily vegetable based diet.  I still get my big pastrami sandwich from time to time but it's not an all the time, every day thing now - as delicious as that sounds...

3. **Set limits on your time** - It's nice being Superman and delivering functions and story points on your app dev board, but after a while of pulling long hours, late nights, and weekends, it can have negative effects on your physical health and that of your social life.  It's ok to stop working at the end of the work day and spend your afternoon enjoying a hobby; pass out to a Netflix series before midnight.  There's no need to sacrifice your own well-being for that of a business or project.

4. **Have a hobby or side-gig** - If you're passionate about what you do then it's sometimes hard to stop thinking about work.  Take that passion and put it towards something that brings you joy and value.  Reverse engineer KonMarie to find what your version of "stamp collecting" is.  Personally, I enjoy photography and spend time with my video gear as much as I can - especially while riding those neato electric scooters around Downtown Nashville, or other cities that have them when I'm traveling around.

5. **Validate your skills** - If you're involved in technology it's sometimes overwhelming by how fast things can progress.  That's ok, most people are in the same boat surprisingly enough.  Find that thing where your curiosity and passion cross and study it.  If you can stay drawn into that topic then look for certifications and exams you can take to get recognized.

## Leveling Up

What I enjoy and find a lot of draw in is DevOps, Site Reliability Engineering, and Security.  Now you can't really do DevOps unless you have an understanding of the full-stack, which nowadays means the Hybrid Cloud, Everything as Code, Continuous Integration, Continuous Deployment, Containers, Kubernetes, and Microservices - just to name a few things.  Yikes.

For the last few years I've been in and around a lot of those various aspects.  I've deployed and operated OpenShift clusters in AWS via CloudFormation that were highly available and load balanced, had orchestrated pipelines in Jenkins taking all applications through Test, Stage, and Production deployment routines, and across static sites, binary applications, and dynamic services in Java, NodeJS, and PHP.  Even though I've done this I felt a little lethargic amongst my creation - you see, these platforms and services can at time abstract so much away from your control and knowledge that when you peel back the surface it can be intimidating to have all the gears gnashing in front of you.

So recently I set out to do a few things:

1. **Learn Kubernetes** - I've worked with OpenShift plenty and Docker a lot but I've never gotten to play in-depth with vanilla Kubernetes outside of my dinky Raspberry Pi cluster that costs more than it should for not being able to do much of anything.  OpenShift abstracts a few things in different ways than K8s traditionally would, and gives you a beautiful panel to work out of so you never have to really learn too much about the underlying architecture or schemes of Kubernetes.  Now I've done [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) and instead of 6 small servers with different sites I now have 2 sizable clusters running orchestrated containers that have tripled my personal cloud bills!  Yay HA K8s!

2. **Document and Open-Source** - One thing that bites me in the ass is when I spend time on accomplishing a task, have to do it again, and forgot/lost step 2-6 out of 28.  Trying to do better about documenting my work and then also open-sourcing whatever I can, such as Ansible Playbooks and Roles, Jenkins Agents and Pipeline examples, and whatever else that makes sense.  The collaboration and feedback from the community usually helps me learn new things as well as better whatever is in the repo.

3. **Get Certified** - I've already got a few certificates though, and I wanted to target something that compliments the others while also expanding my current knowledge of a platform I have use of.  First objectives were **Amazon Web Service's Cloud Practitioner** and **Solution Architect Associate** certifications.  Hell, I even scheduled them both in the same day to set the target and deadline for when I needed to learn and test by.

> Thankfully, I've successfully passed both and received my **AWS Cloud Practitioner** [TCL54GE1EFF11JCP] and **AWS Solution Architect Associate** [E1DQRTGCE2FE17CL] certificates!  You can toss the codes in and verify them [here](http://aws.amazon.com/verification).

## How I did it

So honestly, I've used AWS for the last few years and have a decent familiarity with their core offerings.  Most of this can be done in the AWS Free Tier, or for inexpensive costs if you spin them down while you're not using them.  Aside from my general familiarity I did my usual of taking a few days of time off, bolting down in front of some books, my notepad, and online training and just focused on learning what I needed to.

### AWS Cloud Practitioner Exam and Certification

This is a pretty easy exam in my opinion.  The AWS Cloud Practioner Certification means you know about the general concepts and theories behind the Public Cloud, the benefits AWS brings to organizations, and what the core AWS services are and their basic function.  This can be attained by pretty much anyone, technical or not, in a day or two of studying.

What's really cool about the AWS Cloud Practitioner Certification is that AWS gives you the official training for Free-Ninety-Free.  You can head over to the AWS Training site and get the AWS Cloud Practitioner Essentials training course just by enrolling: https://www.aws.training/learningobject/curriculum?id=27076

Honestly the free training is what got me pushing down this AWS Certification path, even if I knew it was kind of a softball certification.  Once I saw how easy (for me) the Cloud Practitioner was I decided to also go for the next level up, the AWS Certified Solution Architect - Associate.

### AWS Certified Solution Architect - Associate

Now we're entering something that provides a little more of an involved course. The AWS Solution Architect exams challenges you to expand your knowlege past the key and core services.  At this point, you're expected to know what EC2 is and have used them before - and Launch Configurations, Auto-Scaling Groups, Load Balancers, and so on.  The things that would be key services offered in a scalable, highly available cloud, so make sure you know the designation and scope of Global, Edge, Regional, and Availability Zones.

You'll need to take a deeper dive into a wider palette of services such as AWS' Storage services, be that S3, Storage Gateways, Glacier, and even Snowballs.  There's a pretty heavy focus on the Database services as well so you'll want to know the difference between a Relational Database and NoSQL document-based Databases, the different types and stipulations of the various AWS RDS configurations, use of Aurora, DynamoDB, Redshift, ElastiCache, and so on.

It's definately a good idea to learn up on some of the more modern service offerings as well such as Serverless Architectures with AWS Lambda, Containers with either ECS or EKS, and then the other managed services such as Elastic BeanStalk and Fargate.  There's a need to know different Development and Integration services as well - make sure you know the difference between SNS and SQS.  If that's not enough, you should have a firm understanding of IAM and the flow of Users, Groups, Policies, and Roles, general security implications in the cloud, and what the divide of responsibility is between the customer and AWS.  For instance, AWS takes care of the guards, physical security, and infrastructure maintenance, while you worry about the security of your VPCs and Servers.

It's helpful to have a basic understanding of networking concepts and how they apply on-premises and then how they change in AWS.  There are a number of services such as AWS VPN that you should understand the role of, as well as AWS DirectConnect.  Outside of that, it's also a good idea to at least have a high-level understanding of the rest of AWS Services - you don't need to use Kinesis, but you should know what it does in streaming of data.

## Protips

Here are a couple extra goodies and bits of insight that will help prepare you better if and when you decide to get AWS Certified:

1. **Thinking In and Out of the Box** - They're multiple choice question exams, but especially when you get into the Solution Architecture material it's a lot of conceptual design and integration that goes into being able to pass.  If you can balance private & public subnets in different regions and so on, then you should be good.  If you don't have familiarity with HA and Load Balancing concepts and implementations then you might want to study up on basic Linux and Internet technologies as well.

2. **Performance Enhancing Drugs** - For when you're all outta *Snake Juice*, drink an energy drink and maybe take some N/O<sub>2</sub> boosters - those rooms can have a lot of terminals and warm bodies and accumlating CO<sub>2</sub> does a lot of harm to a critical mind.

3. **Get the free AWS Cloud Practitioner Training** - Easy checkbox - then the exam is only $100. https://www.aws.training/learningobject/curriculum?id=27076

4. **Get additional training** - I'll be honest with ya, I got a [Linux Academy](https://linuxacademy.com/refer?d1ad422e2556327ca79bda42b13842d0) subscription and I think it really helped.  All the topics on the exams were covered by their material and it's pretty cheap all things considering.  On top of that, I'm now using it to learn the AWS Solution Architect - Profession certification, as well as use it to obtain a GCP Engineer and Certified Kubernetes Admin certificate.  I think a few months of this subscription will pay off in the long run.

5. **Don't do multiple in a day** - I mean you totally can and it's very possible, but if you pass an exam you get a 50% discount voucher for your next exam...just saying.  If you do take them in the same day, make sure to be nice and shoot the shit with the proctors - you should be nice in general.  I digress, I had one scheduled for the morning and one in the afternoon and after a little batting of the eyelashes, they let me take my afternoon exam right after I passed my first one which saved me hours of just sitting around waiting.

6. **Write things down when studying** - I even broke out the different colored pens.  The visual and wrote memorization really helped drill in some of the finer details such as rate limits and peculularities in service offerings.

7. **Don't forget the extra services** - Before studying for these certificates I had no idea of what AWS Config was, or AWS Snowball, and about half a dozen other services.  Make sure to look over ***all*** the services and be able to explain them at a high level if you're planning on taking the AWS Solution Architect exam.

I highly suggest taking a look at the AWS Certification options.  Like it or not, AWS is the 800lb Gorilla in the room when it comes to the Public Cloud offerings (for now).  Though, it's not always the most cost effective cloud offering, which is why I'm taking my K8s clusters elsewhere.  AWS is a great platform to learn Web-Scale archtecture fundamentals, even if you decide to focus further in other practices.
