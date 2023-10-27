---
title: Custom Credential Types in Ansible
date: 2023-10-26T04:20:47-05:00
draft: false
publiclisting: true
toc: false
hero: /images/posts/heroes/ansible-credential-types.png
photo_credit:
  title: Leah Kelley
  source: https://www.pexels.com/photo/person-holding-a-book-8050564/
tags:
  - open source
  - oss
  - ansible
  - aap
  - aap2
  - automation
  - tower
  - controller
  - secrets
  - credentials
  - nutanix
authors:
  - Ken Moini
---

> Wow, been a while, eh?

Yeah, I know, I've been *slacking*.  What can I say, life has been busy.

Anywho - I'm back at it like a crack addict, and for my first rock I'll be going over creating custom Credential Types in Ansible Automation Platform 2!  *Ooooh!  Ahhhh!  Spoopy.*

## Why custom Credential Types?

Well simply put, Ansible doesn't come with many credential types for integrating with various systems - you kind of have to make them.  It's not hard, just a bit of a pain in the ass to remember how to do it every time you need to.

In case you need to integrate with an external system such as in this instance - Nutanix Prism - you can make your own Credential Type, then use that to create a Credential to securely store authentication details in Ansible Tower/Controller.

Of course you could just store the credentials as vaulted variables, but that becomes a pain to manage with different Inventories - and it's kind of an anti-pattern when providing Automation-as-a-Service.

## Creating a Credential Type

So in my instance, I'm wanting to authenticate to various Nutanix clusters that may be distributed across different data centers.  First we need to make a Credential Type that defines the structure and metadata of our required authentication variables.

1. Log into your Ansible Tower/Controller instance and navigate to Administration > Credential Types.
2. Click that big blue **"Add"** button.
3. Give your new Credential Type a **Name** - in my case, it'll be `Nutanix`
4. Provide a **Description** if you'd like, such as `Authentication Credentials to connect to a Nutanix API`
5. Now we provide some **Input Configuration** - this is what a Credential will take as input, displayed as a form when creating Credentials of this type.  Mine look something like this:

```yaml=
---
fields:
  - id: nutanix_username
    type: string
    label: Nutanix Username
    help_text: Represented as an environmental variable `NUTANIX_USERNAME` and the variable 'nutanix_username' in a Playbook.
  - id: nutanix_password
    type: string
    label: Nutanix Password
    secret: true
    help_text: Represented as an environmental variable `NUTANIX_PASSWORD` and the variable 'nutanix_password' in a Playbook.
  - id: nutanix_host
    type: string
    label: Nutanix Endpoint
    help_text: Do not include the protocol and port, eg prism-central.example.com - represented as an environmental variable `NUTANIX_HOSTNAME` and the variable 'nutanix_host' in a Playbook.
  - id: nutanix_port
    type: string
    label: Nutanix Port
    help_text: Port number for the Endpoint - represented as an environmental variable `NUTANIX_PORT` and the variable 'nutanix_port' in a Playbook.
  - id: nutanix_validate_certs
    label: Validate SSL Certificates?
    type: boolean
    help_text: Represented as an environmental variable `VALIDATE_CERTS` and the variable 'validate_certs' in a Playbook.
required:
  - nutanix_username
  - nutanix_password
  - nutanix_port
  - nutanix_host
  - nutanix_validate_certs
```

6. Finally, we'll provide it the **Injector Configuration** - this is where you can map the inputs to files, environmental variables, or extra variables that are provided to your Playbooks.  In this case, we'll use some standard environmental variables AND extra variables that are common with the [Nutanix Ansible Collection](https://github.com/nutanix/nutanix.ansible):

```yaml=
---
env:
  NUTANIX_HOSTNAME: '{{ nutanix_host }}'
  NUTANIX_PORT: '{{ nutanix_port }}'
  NUTANIX_USERNAME: '{{ nutanix_username }}'
  NUTANIX_PASSWORD: '{{ nutanix_password }}'
  VALIDATE_CERTS: '{{ nutanix_validate_certs }}'
extra_vars:
  nutanix_host: '{{ nutanix_host }}'
  nutanix_port: '{{ nutanix_port }}'
  nutanix_username: '{{ nutanix_username }}'
  nutanix_password: '{{ nutanix_password }}'
  validate_certs: '{{ nutanix_validate_certs }}'
```

7. Click **Save** to create the new Credential Type

Well - that's it!  Now you can go about using your new Credential Type.

---

## Using the Credential Type

With the Credential Type created, you can create a Credential of that...type.  Yep.

1. Navigate to Resources > Credentials
2. Click the big blue "Add" button.
3. Give your Credential a **Name**, maybe even a **Description** and **Organization**
4. From the **Credential Type** drop down select the newly minted Credential Type - you'll see the Input Configuration defined specification displayed as a handy-dandy form!


> Happy Automating!
