---
title: Scalable GitOps with ArgoCD Agent
date: 2026-09-24T04:20:47-05:00
draft: true
publiclisting: true
toc: false
hero: /images/posts/heroes/argocd-agent.png
photo_credit:
  title: Lots of squid in a coral reef
  source: Gemini
tags:
  - argocd
  - gitops
  - agent
  - principal
  - managed
  - autonomous
  - hybrid
  - cloud
  - containers
  - kubernetes
  - openshift
authors:
  - Ken Moini
---

> A fleet full of squids

KubeCon last year had a lot of exhibits, talks, and vendors addressing GitOps - I was honestly surprised to see so much motion around Flux, thought they died out.  But folks like Akuity were there with a promise: to make ArgoCD scalable.

In one of [my previous articles](https://kenmoini.com/post/2025/12/sensible-multicluster-gitops/), I mentioned some tactics to make ArgoCD scalable in a multi-cluster environment - however since then the ArgoCD community has done a lot of work to address some of the issues folks would face when running dozens if not hundreds of ArgoCD instances across their fleet, in addition to just some really excellent new capabilities:

- [ArgoCD Rollouts](https://github.com/argoproj/argo-rollouts) use is becoming more common as it has matured
- [GitOps Promoter](https://github.com/argoproj-labs/gitops-promoter) was introduced as TP in OpenShift GitOps 1.22
- Image Updater while still under development is stable enought to have been [GA'd in OpenShift GitOps](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/1.21/html/argo_cd_instance/using-argo-cd-image-updater)
- [Manifest/Source Hydrator](https://argo-cd.readthedocs.io/en/latest/user-guide/source-hydrator/) is available for beta use
- Last but not least - [ArgoCD Agent](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/1.22/html/argo_cd_agent_architecture/argocd-agent-architecture) has become usable for humans

And ArgoCD Agent is what we're talking about today

## Agents?  In my Argo?

**Aside:** *Honestly I hate the name "Agent" and the use of "Principal" but that sorta stuff is above my pay grade - I just wish some of the mega-nerds coming up with these things would say stuff in a sentence, aloud, as a test to see if it makes sense...*

Anywho - typically you have two main architectures for ArgoCD, Centralized and Distributed.

In a Centralized architecture, you have a central ArgoCD that pushes out to multiple clusters.

{{< imgSet cols="1" name="argo-centralized" >}}
{{< imgItem src="/images/posts/2026/09/argocd-centralized.jpg" alt="One Argo to rule them all" >}}
{{< /imgSet >}}

In a Distributed architecture, you have an ArgoCD instance installed on every cluster that simply manages itself.

{{< imgSet cols="1" name="argo-distributed" >}}
{{< imgItem src="/images/posts/2026/09/argocd-distributed.jpg" alt="Many Argos" >}}
{{< /imgSet >}}

I've historically done a bit of both - a Hub cluster with a central Argo managing ApplicationSets across labeled clusters synced in from Advanced Cluster Management, primarily for cluster-level things ACM Policies can't do (think Helm stuff).  Then each managed cluster gets its own Argo to sync down its own things like Applications...for applications.

For multi-tenant instances, each cluster tenant would get their own Argo because that's often easier than dealing with the RBAC and reduces the effects of noisy neighbors borking the Argo repo/server Pod.

The problem with a distributed architecture, or even my hybrid implementation, is that there's not really a centralized management or observability endpoint.  ArgoCD Agent mode fixes that.

