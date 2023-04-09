---
title: "Life Hack: Watch and Restart Libvirt VMs - 9 / 100 DoC"
date: 2021-06-27T07:44:47-05:00
draft: false
toc: false
publiclisting: true
aliases:
    - /blog/life-hack-watch-and-restart-libvirt-vms/
hero: /images/posts/heroes/resized/resized-lifehack-restart-libvirt-vms.png
tags:
  - homelab
  - ocp
  - libvirt
  - kvm
  - qemu
  - virsh
  - bash
  - scripting
  - red hat
  - openshift
  - kubernetes
  - containers
authors:
  - Ken Moini
---

> ***No one should be surprised at my lack of writing lately...busy bee buzz buzz...***

Been doing some really dope things lately, one being orchestrating full IaaS and PaaS automation for deploying OpenShift to Libvirt.

OpenShift doesn't have a built-in or traditional method to deploy to Libvirt, unless you compile a developmental version of the `openshift-install` binary - let's not kid ourselves, who wants to do a silly thing like *compile* something?

So instead I've been using the bare metal installation method that's driven by the Red Hat Cloud's Assisted Installer service.  Even more recently, I've been using an offline and local deployment of the Assisted Installer service which has been fantastic to say the least.

There is however, as always, some slight weird hiccup...

## Libvirt Events

For some forsaken reason, Libvirt isn't respecting VM events such as `on_reboot` which is a problem - the OpenShift VMs need to restart when rebooted in order to finish the installation or else it will cause the installation to fail.  Evidently this is a bug that's been a problem for a while...

Normally I was just waiting 20 or so minutes to manually restart the VMs which was a minor pain in the ass for something that's SUPPOSED TO BE AUTOMATED!

Naturally, I wrote a little Bash ditty to handle the restarting of the VMs...

## Bash Hacks

So in my general deployment process (found here: https://github.com/kenmoini/ocp4-ai-svc-libvirt) I have the names of my OpenShift VMs generate based on the counts for each node type so 3 Control Plane nodes create a `${CLUSTER_NAME}-ocp-cp-${COUNT}` named VM and so on for the Application Nodes.

With that list of Libvirt VMs, or what are traditionally known as Libvirt Domains, I could loop through the names of the VMs and check to see if it has been shut down yet from the reboot, and if so start it back up again until all the OpenShift Nodes were back online - including the bootstrap VM!

{{< code lang="bash" line-numbers="true" >}}
#!/bin/bash

#set -x
#set -e

source ./cluster-vars.sh

# Make an array
VM_ARR=()

# Loop...
for ((n=1;n<=${CLUSTER_CONTROL_PLANE_COUNT};n++))
do
  VM_ARR+=("${CLUSTER_NAME}-ocp-cp-${n}")
done

# ...de loop
for ((n=1;n<=${CLUSTER_APP_NODE_COUNT};n++))
do
  VM_ARR+=("${CLUSTER_NAME}-ocp-app-${n}")
done

LOOP_ON="true"
VIRSH_WATCH_CMD="sudo virsh list --state-shutoff --name"

echo "========= Cluster VMs: ${VM_ARR[@]}"

while [ $LOOP_ON = "true" ]; do
  currentPoweredOffVMs=$($VIRSH_WATCH_CMD)

  # loop through VMs that are powered off
  while IFS="" read -r p || [ -n "$p" ]
  do
    if [[ " ${VM_ARR[@]} " =~ " ${p} " ]]; then
      # Powered off VM matches the original list of VMs, turn it on and remove from array
      echo "========= Starting VM: ${p} ..."
      sudo virsh start $p
      # Remove from original array
      TMP_ARR=()
      for val in "${VM_ARR[@]}"; do
        [[ $val != $p ]] && TMP_ARR+=($val)
      done
      VM_ARR=("${TMP_ARR[@]}")
      unset TMP_ARR
    fi
  done < <(printf '%s' "${currentPoweredOffVMs}")

  if [ '0' -eq "${#VM_ARR[@]}" ]; then
    LOOP_ON="false"
    echo "========= All Cluster VMs have been restarted!"
  else
    echo "========= Still waiting on ${#VM_ARR[@]} VMs: ${VM_ARR[@]}"
    sleep 10
  fi
done
{{< /code >}}

So long as the VM name formats and counts are accounted for in the loops, this script will watch the VMs via `virsh`, wait until they are shut down, and reboot the nodes manually so the rest of the OpenShift installation process can progress!

Just goes to show - come hell or high water, I will automate all the things...even if it is just with some simple Bash...