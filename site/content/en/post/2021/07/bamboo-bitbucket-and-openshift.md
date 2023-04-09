---
title: "Getting started with Atlassian BitBucket, Bamboo, and Red Hat OpenShift"
date: 2021-07-20T07:42:47-05:00
draft: false
toc: true
publiclisting: true
aliases:
    - /blog/bamboo-bitbucket-and-openshift/
hero: /images/posts/heroes/resized/resized-bamboo-openshift.png
tags:
  - homelab
  - atlassian
  - bamboo
  - bitbucket
  - red hat
  - openshift
  - containers
  - docker
  - podman
  - kubernetes
  - cicd
  - ci/cd
  - automation
  - devops
  - git
authors:
  - Ken Moini
---

> ***Forgive me father for I have sinned...I installed Bitbucket...***

Ok, there's nothing really wrong with Atlassian's stack...aside from it being super confusing and made by aliens from Uranus.

Somewhere out there, believe it or not, there are still people using BitBucket, Jira, and Bamboo.  Poor depraved souls, I know, I know - let us take a moment of silence to reflect upon our good fortunes in this bountiful land where we can sow our code with modern machinations.

_silence breaks as quickly as it began_

> "Alrightalrightalrightfuckallthatshit, let me show ya the pantry"

Only 3 people reading this will get that reference and that's OK.

*_Anywho..._*

In case you are also an unfortunate soul in need of integrating your horse and buggy Atlassian stack with the spaceship that is OpenShift, this post should show you how to get it all up and running.

## Installing Bamboo

This is actually decently straight-forward to get installed, slightly confusing to get the trial license for - especially since their site tries to push everyone to their weird cloud service.

First, let's start with a RHEL 8.x system - once you've got yourself booted into that system, let's run the following script to get it rolling:

{{< code lang="bash" line-numbers="true" >}}
#!/bin/bash

export SYSTEM_HOSTNAME="bamboo"
export BAMBOO_VERSION="7.2.4"

# Set SELinux to Permissive mode
setenforce 0

# Set the hostname
hostnamectl set-hostname $SYSTEM_HOSTNAME

# Update the system
dnf update -y

# Install Java
dnf install java-1.8.0-openjdk -y

# Download Atlassian Bamboo
cd /opt
wget https://www.atlassian.com/software/bamboo/downloads/binary/atlassian-bamboo-${BAMBOO_VERSION}.tar.gz
tar zxf atlassian-bamboo-${BAMBOO_VERSION}.tar.gz
cd atlassian-bamboo-${BAMBOO_VERSION}

# Create and set Bamboo Home
mkdir -p /opt/bamboo_home
sed -i 's/.*bamboo.home.*/bamboo.home=/opt/bamboo_home/' /opt/atlassian-bamboo-${BAMBOO_VERSION}/atlassian-bamboo/WEB-INF/classes/bamboo-init.properties

# Allow default port on Firewall
firewall-cmd --add-port=8085/tcp

# Download kubectl and oc
cd /opt
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz
tar zxf openshift-client-linux.tar.gz
mv oc /usr/local/bin/oc
mv kubectl /usr/local/bin/kubectl

# Start the Bamboo Server
/opt/atlassian-bamboo-${BAMBOO_VERSION}/bin/start-bamboo.sh
{{< /code >}}

Give it a couple seconds and it should start up - then point your browser to `http://$SYSTEM_HOSTNAME:8085/` and proceed from there.

### Getting a Bamboo Trial License

So this next part was slightly confusing - in order to activate the Bamboo server with a Evaluation/Trial license you had to click the smallest link on the page to proceed to the form that you have to log into and fill out...

![Bamboo Licensing Screen](/images/posts/legacyUnsorted/bambooLicensingScreen.png)

You see that small "Atlassian" link hidden in that line about "Please enter your Bamboo license key above - either commercial or evaluation. Contact Atlassian if you require a license key."

Yeah, you're gonna want to click on that to get an evaluation license.  Log in with some sorta SSO and then it'll send ya to a form to generate an eval.

From there, continue with the setup however you'd like from there.

## Installing BitBucket

Before Bamboo can really be usable, you need an SCM - because we're masochists, we'll be deploying BitBucket from the same Atlassian stack.

Here's how to Bash things together:

{{< code lang="bash" line-numbers="true" >}}
#!/bin/bash

export SYSTEM_HOSTNAME="bitbucket"
export BITBUCKET_VERSION="7.14.1"

# Set SELinux to Permissive mode
setenforce 0

# Set the hostname
hostnamectl set-hostname $SYSTEM_HOSTNAME

# Allow default port on Firewall
firewall-cmd --add-port=7990/tcp
firewall-cmd --add-port=7992/tcp
firewall-cmd --add-port=7993/tcp

# Update the system
dnf update -y

# Install needed packages
dnf install git -y

# Download the BitBucket installer
cd /opt
wget https://www.atlassian.com/software/stash/downloads/binary/atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin
chmod +x atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin

# Run the installer with the default values (-q)
atlassian-bitbucket-${BITBUCKET_VERSION}-x64.bin -q
{{< /code >}}

Next you can open your browser to http://$SYSTEM_HOSTNAME:7990 - the trial license for BitBucket is a little more straightforward from the installation, however when it prompts you to install on the target server it will try to redirect you back to the set up and if you don't have SSL set up on it already then it'll fail the redirect...just copy and paste the license into the Setup form.

### Import Code into BitBucket

Next we'll need some source code to operate on - in this case we'll use a simple NodeJS application.

1. Create a new Project in BitBucket - Projects are like Namespaces, they can house multiple Repositories
2. Import/Create+Upload code to the Project - in this case we're using the generic Git source import function and this repo: https://github.com/kenmoini/teleprompter
3. Get confused about all the damned icons without labels
4. ?????
5. PROFIT!!!!!1

Now that we have our code, we need to build out some automation for it in Bamboo right?

## Configure Bamboo

Now that we have BitBucket with a code repo sitting pretty, we can connect it to Bamboo and then proceed to some other configuration such as a Kubernetes remote agent.

For the scope of this document, we're not going to touch on exposing BitBucket/Bamboo behind a reverse proxy and setting up SSL or LDAP/SSO.  Also take note that both servers are running as root, which is likely not a good thing...

### Connect BitBucket to Bamboo

As the initial admin (or an admin, I guess), navigate to the Bamboo Administration screen (click the cog icon to the left of your avatar in the right-side of the top navbar...whew...)

From the menu in the left, navigate to "Manage Apps > Application Links" - enter the url of your BitBucket `server:port` and click the "Create new link" button - it'll ask you to verify the link, redirect you to the BitBucket server to confirm the link, and then back to the Bamboo server.

### Disable Remote Agent Authentication

Most of these Agent deployment methods require *Remote Agent Authentication* to be disabled - do so from the Bamboo Administration screen, under "Agents", click the "Disable Remote Agent Authentication" link in the "Remote Agents" section.

### Disable Security Token Verification

Most of these Agent deployment methods also require *Security Token Verification* to be disabled - do so from the Bamboo Administration screen, under "Agents", click the "Disable Security Token Verification" link in the "Remote Agents" section.

Note that you can technically use Security Tokens with the Container Deployment-based Remote Agent method, but it requires setting a `BAMBOO_SECURITY_TOKEN` environment variable to the Deployment.

## Conecting Bamboo to Kubernetes/OpenShift

There are 3 approaches to this (at the time of this writing, and according to me and my research):

1. Stuff a container with the agent, deploy static remote agents on K8s/OCP
2. Use the Per Build Container plugin
3. Use the "Kubernetes (Agents) for Bamboo" plugin by Windtunnel Technologies

I've worked on option #1 - option #2 didn't work for me, couldn't even get the plugins and modules enabled.  Option #3 worked and was pretty easy but it also had some quirks.

> Either way you go, you'll likely need to disable some of the SecurityContextConstraints and enable some privileged operations on your K8s/OCP cluster!

### Option #1 - Container Deployment-based Remote Agent

The idea with this is that you have a container that has the Bamboo Remote Agent JAR file in it, add some configuration, a little Bash to automate the start up and passing of variables and you're good to go...more or less.

In case you'd like to pick up a base container image that works on OpenShift, you can use this and build upon it pretty easily: https://github.com/kenmoini/atlassian-bamboo-k8s-image

The container is pre-built and available on Quay and built on a RHEL 8 UBI because Docker Hub wants to be a punk little bitch with their pull-limits: https://quay.io/repository/kenmoini/atlassian-bamboo-k8s-image

Once you have the (edited) deployment objects applied to the cluster (located in that GitHub repo in the `openshift/` folder), you should be able to see the Remote Agent being listed in your "Bamboo Administration > Agents" page.

### Option #2 - Per Build Container Plugin

This option didn't really work for me - not entirely stable from what I can gather and their release cycle isn't kept up with properly from what I can tell.  Here's what I tried doing:

1. Navigate here: https://bitbucket.org/atlassian/per-build-container/downloads/ - download the following plugins:
  - isolated-docker-spi
  - bamboo-isolated-docker-plugin
  - bamboo-kubernetes-backend-plugin
  - bamboo-kubernetes-metrics
2. Navigate to the Bamboo Administration screen, in the left-hand pane find "Manage Apps > Manage Apps"
3. Find the "Upload App" button and upload the JAR files you just downloaded - install in the order listed above.

The issue I had was that the plugins failed to enable - so I moved onto the other plug in before landing on the Container Deployment-Based option.

### Option #3 - Kubernetes Agent Plugin by Windtunnel

This was actually a pretty straightforward option, however it's also the most expensive one - there is a trial you can get for the plugin to test.

I suggest reading this to get the plugin up and running with your cluster: https://github.com/kenmoini/atlassian-bamboo-k8s-image#configure-windtunnel-technologies-plugin

## Creating a Build Plan And Jobs and Tasks and...stuff

Now that everything is nice and connected, you should be able to create a Build Plan in Bamboo.  It's all GUI-driven so I can't just give you some YAML to apply like modern technologies...

1. In Bamboo's top bar, click the "Create" dropdown and select "Plan"
  - Select or create a new Project
  - Give the Plan a Name
  - Link the repo we created in BitBucket earlier - it may ask you for additional linking verification because what we did earlier evidently wasn't enough...
  - Click "Configure Plan"
2. For "Isolate Build" select the "Agent environment" option
3. Next, we can add some Tasks - the first Task is automatically added and it will check out the repository link to this Plan and change directory into its root.
4. Add a second Task, this can be whatever simple, like a "Command" task
  - Give the new Command Task as name, like "Bash Listing"
  - Select the "bash" Executable - if using my container base then it should have some Executables defined already.
  - In "Arguement", add in the following: `-c "echo 'Hello from inside a container!'; ls -al"`
  - Click "Save"
5. Click "Create"

Note that this won't actually build our application yet, it just does a simple echo and listing of the directory.

The Build should kick off, and if everything is lined up properly it should be run on that containerized agent running on your K8s/OCP cluster!