---
title: Sensible Multi-Cluster GitOps
date: 2025-09-22T04:20:47-05:00
draft: false
publiclisting: true
toc: true
hero: /images/posts/heroes/multicluster-gitops.png
photo_credit:
  title: Irina Iriser
  source: Pexels
tags:
  - openshift
  - red hat
  - kubernetes
  - openshift
  - containers
  - cloud
  - automation
  - governance
  - gitops
  - acm
  - advanced cluster management
  - rhacm
  - policies
  - argo
  - argocd
  - multi-cluster
authors:
  - Ken Moini
---

> This is sure to piss off some opinionated people

When it comes to multi-cluster management, GitOps and automation are required, ArgoCD is top dog and I know I have some associates and friends who swear by it - they use ArgoCD for everything.  And some of them have to wait an hour for a sync to complete.  Some others end up adding a lot of other things in their Argo Applications to account for basic automation and logic controls.  This is even more confounded when some do things "Not the Good Way" and have one ArgoCD instance syncing out everything to everywhere.

ArgoCD is great - except for all the times when it's not.  I've found it to be really good at syncing things, but it's easily able to wreck itself and/or your cluster with some simple misconfiguration.  The other day two ArgoCD Applications were in a competing reconcile loop that caused other syncs to fail and provided so much pressure to the API that the cluster was impaired.  This gets even more brittle as you add additional logic functions, hooks, healthchecks, overrides, etc to your manifests.

So this post is to demonstrate how I've gone through the journey of implementing scalable GitOps in a variety of different environments and patterns for my customers - and which one works best.

---

## Segmented GitOps Controllers

First thing's first - when starting out with ArgoCD and GitOps, you'll likely just have one cluster-wide instance that syncs down everything.  This includes cluster configuration, core workloads, applications, etc - CI/CD processes update a Helm Chart version, new application rollouts are applied, and Argo just syncs things down.

After a while, you'll start to increase the resource limits/requests for the different components of ArgoCD.  Then probably add custom health checks to let the sync waves operate more efficiently.  At a certain point though, a single ArgoCD instance becomes a very large and slow single point of failure.

To avoid the scaling pain, of course the first logical step is to have different ArgoCD deployments:

- Initial Platform Operations instance that bootstraps the cluster, it's configuration, and other ArgoCD instances
- Domain oriented instances - this could be another ArgoCD instance for Platform Engineering (think Backstage things)
- Application oriented instances - this could start as just a single ArgoCD instance for application workloads, or grow to individual ArgoCD instances per Line of Business/App Team depending on the RACI/RBAC.

This is generally a good place to start with the GitOps optimizations, but there are some more patterns to explore...

---

## Scale Out - Push vs Pull

The next challenge is when you have multiple clusters under the management of a single set of ArgoCD deployments.  RBAC is difficult to manage and ArgoCD pushing out to multiple clusters becomes brittle - this is especially true for edge deployments.  What happens when the controller can't reconcile things in time due to a tempermental connection?  Sure, it'll retry a number of times, but this increases API pressure and you'll find more OOMKilled issues - giving it more RAM isn't always the right answer.

Push-based ArgoCD deployments may also not work due to network topology limitations - does the central ArgoCD instance have connectivity to all the managed clusters?  I've worked with customers where they can't get firewall rules opened for this centralized approach even if they have the routed networks in place - and it's typically not a matter of just making the port adjustments, it's more a concern of blast radius.

So for these scenarios you'll probably look at deploying an ArgoCD instance, or set of them building on the previous pattern, on individual clusters as they're bootstrapped.  This allows each cluster to pull in their own configuration and applications instead of being pushed from a central controller.

Now personally, I like the best of both worlds if possible - a centralized ArgoCD instance that is in charge of multi-cluster bootstrapping which essentially pushes out the configuration needed for each managed cluster to deploy their own ArgoCD stacks in order to pull in their own synced manifests.

This allows for centralized management that scales out more efficiently...but there are latent challenges with ArgoCD in itself that need to be addressed.

---

## Health Checks, Hooks, Jobs, Oh My!

No matter what people say about Kubernetes, you can't always just throw YAML at it and wait for that "eventual consistency" to normalize.  Doing so causes a lot of API pressure, which leads to unstable clusters.

There also is a problem with the secondary reconciliation of objects - think External Secrets.  An ArgoCD Application may sync down an ExternalSecrets CR, but the connection to the {Cluster}Issuer may not be in a happy state which causes the ExternalSecret to not produce the needed Secret for cluster configuration, applications, etc.  This can cause some minor chaos at least.

To solve that, you can add custom ArgoCD Health Checks, it's not too hard, just a bit of LUA.  As a matter of fact, you can find an example of the [ExternalSecret CR Health Check here in one of my public repos](https://github.com/kenmoini/ocp4-gitops-config/blob/main/openshift/openshift-gitops/instance/components/health-check-externalsecret/patch-externalsecret-health-check.yaml).

You'll find yourself creating a good number of ArgoCD Health Checks for objects that it isn't able to detect states for like it does for simple things like Deployments.  These are increasingly important as you leverage Sync Waves.

Another [key function of Sync Waves are Resource Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/).  Essentially you can run Kubernetes Jobs/Pods prior to syncing, on sync failures, or after successful syncs.  This lets you run scripts before/during/after sync stages - if you've spent years using Jenkins with a bunch of `shell` stages, you'll feel right at home.  Kind of clunky, but they're useful for things like database schema upgrades when updating versions of an application.

Some of the ArgoCD examples you'll find for Sync Waves and Resource Hooks will be around notifications - personally I'm not a fan of this pattern.  Assuming your GitOps functions are solid, successful syncs should be assumed - and any deviations should provide alerts via Prometheus/AlertManager/etc.  There's no reason to stuff a Slack notifier into each of your synced Applications if you can just centralize it with your observability instruments.

---

## Unified Multi-Cluster GitOps and Management

You can spend months dialing in your ArgoCD configuration and workflows, but you'll still find it somewhat limiting.  Sync Waves don't always wave the right way, dependency trees are difficult to manage, and conditionals are hardly a thing.  This is where you'll start to look at other tools and automation that break out of the GitOps mechanisms - or you can look into a governance policy framework.

Red Hat's [Advanced Cluster Management for Kubernetes](https://www.redhat.com/en/technologies/management/advanced-cluster-management) has many capabilities, but the most powerful one in my opinion is it's Policy controller.  It allows for better state management, dependency flows, conditionals, event stream signalling, and more. 

It's based on the [Open Cluster Management](https://open-cluster-management.io) project stack so you can try it out even without Red Hat OpenShift if you'd like - it's used and part of many other cloud management stacks such as Spectro, Alibaba, etc.

Using ACM, ArgoCD, and a dynamic secret provisioner like External Secrets + Vault, you can build a scalable GitOps pattern that easily segements concerns and personas.  There's even a [Validated Pattern for Multi-Cloud GitOps](https://validatedpatterns.io/patterns/multicloud-gitops/) you can check out.

The Validated Pattern is a good place to start, but it's still very ArgoCD-centric.  Personally I like using ArgoCD as an applied Unix philosophy of "one tool, one job" sort of thing which means that ArgoCD by and large is left as a simple syncing tool.  The advanced workflows otherwise are handled by ACM Governance Policies, and this pattern is something I've helped customers deploy successfully across private clouds, public clouds, and at the Edge.

![Multi Cluster GitOps Architecture](static/images/posts/2025/12/mcm-arch.png)

The architecture can be summed up as such:

- **Hub and Spoke** - Central Management cluster with N number of managed spoke clusters.  Segmented Hub clusters can be done geographically, per deployment level (eg Dev/Test, QA/Pre-prod, Prod), or per tenant structure.
- **Simple Bootstrapping** - The Hub is bootstrapped with a single script that provides it everything needed for Secrets Management, self-configuration, and managed cluster distribution.
- **Hybrid Push/Pull ArgoCD** - The Hub cluster syncs to itself, then provides each managed cluster its own ArgoCD instances.
- **Policy-first** - Operators and platform workloads are handled with ACM Policies whenever possible which allows for easy conditionals, dependency flows, and state management on a per-Kubernetes version basis making upgrades and matrixing easy.

A few examples of how this helps:

- External Secrets state can be determined to prevent cluster misconfiguration if there's an issue with the backing secret store.
- Workload Ensembles can deploy stacks for GPU enablement, Developer Services, Enhanced Observability, and more with a single label on a cluster - without needing a slew of ArgoCD Applications set up in convoluted paths in your repo.
- Policy violations raise Alerts that can then be acted upon by Event Driven Automation which reduces long-tail or recurring automation jobs.
- Templating of cluster composition into deployed manifests is easily done for even the most complex constructors.
- Validated that controllers are deployed and in a ready state before applying their managed CRDs.
- Clusters under ACM management are automatically synced into ArgoCD Cluster stores, which means ArgoCD ApplicationSets can matrix out without extra maintenance.

Setting things up the first time is some what tedious like any other GitOps practice, but once everything is in place it works like magic.

My favorite part is when my customers and partners go "Wow that's so much easier now!" as they onboard managed clusters and see things just kind of click into place automatically - and quickly.

If you'd like to see more examples of how this all works, you can check out this public repo as a good guide and starting point: https://github.com/kenmoini/lab-ocp

For any questions or guidance, feel free to drop a comment or reach out to me directly - would be happy to help tame your GitOps practices.
