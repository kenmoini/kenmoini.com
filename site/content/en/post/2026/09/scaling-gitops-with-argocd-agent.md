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
- 