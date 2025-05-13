---
title: "Unreal Engine and Pixel Streaming"
date: 2021-04-13T22:02:47-05:00
draft: true
toc: true
tags:
  - rhel
  - rhel 8
  - red hat enterprise linux
  - red hat
  - nvidia
  - drivers
  - cuda
  - data center driver
  - gpus
  - epic games
  - unreal engine
  - podman
  - docker
  - containers
  - gitlab
  - ci/cd
  - devops
  - automation
  - pipelines
authors:
  - Ken Moini
---

> ***A mega compendium on how to get up and running with Unreal Engine Pixel Streaming on RHEL in containers...this is likely a work-in-progress***

Without the cookie-recipe intro, let's jump into things: I'm trying to get Pixel Streaming from Unreal Engine working in RHEL, and specifically in containers to use in a Kubernetes platform.

I'm not really innovating here, just adding some glue and patches - a lot of the hard work has already been done by the fine folk at Epic Games and TensorWorks.  You can read/watch this for a more detailed background into Pixel Streaming with UE on Linux: https://adamrehn.com/articles/pixel-streaming-in-linux-containers/

This is going to be a complete start-to-finish guide on how to access Unreal Engine source, build it, and run it - hopefully.

# Accessing Unreal Engine bits

## 1. Get an Epic Games account

If you don't already have an Epic Games account, you should sign up here: https://www.unrealengine.com/id/login

## 2. Download & Install the Unreal Engine/Epic Games Launcher

Now that you have an account, you can install the Epic Games Launcher: https://www.unrealengine.com/en-US/download

There's no real difference in the software that you get download between the two licenses - just pick one, unless you know, you're in some sorta serious industry and are gonna be making money from this thing and then you'll want to pay attention and pay Epic probably.

## 3. Connect your GitHub account to your Epic Games account

Log into the Epic Games site and connect your GitHub account to your Epic Games account: https://www.epicgames.com/account/connections

Follow that link, click on the ***Accounts*** tab, click ***Connect*** under GitHub.

Once you connect your GitHub account, you'll be sent an email with an invitation to join the Epic Games organization on GitHub - pretty cool!

This is where you can find the Unreal Engine source code, as well as forks of the Unreal Engine source, since it's all kept in private repos.

The forked repo we're interested in is this one: https://github.com/ImmortalEmperor/UnrealEngine/tree/4.25-pixelstreaming

Now, before you go cloning/fetching/forking that repo, we have to set up a GitLab instance that has a GPU attached to it in order to build Unreal Engine.  You could raw dog this and just work on a Linux node that has a GPU attached, clone down and just work on that node using a Bash script for automation or something, but something like a real Git server gives easier collaboration and the ability to work with a pipeline.

# Deploying a GitLab server with a GPU

Now, there are probably a couple ways you could go about using GitLab in this scenario. Assuming you may not have a bunch of physical servers with GPUs in them and to avoid complications we'll just use one big ol' Linux server with a GPU attached.  This will serve as our build server and game server.

## 1. Deploy a Linux Server

Wherever you are running this, deploy a Linux server - this is tested to work on RHEL 8.4.  The more cores the better because you'll be building a lot of C++ programs and the more cores, the faster it'll build.  Set a decent bit of RAM too, at least 32-64 GB.

## 2. Install GitLab

I won't go into the details of deploying GitLab, there are a few ways to deploy it and their instructions are solid: https://about.gitlab.com/install/

## 3. Unload Nouveau

Before actually installing the NVidia drivers, you have to unload Nouveau and prevent it from starting at boot.  You can follow my instructions to do so here: https://kenmoini.com/blog/disabling-nouveau-drivers-rhel-8/

## 4. Add Nvidia Repos, Install Drivers, Container Toolkit, and CUDA

Next you can install the repos needed to download the NVidia drivers and CUDA packages to build the Unreal Engine.

{{< code lang="bash" command-line="true" output="" >}}
# Add the NVidia Container Toolkit Repo
curl -s -L https://nvidia.github.io/nvidia-docker/rhel8.3/nvidia-docker.repo | sudo tee /etc/yum.repos.d/nvidia-docker.repo

# Add EPEL
sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Add the CUDA repo
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo

# Install Drivers, CUDA
sudo dnf clean all
sudo dnf -y module install nvidia-driver:latest-dkms
sudo dnf -y install cuda nvidia-container-toolkit
{{< /code >}}