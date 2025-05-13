# Manual Workshop Deployment

Often times you'll find RHPDS failing catastrophically right before a customer event - what do you do?

> We'll do it live!

0. [Prerequisites](#prerequisites)
1. [Get an AWS Account](#get-an-aws-account)
2. [Setup AWS Credentials locally](#setup-aws-credentials-locally)
3. [Deploy an OpenShift Cluster](#deploy-an-openshift-cluster)
4. [OpenShift Users](#openshift-users)
5. [Find the Workshop Source](#find-the-workshop-source)
6. [Creating a Bootstrap Playbook](#creating-a-bootstrap-playbook)
7. [Uninstalling the Workshop/Workload](#uninstalling-the-workshopworkload)
8. [Destroying the Cluster](#destroying-the-cluster)

## Prerequisites

This assumes the use of a Linux or Mac OS X terminal - you'll need a few things preinstalled:

- Git
- Ansible
- Tar+Gzip

The following steps focus on deploying OpenShift workshops and thus require little outside of an OpenShift cluster.

If you are deploying something like the Ansible workshops where there is more AWS infrastructure to provision then you'll likely need boto and some other pip3 modules installed that are detailed here: https://github.com/redhat-cop/agnosticd/blob/development/docs/Preparing_your_workstation.adoc

---

## Get an AWS Account

Since most workshops are made to deploy to AWS infrastructure, you'll need an AWS account of some sort - you can get one via RHPDS/RHOE.

---

## Setup AWS Credentials locally

This process is done anytime your AWS credentials change.

In your RHPDS/RHOE email you will receive some credentials to access AWS that should look like this:

{{< code lang="text" >}}

Here is some important information about your environment:


Your AWS credentials are:

AWS_ACCESS_KEY_ID: AKI...
AWS_SECRET_ACCESS_KEY: 2ny...
** Plase be very careful to not expose AWS credentials in GIT repos or anywhere else that could be public! **

Top level route53 domain: .sandbox502.opentlc.com
The default region is set to us-east-2

 Web Console Access: https://268094075838.signin.aws.amazon.com/console 
 Web Console Credentials: you@redhat.com-0583 / s0mePa2s
{{< /code >}}

What you're looking for is the `AWS_ACCESS_KEY_ID` and the `AWS_SECRET_ACCESS_KEY` - assuming you're using a Mac or Linux terminal do the following:

{{< code lang="bash" line-numbers="true" >}}
### NOTE!  The following commands will overwrite your ~/.aws/credentials file... backup with `cp ~/.aws/credentials ~/.aws/credentials.bak-$(date +%s)`

## Substitute your keys from the email...
mkdir -p ~/.aws/

cat > ~/.aws/credentials << EOF
; https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
[default]
aws_access_key_id     = AKI...
aws_secret_access_key = 2ny...
EOF
{{< /code >}}

---

## Deploy an OpenShift Cluster

More than likely you'll need to deploy OpenShift for these workshops - if so the easiest way to do so is via the [AWS IPI](https://console.redhat.com/openshift/install/aws/installer-provisioned).

> Note: Make sure to get the right version of OpenShift's openshift-install binary, some workshops don't deploy past 4.8 currently.

0. Create a working directory: `mkdir -p ~/tmp-ocp-dev && cd ~/tmp-ocp-dev`
1. Download the openshift-install binary: `wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.8/openshift-install-linux.tar.gz`
2. Download the oc & kubectl binaries: `wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.8/openshift-client-linux.tar.gz`
3. Extract: `tar zxvf openshift-install-linux.tar.gz && rm openshift-install-linux.tar.gz README.md`
4. Extract: `tar zxvf openshift-client-linux.tar.gz && rm openshift-client-linux.tar.gz README.md`
5. Set permissions: `chmod a+x openshift-install oc kubectl`
6. Create install-config.yaml: `./openshift-install create install-config --dir=ocp`

All together now...

{{< code lang="bash" line-numbers="true" >}}
## Set some vars
DEV_DIR="$HOME/tmp-ocp-dev"
OCP_VER="4.8"

## Set the working directory
mkdir -p $DEV_DIR
cd $DEV_DIR

## Download needed binaries
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-${OCP_VER}/openshift-install-linux.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-${OCP_VER}/openshift-client-linux.tar.gz

## Extract the openshift-install binary
tar zxvf openshift-install-linux.tar.gz
rm openshift-install-linux.tar.gz README.md

## Extract the kubectl and oc binaries
tar zxvf openshift-client-linux.tar.gz
rm openshift-client-linux.tar.gz README.md

## Set permissions
chmod a+x openshift-install oc kubectl

## Create the OpenShift install-config.yaml file
./openshift-install create install-config --dir=ocp
{{< /code >}}

### RHPDS Notes:

- You should choose `us-east-2` when possible
- Choose the **Base Domain** that has the 4-character GUID prefix
- Give a short **Cluster Name** for ease like `ocp`
- Sizing your cluster can be tricky - some workshops require more resources per user than others.

You can template a similar install-config.yaml file - there are example configurations for different sized nodes:

{{< code lang="yaml" line-numbers="true" >}}
apiVersion: v1
baseDomain: 0583.sandbox502.opentlc.com
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    aws:
      # https://aws.amazon.com/ec2/instance-types/m5/
      type: m5.8xlarge
  replicas: 6
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
metadata:
  creationTimestamp: null
  name: ocp
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: us-east-2
publish: External
pullSecret: '{"auths": ...'
sshKey: |
  ssh-rsa AAAAB3NzaC1yc2E...
{{< /code >}}

> Next, deploy the cluster - it should take about 30 minutes: `./openshift-install create cluster --dir=ocp`

Once the cluster provisioning is complete you should be given some kubeadmin credentials - make sure to log in as the kubeadmin user with the oc client...most of the Ansible tasks will use the authenticated context/user that is set by the `oc login` command.

Log into the Web Console and pull the login command from the user drop-down menu entry **Copy login command**.

---

## OpenShift Users

Most workshops have a scalable number of users in a `userN` or `studentN` format - some workshops need these users provisioned separately and the easiest way to do this is with an HTPasswd provider:

### Creating HTPasswd Manually

{{< code lang="bash" line-numbers="true" >}}
## Set some vars
DEV_DIR="$HOME/tmp-ocp-dev"

# Create an HTPasswd file with an admin user
htpasswd -c -B -b ${DEV_DIR}/ocp-users.htpasswd opentlc-mgr r3dh4t123!

# Add additional users
htpasswd -b ${DEV_DIR}/ocp-users.htpasswd user1 openshift
{{< /code >}}

### Creating HTPasswd With Bash

{{< code lang="bash" line-numbers="true" >}}
#!/bin/bash

export HTPASSWD_FILE=${HTPASSWD_FILE:="$HOME/tmp-ocp-dev/ocp-users.htpasswd"}

export INITIAL_USER_NAME=${INITIAL_USER_NAME:="opentlc-mgr"}
export INITIAL_USER_PASS=${INITIAL_USER_PASS:="r3dh4t123!"}

export BULK_NUM_USERS=${BULK_NUM_USERS:=10}
export BULK_USER_PREFIX=${BULK_USER_PREFIX:="user"}
export BULK_USER_SUFFIX=${BULK_USER_SUFFIX:=""}
export BULK_USER_PASSWORD=${BULK_USER_PASSWORD:="openshift"}
export BULK_USER_START_NUM=${BULK_USER_START_NUM:=1}

echo "===== Creating HTPasswd file..."
touch $HTPASSWD_FILE

echo "===== Create the initial user..."
htpasswd -c -B -b $HTPASSWD_FILE $INITIAL_USER_NAME $INITIAL_USER_PASS

echo "===== Create bulk users..."
for ((n=$BULK_USER_START_NUM;n<$BULK_NUM_USERS;n++))
do
  BULK_USERNAME="${BULK_USER_PREFIX}${n}${BULK_USER_SUFFIX}"
  echo "  Adding ${BULK_USERNAME} to ${HTPASSWD_FILE}..."
  htpasswd -b $HTPASSWD_FILE ${BULK_USERNAME} ${BULK_USER_PASSWORD} >/dev/null 2>&1
done
{{< /code >}}

### Setting the IdP

With the HTPasswd file created you can now apply it to the cluster:

{{< code lang="bash" line-numbers="true" >}}
## Set some vars
DEV_DIR="$HOME/tmp-ocp-dev"

## Create the secret that houses the HTPasswd file
oc create secret generic htpasswd-secret --from-file=htpasswd=${DEV_DIR}/ocp-users.htpasswd -n openshift-config

## Create the OAuth Config YAML file
cat > ${DEV_DIR}/htpasswd-oauth-idp.yaml << EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: HTPasswd
    mappingMethod: claim 
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpasswd-secret
EOF

## Backup current OAuth config
oc get OAuth cluster -o yaml > ~/oauth-cluster.yaml.bak-$(date +%s)

## Apply the new config
oc apply -f ${DEV_DIR}/htpasswd-oauth-idp.yaml
{{< /code >}}

### Cluster Permissions

Likely the users also need some permissions - maybe `opentlc-mgr` needs `cluster-admin`...

{{< code lang="bash" line-numbers="true" >}}
## Add the cluster role to the opentlc-mgr user
oc adm policy add-cluster-role-to-user cluster-admin opentlc-mgr

## Remove the kubeadmin user if you feel comfortable doing so - this is ideally done before a workshop, after testing that `opentlc-mgr` has cluster-admin access
oc delete secrets kubeadmin -n kube-system
{{< /code >}}

---

## Find the Workshop Source

Workshops that are available via RHPDS usually have a matching agnosticD deployer.

[agnosticD](https://github.com/redhat-cop/agnosticd) is the collection of Ansible content that helps deploy most of the workloads in RHPDS.

If it's not in the agnosticD repo then you may find it in other orgs/repos. A Google/GitHub search can often find it.

> For this example, we're deploying the OCP Service Mesh 2.0 Workshop and the deployer is indeed in agnosticD.

1. Navigate to https://github.com/redhat-cop/agnosticd
2. Find the role for the workload you're deploying - in this case it's under `ansible/roles_ocp_workloads/ocp4_workload_servicemesh_workshop/`.  If it's not under `ansible/roles_ocp_workloads/` it may be under `ansible/roles_ocp_workloads/`

Once you found your source, clone it down to your local terminal - where you set up the AWS Credentials file in the previous step.

{{< code lang="bash" line-numbers="true" >}}
## Set some vars
DEV_DIR="$HOME/tmp-ocp-dev"

## Make a new directory for easy disposal
mkdir -p $DEV_DIR

cd $DEV_DIR

git clone https://github.com/redhat-cop/agnosticd

cd agnosticd

cd ansible/roles_ocp_workloads/ocp4_workload_servicemesh_workshop/
{{< /code >}}

From this directory you can find a few key Tasks:

- main.yml - This kicks off the Role and the rest of the Tasks based on an `ACTION` variable
  - pre_workload.yml - The first set of Tasks run is for anything that needs to be deployed prior to actual scaling workloads
  - workload.yml - This will provision the bulk of most workshops and will likely call other Task files as well
    - install_elasticsearch_operator.yaml
    - install_jaeger_operator.yaml
    - install_kiali_operator.yaml
    - install_servicemesh_operator.yaml
    - per_user_workload.yaml
    - homeroom.yaml
  - post_workload.yml - Usually most reporting and testing is done at this stage
  - remove_workload.yml - Tasks set for uninstalling the workshop

---

## Creating a Bootstrap Playbook

> Note: This is not the official way to use AgnosticD workload roles - it's just the most painless way to do it

While in the workshop source role directory, make a file called `bootstrap.yaml` to quickly provision the workshop to a locally authenticated AWS/OCP environment.

Take a note of the variables defined in `defaults/` and `vars/` where applicable.

For workshop workloads you'll need an `ACTION` variable that is either `create` or `destroy` and often a `user_count` variable defined.

Create a new Playbook as follows:

{{< code lang="yaml" line-numbers="true" >}}
---
- name: Deploy workshop
  connection: local
  hosts: localhost
  vars:
    ACTION: create
    user_count: 75
    ## FRAMEWORK variables - do not change.
    become_override: false
    ocp_username: opentlc-mgr
    silent: false

    ## ADD Variables here for use in your role, if needed.
    ## When you go to create a ServiceNow ticket to create
    ## the RHPDS catalog item, you can ask the engineer to feed
    ## values the requesting user enters in the form in RHPDS
    ## into these variables. Everything you add here should be
    ## prefixed with the role name: ocp4_workload_servicemesh_workshop_*

    ## Workshop Settings
    ocp4_workload_servicemesh_workshop_user_count: "{{ num_users | default(user_count) | default(1) }}"
    ocp4_workload_servicemesh_workshop_image_repo: quay.io/redhatgov/service-mesh-workshop-dashboard
    ocp4_workload_servicemesh_workshop_image_tag: "2.2"

    ## Operator Settings
    ocp4_workload_servicemesh_workshop_elasticsearch_channel: "4.6"
    ocp4_workload_servicemesh_workshop_jaeger_channel: stable
    ocp4_workload_servicemesh_workshop_kiali_channel: stable
    ocp4_workload_servicemesh_workshop_servicemesh_channel: stable
    ocp4_workload_servicemesh_workshop_rhsso_channel: alpha
    ocp4_workload_servicemesh_workshop_elasticsearch_starting_csv: "elasticsearch-operator.4.6.0-202103010126.p0"
    ocp4_workload_servicemesh_workshop_jaeger_starting_csv: "jaeger-operator.v1.20.3"
    ocp4_workload_servicemesh_workshop_kiali_starting_csv: "kiali-operator.v1.24.7"
    ocp4_workload_servicemesh_workshop_servicemesh_starting_csv: "servicemeshoperator.v2.0.5"
    ocp4_workload_servicemesh_workshop_rhsso_starting_csv: "rhsso-operator.7.4.7"

    ## Operator Catalog Snapshot Settings
    ocp4_workload_servicemesh_workshop_catalogsource_name: redhat-operators-snapshot-servicemesh-workshop
    ocp4_workload_servicemesh_workshop_catalog_snapshot_image: quay.io/jakang/olm_snapshot_redhat_catalog
    ocp4_workload_servicemesh_workshop_catalog_snapshot_image_tag: "v4.6_2021_05_23"
    #ocp4_workload_servicemesh_workshop_catalog_snapshot_image_tag: "v4.8_2021_10_01"

  tasks:
  - name: Kick off the deployment
    include_tasks: tasks/main.yml
{{< /code >}}

The variables will likely be a little different depending on what workshop/workload you are deploying.

Run the Bootstrap Playbook:

{{< code lang="bash" line-numbers="true" >}}
ansible-playbook bootstrap.yaml
{{< /code >}}

---

## Uninstalling the Workshop/Workload

Mature AgnosticD role often have uninstallation Tasks that can clear out the deployments, reverting to something close to the prior state of the cluster.  Not all items may be removed from a cluster, some CRDs could be left behind by lazy Operators, Helm Charts, etc.

{{< code lang="bash" line-numbers="true" >}}
ansible-playbook -e ACTION=destroy bootstrap.yaml
{{< /code >}}

---

## Destroying the Cluster

If you have kept the installation directory used by the openshift-install binary then you can easily delete all the cluster resources:

{{< code lang="bash" line-numbers="true" >}}
## Set some vars
DEV_DIR="$HOME/tmp-ocp-dev"

cd $DEV_DIR

./openshift-install destroy cluster --dir=ocp
{{< /code >}}

If you don't have the install-config files still available then if you deployed via RHPDS/RHOE you can destroy your whole sub-account.