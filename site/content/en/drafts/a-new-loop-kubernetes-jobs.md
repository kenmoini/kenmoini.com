---
title: "A New Loop - Kubernetes Jobs"
date: 2021-12-02T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/quick-n-dirty-pki.png
tags:
  - red hat
  - workshops
  - rhpds
  - open source
  - oss
  - kubernetes
  - openshift
  - containers
  - jobs
  - config maps
  - cloud
  - automation
authors:
  - Ken Moini
---

> So THAT'S why all these deployments take hours...

At Red Hat there's something called ***Red Hat Product Demo System***, or RHPDS for short.

You can log in, deploy a demo or workshop environment and in a little while you should *ideally* get the information to access the environment and start the demo or hands-on workshop!

It sometime doesn't deploy right so you have to do it manually to your own infrastructure/platforms.  In doing so, you often learn a bit about the workshop's deployment requirements and strategies.

I had to manually deploy the Service Mesh 2.0 workshop, which has a Service Mesh per user, along with all the other things that come along with it.  Well, it waits for every ServiceMeshControlPlane to deploy for every user which can take a while once you hit about 50-75 users.

Most of the deployments are handled by Ansible under the covers which can do a lot of things at scale, but sometimes is not the best solution to do things in parallel.

So for instance, this Service Mesh 2.0 workshop has to do a series of tasks per user such as:

- Creating a set of projects/namespaces
- Creating a CatalogSource
- Setting RBAC
- Installing the RH SSO Operator
- Triggering the InstallPlan
- Waiting for it to Install
- Creating a ServiceMeshControlPlane
- Waiting for it to launch
- Creating the Member and MemberRole
- Reconfiguring Kiali

...a list of processes that has a lot of dependencies to wait on to deploy properly - ***doing so sequencially for each user is an architecture failure***.

> This is where Kubernetes Jobs come in...

## A Faster Way to Mars

Getting to Mars faster takes a bit more engineering efforts - deploying the resources for each user as well requires a bit more engineering but in the long run it's worth it to shave off as much time as possible.

My proposal is simple: use Kubernetes Jobs with ConfigMaps and Environment Variables set to deploy each user workload and provision the environment from within the cluster itself.

This allows all the users to execute their functions at the same time in parallel - speeding up deployment time dramatically.

There is a challenge in procuring status for the overall progress through Ansible, but as long as your Job script returns the right codes you can query for completion of the jobs and then continue with the rest of the Ansible-driven execution steps.

## Building the Job script

First thing we need to do is build the script that's running in the Kubernetes Job so we can map out the additional container requirements - this is likely going to be Bash so let's see what we need to do:

{{< code lang="bash" command-line="true" >}}
#!/bin/bash

## Needed configmaps:
CATALOGSOURCE_YAML_PATH="/opt/catalogsource.yaml"
RBAC_YAML_PATH="/opt/rbac.yaml"
RH_SSO_OPERATOR_YAML_PATH="/opt/rh-sso-operator.yaml"

## Authenticate to the Kubernetes API
APISERVER=https://kubernetes.default.svc
SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
TOKEN=$(cat ${SERVICEACCOUNT}/token)
CACERT=${SERVICEACCOUNT}/ca.crt

export OCP_CLIENT_VERSION=${OCP_CLIENT_VERSION:="4.8"}

if [ -z "$USER" ]; then
  echo "No \$USER defined!"
  exit 1
fi

USER_NS="${USER}"
SM_NS="${USER_NS}-istio"

## Perform a test API Call
curl --fail --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api

## Install tar
microdnf install tar gzip

## Download oc
cd /tmp
curl -o oc.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-${OCP_CLIENT_VERSION}/openshift-client-linux.tar.gz
tar zxvf oc.tar.gz
chmod a+x oc kubectl

## Login with the oc CLI
./oc login --token=${TOKEN} --certificate-authority=${CACERT} ${API_SERVER}

## Create the user namespace/project
./oc new-project ${USER_NS}

## Create CatalogSource for use with catalog snapshot
./oc apply -f ${CATALOGSOURCE_YAML_PATH} -n ${USER_NS}

## Create RBAC permissions for the user
./oc apply -f ${RBAC_YAML_PATH} -n ${USER_NS}

## Install the RH SSO Operator
./oc apply -f ${RH_SSO_OPERATOR_YAML_PATH} -n ${USER_NS}

## Wait for the Operator to deploy
LOOP_ON="true"
while [ $LOOP_ON = "true" ]; do
  # Query for the operator status
  OC_INSTALL_PLANS=$(oc get installplans -n ${USER_NS} -o json)
  echo $OC_INSTALL_PLANS

  CLUSTER_INFO_REQ=$(curl -s \
    --header "Content-Type: application/json" \
    --header "Accept: application/json" \
    --request GET \
  "http://$ASSISTED_SERVICE_IP:$ASSISTED_SERVICE_PORT/api/assisted-install/v1/clusters/$CLUSTER_ID")
  CLUSTER_STATUS=$(echo $CLUSTER_INFO_REQ | jq -r '.status')

  if [[ $CLUSTER_STATUS = "installed" ]]; then
    LOOP_ON="false"
    echo -e "===== Cluster has finished installing...running cluster configuration now (after 15s)...\n"
    sleep 15
    runClusterConfiguration
  else
    echo "===== Waiting for cluster to be fully installed and ready...waiting $CYCLE_TIME_IN_SECONDS seconds..."
    sleep $CYCLE_TIME_IN_SECONDS
  fi
done

## Set InstallPlan Name

## Get InstallPlan

## Approve InstallPlan if necessary

## Get Installed CSV

## Wait until CSV is Installed

## Create the user-istio namespace/project
./oc new-project ${SM_NS}

## Create RBAC permissions for the user
./oc apply -f ${RBAC_YAML_PATH} -n ${SM_NS}

## Delete any limitranges in the user-istio project
set +e
LIMITS=$(./oc get limits -n ${SM_NS} -o name)
if [ $? == 0 ]; then
  for l in "${LIMITS[@]}"
  do
    ./oc delete limits $l -n ${SM_NS}
  done
else
  echo "No limits found..."
fi
{{< /code >}}

With all that we'll need to do a few things to make that script work:

- Mount all the needed templated YAML files as ConfigMaps to the Job container
- Create a namespace/project for all these jobs to take place in
- Create a ServiceAccount with cluster-admin permissions to use since we're doing some administrative work to the individual user environments

...and that's it actually!

### Create Jobs Project

{{< code lang="bash" command-line="true" >}}
./oc new-project workshop-user-jobs
{{< /code >}}

### Create Jobs SA

{{< code lang="bash" command-line="true" >}}
cat > user-job-robot-sa.yaml << EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: user-job-robot
  namespace: workshop-user-jobs
automountServiceAccountToken: false
EOF

./oc apply -f user-job-robot-sa.yaml -n workshop-user-job

## Add cluster-admin role to it
./oc adm policy add-cluster-role-to-user cluster-admin -z user-job-robot -n workshop-user-jobs
{{< /code >}}

### Job Template

{{< code lang="yaml" line-numbers="true" >}}
apiVersion: batch/v1
kind: Job
metadata:
  name: user1-job
  namespace: workshop-user-jobs
spec:
  ttlSecondsAfterFinished: 6900
  template:
    spec:
      serviceAccountName: user-job-robot
      automountServiceAccountToken: false
      containers:
      - name: user1-job
        image: registry.access.redhat.com/ubi8/ubi-minimal:8.5-204
        command: ["bash /opt/bootstrap.sh"]
        volumeMounts:
        - name: jobdata
          mountPath: "/opt"
          readOnly: true
      volumes:
      - name: jobdata
        configMap:
          name: user1-job-data
      restartPolicy: Never
  backoffLimit: 1
{{< /code >}}


### ConfigMap

{{< code lang="yaml" line-numbers="true" >}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: user1-job-data
data:
  user: "user1"
  bootstrap.sh: base64EncodedData==
{{< /code >}}


## CMD Testing Pod

{{< code lang="yaml" line-numbers="true" >}}
apiVersion: v1
kind: Pod
metadata:
  name: ubi
  labels:
    app: ubi
  namespace: test-pod
spec:
  containers:
    - name: ubi
      image: 'registry.access.redhat.com/ubi8/ubi-minimal:8.5-204'
      command: ['sh', '-c', 'echo "Hello, Kubernetes!"']
{{< /code >}}