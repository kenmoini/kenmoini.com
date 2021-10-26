---
title: "Upgrading to Ansible 2.10"
date: 2020-10-2T21:02:47-05:00
draft: true
toc: false
tags: 
  - Ansible
  - Red Hat
  - automation
authors:
  - Ken Moini
---

```bash
pip3 uninstall ansible
```

```bash
pip3 install ansible-base
```

```bash
pip3 install argcomplete

register-python-argcomplete ansible | sudo tee /etc/bash_completion.d/python-ansible
register-python-argcomplete ansible-config | sudo tee /etc/bash_completion.d/python-ansible-config
register-python-argcomplete ansible-console | sudo tee /etc/bash_completion.d/python-ansible-console
register-python-argcomplete ansible-doc | sudo tee /etc/bash_completion.d/python-ansible-doc
register-python-argcomplete ansible-galaxy | sudo tee /etc/bash_completion.d/python-ansible-galaxy
register-python-argcomplete ansible-inventory | sudo tee /etc/bash_completion.d/python-ansible-inventory
register-python-argcomplete ansible-playbook | sudo tee /etc/bash_completion.d/python-ansible-playbook
register-python-argcomplete ansible-pull | sudo tee /etc/bash_completion.d/python-ansible-pull
register-python-argcomplete ansible-vault | sudo tee /etc/bash_completion.d/python-ansible-vault

sudo chmod +x /etc/bash_completion.d/python-ansible*

source /etc/bash_completion.d/python-ansible*
```

```bash
pip3 install ovirt-engine-sdk-python
pip3 install boto
pip3 install openstacksdk

ansible-galaxy collection install ovirt.ovirt
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install openstack.cloud
```