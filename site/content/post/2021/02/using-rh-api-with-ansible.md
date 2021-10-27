---
title: "Using the Red Hat API with Ansible - 4 / 100 DoC"
date: 2021-02-15T21:02:47-05:00
draft: false
toc: false
aliases:
    - /blog/using-rh-api-with-ansible/
    - /blog/using_rh_api_with_ansible/
hero: /images/posts/heroes/resized/resized-rh-api-ansible.png
tags:
  - 100 days of code
  - 100doc
  - ansible
  - tower
  - galaxy
  - red hat
  - api
  - subscription
  - workshops
authors:
  - Ken Moini
---

> ***I think I'll need to take a vacation here soon and just pump out a bunch of articles on the things I've been up to...***

So recently I've been building out a few updated workshop deployers to provision environments in the IBM Cloud - it's about as fun as that all sounds.

Anywho, one of the workshop environments is an Ansible Automation environment, with Ansible Tower pre-installed and everything so participants can jump in and get their hands dirty with some clean automation!

Evidently, Ansible Tower 3.8 has new ways to license the server, and the preferred manner is to do so via a Red Hat Subscription Manifest, like the ones used with Red Hat Satellite.

So how do you store your automation in a public GitHub repo and still securely pass around the subscription manifest zip file?


{{< center >}}![I may have a problem...](/images/posts/legacyUnsorted/17aSDTa5W_p_dBQwCre5-4A.png){{</ center >}}

## New-ish Red Hat APIs

So Red Hat has some APIs that are available that let you interact with your Red Hat account and the Red Hat Subscription Management platform - you can read more about it here: https://access.redhat.com/articles/3626371

Easily enough, you log into your [Red Hat Customer Portal](https://access.redhat.com/management/api) and generate an offline token - this is used against the RH OAuth broker to get a short-lived token that can be used with the RH APIs.

The [Swagger docs](https://access.redhat.com/management/api/rhsm) are great for testing without even any programming - there are even some examples on how to use it with `curl` - but what about Ansible?

## APIs a-la Ansible

So my challenge is to download a Subscription Manifest to the Ansible Tower nodes, and then subscribe the Tower server.  Here's how I did just that:

1. Generate an RHSM API Token
2. Create a Subscription Allocation with Ansible Automation Platform subscriptions attached to it - take note of the Subscription Allocation UUID
3. Use the following Playbook:

```yaml
---
- name: Obtain Red Hat Subscription Manifest package for Ansible Tower server
    hosts: localhost
    gather_facts: true
    vars:
      rhsm_api_token: yourOfflineToken
      rhsm_tower_allocation_uuid: theUUIDofTheSubscriptionAllocation
    
    task:
      - name: Log into RH SSO API
        uri:
          url: https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
          body_format: form-urlencoded
          method: POST
          body:
            grant_type: refresh_token
            client_id: rhsm-api
            refresh_token: "{{ rhsm_api_token }}"
        register: rh_sso_reg
      
      - name: Trigger Manifest Export
        uri:
          url: "https://api.access.redhat.com/management/v1/allocations/{{ rhsm_tower_allocation_uuid }}/export"
          status_code: 200
          headers:
            Authorization: "Bearer {{ rh_sso_reg.json.access_token }}"
        register: trigger_manifest_export_reg
      
      - name: Check status of Manifest ExportJob
        uri:
          url: "{{ trigger_manifest_export_reg.json.body.href }}"
          status_code: 200
          headers:
            Authorization: "Bearer {{ rh_sso_reg.json.access_token }}"
        register: check_manifest_export_reg
        until: check_manifest_export_reg.status == 200
        retries: 10
        delay: 10
        ignore_errors: true
      
      - name: Download Manifest
        get_url:
          url: "{{ check_manifest_export_reg.json.body.href }}"
          dest: "{{ generation_directory }}/tower_sub_manifest.zip"
          headers:
            Authorization: "Bearer {{ rh_sso_reg.json.access_token }}"

- name: Tranfer Subscription Manifest to Tower Servers and subscribe
    hosts: tower_servers
    vars:
      tower_username: admin
      tower_password: someStr0ngP455
      
    tasks:
      - name: Copy manifest over to Tower nodes
        copy:
          src: "{{ generation_directory }}/tower_sub_manifest.zip"
          dest: /opt/tower_sub_manifest.zip
      
      - name: Configure Tower license
        ansible.tower.tower_license:
          manifest: /opt/tower_sub_manifest.zip
          eula_accepted: True
          tower_username: "{{ tower_username }}"
          tower_password: "{{ tower_password }}"
          validate_certs: false
```

You may need to install the `ansible.tower` collection from the Red Hat Automation Hub: https://cloud.redhat.com/ansible/automation-hub/repo/published/ansible/tower

With that, my workshop participants can now log into the Ansible Tower WebUI directly without having to deal with the licensing process!  Now to hope I won't have to automate some change in this process in the next minor version...