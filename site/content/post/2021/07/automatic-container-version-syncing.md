---
title: "Automating Container Builds and Releases Synced with Upstream Project Versions"
date: 2021-07-20T07:42:47-05:00
draft: false
toc: false
listed: true
aliases:
    - /blog/automatic-container-version-syncing/
hero: /images/posts/heroes/resized/resized-automated-container-syncs.png
tags:
  - homelab
  - red hat
  - quay
  - registry
  - openshift
  - containers
  - docker
  - docker hub
  - podman
  - builds
  - polyglot systems
  - kubernetes
  - cicd
  - ci/cd
  - automation
  - devops
  - git
  - github
  - github actions
authors:
  - Ken Moini
---

> ***...Beautiful violence, bring me some silence, oh, maybe I'm just bored...***

I think I'm gonna start doing that, bring it back and all - anyone remember setting your AIM/MySpace/Xanga statuses to some small string of lyrics that left everyone wondering what this small emotional dipstick was telling them?!?!  Haha, good times.

Anywho, so today I'm going to show you how to use GitHub Actions to automate syncing a container image's version with an upstream project's version.

***tl;dr:*** I'm automatically syncing a container image's tagging/versioning to the version of Golang - https://github.com/PolyglotSystems/golang-ubi8/tree/main/.github/workflows

***Wait, what?***

## Down with Docker Hub

Docker Hub really is getting annoying - so everyone adopted them as the defacto and default container registry everything reaches out to first, and now with their pull limits many automation workflows are failing.  Pulling a base image from Docker Hub, in a Docker Hub build mind you, would fail - pulling images from a cluster on the net?  In a GitHub Action?  Don't count on it.

[Quay](https://quay.io) is where it's at - security scanning and no pull limits.  So all my builds are now pushing there, however if you need something like the Golang base image off Docker Hub, unless you track in additional secrets then you'll likely get a failed build since Quay recycles build nodes like anyone with a resource manager would.  So now I need a new Golang base image source.

## Red Hat and Golang

Red Hat provides a Golang builder image as a part of their Red Hat Registry - [it's great](https://catalog.redhat.com/software/containers/ubi8/go-toolset/5ce8713aac3db925c03774d1)!  *Until you realize it's still on Golang v1.15.* ***UGH!***

So I needed Golang 1.16, and instead of waiting for the next RHEL minor release to *hopefully* get Golang 1.16, I figured I'd just build my own image based on Red Hat's Universal Base Image with a nu nu Golang in it.

## *I already did this*

Haha, ***snorts***, so this has been a problem for a while now, and evidently I had already created a base image with Golang v1.16 - however then I looked and evidently Golang v1.17 was out!  Of course I want the *option* of using that if I want - or in case others do too so I had to build a container image and tag it to the new version.

The thought of doing that over and over again for future versions frightened me - I never wanted to do this again.  I just want to always get a secure Golang builder with whatever version of Golang I want. ***So of course I sat out to automate this***

# The Container Image

## 1. Cleaning up

I've recently been making an effort to not make such shitty and poorly enabled/maintained softwares and stuffs.  In doing so, the first thing I did was move this base image repository ownership over to my "professional" (lol) organization - and then make it a lot more battle-ready and public-facing.

## 2. ARG, matey!

First thing I did was supply the Containerfile *(fuck Dockerfile, all my homies hate Dockerfile)* with a few new ARGs - an ARG for GOLANG_VERSION, SYSTEM_OS and SYSTEM_ARCH to support different build configurations.

```yaml
FROM registry.access.redhat.com/ubi8/ubi:latest

ARG GOLANG_VERSION=1.16.2
ARG SYSTEM_ARCH=amd64
ARG SYSTEM_OS=linux
```

***Fun fact:***  ARG is the only thing that can be defined before a FROM and is often used to variate the container base image...I supplied all the ARGs at the top of the Containerfile and found out that after a FROM the previous layer's ARGs are no longer available - so to make this work I just shifted the ARGs to below the FROM declaration.

## 3. Standard Containerfile stuff

Nothing is too fancy about this container image, which is good - that means it should work in a number of environments and is easy to maintain with little to break.

We're updating the base image layer, [Red Hat's Universal Base Image](https://catalog.redhat.com/software/container-stacks/detail/5ec53f50ef29fd35586d9a56), with the latest packages, needed packages, and set some environmental properties.

```yaml
# Basic Updates
RUN dnf update -y \
  && dnf install -y wget curl gnupg make git \
  && dnf clean all \
  && rm -rf /var/cache/yum

RUN mkdir -p /opt/{app-root,app-src}/ \
 && mkdir -p /opt/app-root/{bin,go} \
 && mkdir -p /opt/app-root/go/{bin,src} \
 && chmod -R 777 /opt/app-*

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/app-root/bin:/opt/app-root/go/bin
ENV GOPATH=/opt/app-root/go
```

## 4. Installing Golang

This is pretty easy - download the file, extract, put it where it needs to go, check to see if it worked, clean up.

```yaml
RUN curl -sSLk https://golang.org/dl/go${GOLANG_VERSION}.${SYSTEM_OS}-${SYSTEM_ARCH}.tar.gz -o /tmp/golang.tar.gz \
 && tar -C /opt/app-root -xzf /tmp/golang.tar.gz \
 && go version

RUN rm -rf /var/log/*
```

And that's that!  Now onto the automation...

# GitHub Actions

Next we'll make a few GitHub Actions to automate the processes of:

1. Checking the latest Golang version & creating a tag matching that version in Git
2. Creating a new Release when there is a new tag created
3. Building and Pushing the container when new version is released (and on other events)

Before we jump into the Actions, let's set up Dependabot to keep an eye on the Actions we'll be using.

## Dependabot config

This is pretty easy - Dependabot is a service provided by GitHub that will annoy you with a bunch of emails about vulnerabilities in your repositories.  It's a good bot though, and will sometimes submit Pull Requests for the patches.  We want it to keep an eye on the GitHub Actions we use in the automation we're going to build because GitHub Actions are basically unchecked community TypeScript running in your build pipeline, totally safe, lol.

Make sure the `./.github/dependabot.yml` looks something like this:

```yaml
# See GitHub's docs for more information on this file:
# https://docs.github.com/en/free-pro-team@latest/github/administering-a-repository/configuration-options-for-dependency-updates
version: 2
updates:
  # Maintain dependencies for GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      # Check for updates to GitHub Actions every weekday
      interval: "daily"
```

## Required Secrets

Before setting up and/or pushing them to your GitHub repo, it's handy to not have your first build fail - this automation relies on a few Secrets:

- `GHUB_TOKEN` is a secret holding your account's Personal Access Token
- `REGISTRY_USERNAME` is the username for the container registry being pushed to
- `REGISTRY_TOKEN` is the password/token for the container registry being pushed to

## Sync Upstream Version to Local Tag

Our first GitHub Action will be created in a file called `./.github/workflows/sync-upstream-version-to-tag.yml`

It'll run on any push or tag, just in case - and it'll also run on the 1st and the 15th of every month.

We're just cURL'ing the latest version and creating a tag with that version number.

```yaml
name: Sync with Golang Version
on:
  push:
    paths-ignore:
      - 'README.md'
    branches:
      - '*'
    tags:        
      - '*'
  schedule:
    - cron: '0 0 1,15 * *'

jobs:

  sync-upstream:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Get the latest version of Golang
      id: golang_version
      run: |
        echo ::set-output name=GOLANG_VERSION::$(curl -sSL https://golang.org/VERSION?m=text | sed 's/go//g')

    - name: Bump version and push tag
      id: tag_version
      uses: mathieudutour/github-tag-action@v5.6
      with:
        github_token: ${{ secrets.GHUB_TOKEN }}
        custom_tag: ${{ steps.golang_version.outputs.GOLANG_VERSION }}
```

Now that we've automated Tag creation, we can automate Release automation based on any Version Tag we create - this allows us to push additional hotfix container patches on top of a Golang version x.y.z.AA just by pushing that Tag.

## Create Release

Our next Action will create a GitHub Release anytime a Tag matching `v*` is created/pushed - stuff this in a file called something like `./.github/workflows/create-release.yml`

```yaml
name: Create a new Release on Tag creation

on:
  push:
    tags:
    - 'v*'

jobs:

  create-release:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - uses: ncipollo/release-action@v1
      with:
        token: ${{ secrets.GHUB_TOKEN }}

```

That one is extremely simple, eh?  Now for the real meat and potatoes...

## Build & Push

This last GitHub Action will create the actual container image and push it to our Quay registry.

It won't operate when the README is updated though, 

```yaml
name: Build Golang UBI Container
on:
  push:
    paths-ignore:
      - 'README.md'
    branches:
      - main
      - 'releases/**'
    tags:        
      - v*
jobs:
  # Build the container
  build-container:
    name: Build Container
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:

    - name: Check out code
      uses: actions/checkout@v2.3.4

    - name: Git Build Info
      id: git_build_info
      run: |
        echo ::set-output name=SOURCE_NAME::${GITHUB_REF#refs/*/}
        echo ::set-output name=SOURCE_BRANCH::${GITHUB_REF#refs/heads/}
        echo ::set-output name=SOURCE_TAG::${GITHUB_REF#refs/tags/}

    - name: Get the latest version of Golang
      id: golang_version
      run: |
        echo ${{ steps.git_build_info.outputs.SOURCE_TAG }}
        echo ::set-output name=GOLANG_VERSION::$(curl -sSL https://golang.org/VERSION?m=text | sed 's/go//g')

    - name: Set up QEMU
      uses: docker/setup-qemu-action@v1

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v1

    - name: Docker meta
      id: meta
      uses: docker/metadata-action@v3
      with:
        # list of Docker images to use as base name for tags
        images: |
          quay.io/polyglotsystems/golang-ubi
        # generate Docker tags based on the following events/attributes
        tags: |
          type=ref,event=branch
          type=ref,event=tag
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha

    - name: Login to Quay
      uses: docker/login-action@v1 
      with:
        registry: quay.io
        username: "${{ secrets.REGISTRY_USERNAME }}"
        password: "${{ secrets.REGISTRY_TOKEN }}"

    - name: Build and push
      uses: docker/build-push-action@v2
      with:
        context: .
        push: true
        file: Containerfile
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        build-args: |
          GOLANG_VERSION=${{ steps.golang_version.outputs.GOLANG_VERSION }}
          SYSTEM_OS=linux
          SYSTEM_ARCH=amd64
```

Note that this will use the latest version of Golang for every build - if you want to sync to the Tag reference then swap the `GOLANG_VERSION` build-arg with `${{ steps.git_build_info.outputs.SOURCE_TAG }}`.  That may require additional logic in the Containerfile in order to compensate for the empty string when a tag isn't the trigger - or trigger the build based only of the versioned tags.

There's some additional modifications you could do, such as building for different architectures and operating systems, only building on version tags, and so on.  Either way, as long as the upstream software project you want to sync versions has a way to query for their latest version then you should be good to go with just a few swaps!

You could even extend this automation workflow to other container image layers - if you have a downstream project that consumes this container image, maybe you add additional builder packages like NPM to this Golang builder, and you want to sync when there is a new version of this container image, you would just query something like this: `curl -s https://api.github.com/repos/PolyglotSystems/golang-ubi8/releases/latest | grep "tag_name" | cut -d ':' -f 2,3 | tr -d \",`

> ***With a little Push, you should now have releases of the Golang base image automated to sync with the versions of Golang itself!***