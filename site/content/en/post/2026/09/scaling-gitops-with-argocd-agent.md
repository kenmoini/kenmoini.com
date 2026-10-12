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

The problem with a centralized architecture is that you have a single point of failure - and it's very difficult to scale.

The problem with a distributed architecture, or even my hybrid implementation, is that there's not really a centralized management or observability endpoint.  ArgoCD Agent mode fixes that.

ArgoCD Agent mode (?) gives you a centralized interface to manage and observe, and distributes components across the managed clusters for better resiliency.  The primary components that are offloaded to the managed clusters are the Application{Set} Controllers, Redis, and Repo Pods, though the Hub/Principal still runs its own set of those components.

The main components of Agent mode outside of those usual suspects is a workload run on the **central Hub cluster called the Principal**.  Then every managed cluster gets their own new Agent Pod.  A few things to note:

- Communication always goes from the Agents to the Principal so the central/hub cluster must be accessible from those managed Agent clusters.
- gRPC is used for a common interface, and everything is wrapped in mTLS - which means you'll need to get good with managing x509 certificates.
- Agent clusters are able to withstand network faults between the Principal and repo sources.
- Depending on what mode you use Agent mode, you have some overrides and autonomy on Agent clusters

Oh yeah - Agent Modes.  Currently there are two, Managed and Autonomous.  There are some considerable differences but the tl;dr comes to where the operative controls, Argo manifests, and RBAC live.

In Managed mode, the configuration state is applied on the Principal cluster, then the Agents report in and are provided their assets.

In Autonomous mode, the configuration is applied on each Agent cluster, and then they simply report their status and provide controls to the Principal - this has some implications on asset distribution and RBAC.

Some other implications rise when we look at "what happens when the Great American Fibre Seeking Backhoe takes out our WAN?"

| | Managed | Autonomous |
|---------|------------|------------|
| Agents continue reconciling local Applications? | Yes | Yes |
| Can Create/Edit/Delete Applications? | No | Yes |
| Can Create/Edit/Delete ApplicationSets? | No | Yes |
| Existing ApplicationSets continue processing generators? | No | Yes |

I personally prefer Autonomous mode by and large - I like being able to hit the "oops" button when Application syncs go off the reservation.

You now may be wondering - wait, what about during upgrades, longer Principal cluster outages, etc because we now have a Single Point of Failure with the centralized-ish-ness of the Principal.  Well, [HA and Replication are currently in beta](https://argocd-agent.readthedocs.io/latest/concepts/ha/) and should be expected sometime in 2027 *(allegedly)*.