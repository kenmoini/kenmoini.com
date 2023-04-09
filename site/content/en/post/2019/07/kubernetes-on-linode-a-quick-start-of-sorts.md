---
title: "Kubernetes on Linode – A Quick Start of Sorts"
date: 2019-07-08T22:31:48-05:00
draft: false
publiclisting: true
aliases:
    - /blog/kubernetes-on-linode-a-quick-start-of-sorts/
hero: /images/posts/heroes/resized/resized-kubernetes-on-linode.png
tags:
  - cert-manager
  - certbot
  - containers
  - devops
  - docker
  - fedora
  - FOSS
  - guide
  - hashicorp
  - helm
  - ingress
  - k8s
  - kuard
  - kubernetes
  - let's encrypt
  - linode
  - memes
  - minikube
  - minio
  - minishift
  - nginx
  - nodebalancer
  - oci
  - open source
  - openshift
  - OSS
  - quick start
  - red hat
  - s3
  - ssl
  - terraform
  - tiller
  - tutorial
authors:
  - Ken Moini
---

When I was at Red Hat Summit, I spent the last day in some sweatpants and meandered about the showroom floor trying to hide my Executive Exchange badge from all the sales vultures.  They announced over the loudspeaker that they were closing up shop soon, and so I made my last round across the room.  To my surprise, there were rows I hadn't gone to yet – the place was massive.  Next thing that surprised me was to see a [Linode](https://www.linode.com/?r=c4acc0a829d048727ced26c4920968c9bc6597fd) booth so as a loyal customer I walked on over.  Chatted real quick, gave a jab about how I can't deploy Red Hat Enterprise Linux on Linode instances unless I install it manually which is kind of a pain.  Their new Cloud Manager allows you to easily make your own Images but it can't be created from Raw or Custom deployed block devices, which is the only way to install RHEL on Linode...*sigh*

Anywho, so it looks like my dreams of easily deploying Red Hat OpenShift on Linode are set for another day…BUT what I can do today is deploy Kubernetes on Linode, which is basically OpenShift without a lot of the things that make using Kubernetes easy.  Oh well, the fun part of vanilla Kubernetes is how daunting it can be! ...right?  Right?!

So recently Linode released a kinda easy way to deploy a Kubernetes cluster on their cloud – sweet!  Let's use that and learn raw dog K8s!

{{< figure src="/images/posts/legacyUnsorted/so-you-want-5cb6ac.jpg" class="col-sm-12 text-center" >}}

## Foreword

This will quickly deploy a Kubernetes cluster with Terraform (via the linode-cli k8s-alpha provisioner) so you're not putting all the tiny pieces together.  However, there is still work involved to get it to serve containers on the public Internet.  Most guides I've seen so far stop at the cluster provisioning – like what the fuck do you do after you have 4 servings of Kubernetes?

This guide will show you how to swim in the wave pool with some steps into Service Account User creation, accessing the Kubernetes Dashboard, Installing Helm and Tiller, creating an Ingress Controller, how to deploy your first container, and how to access it on the Internet with SSL certificates automatically provisioned.

{{< figure src="/images/posts/legacyUnsorted/butwaittheresmore.png" class="col-sm-12 text-center" >}}

## Prerequisites and Setup

First thing you're gonna need is to download a few components, Python (2.7), pip, Terraform, the Linode CLI, and some SSH application.  Honestly, I tried installing this from my Windows 10 desktop with Git Bash and it did not work at all.  Deployed it from my Linux laptop and boom worked right away.  So honestly, I'd just roll a Linux VM if you don't use it as your daily driver.  It'll also make interacting with the Kubernetes cluster that much easier.  For these purposes, I installed a fresh copy of Fedora 30 Workstation as a VM on my desktop, ensuring the network is set to Bridge Mode to my home router – NAT messes everything up with Terraform for some reason...  If you do the same then you can run the following commands to get it up to speed:

{{< code lang="bash" line-numbers="true" >}}
$ sudo yum update -y
$ sudo yum install python2-pip wget curl
$ sudo pip install linode-cli
$ wget https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip && unzip terraform*.zip
$ chmod +x terraform
$ sudo mv terraform /usr/bin/
$ ssh-keygen -t rsa -b 4096
{{< /code >}}

What that does is:

- Update all existing packages
- Install Python & Pip, wget, and curl
- Install Linode CLI
- Install Terraform – Uses a specific version of Terraform, as of this writing only version 0.11.14 works with the deployer as there were changes made in 0.12+
- Generates SSH Keys for your user – this will be used when deploying and connecting to the Kubernetes cluster.

Next you'll need to install kubeadm, kubelet, and kubectl – follow the instructions here: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl

Now you'll need to create a **Personal Access Token** in the Linode Cloud Manager.  Head on over to https://cloud.linode.com/profile/tokens and create a new **Personal Access Token**.  Once you have that, the last step of setup is to paste it in when prompted by running the Linode CLI command:

{{< code lang="bash" line-numbers="true" >}}
$ linode-cli
{{< /code >}}

Enter your Personal Access Token and you'll be able to continue with the creation of the Kubernetes cluster.
Once you enter your token, you'll be prompted for some preferences. First, you'll select your **Default Region**, then the **Default Type of Linode** to deploy – choose your region, the type I suggest is g6-standard-2.  The next question about **Default Image to Deploy** I'd suggest skipping.  You can reconfigure these defaults at any time by running ***linode-cli configure***.

## Create your Kubernetes Cluster

This is actually pretty easy – most of the work so far is getting things set up to run this one command (replacing your-cluster-name with...well...):

{{< code lang="bash" line-numbers="true" >}}
$ linode-cli k8s-alpha create your-cluster-name
{{< /code >}}

The default configuration will use the SSH key we created earlier and spin up 4 new Linodes, 1 Kubernetes Master and 3 Kubernetes Application nodes, all at g6-standard-2 in your default region.  What will happen is a Terraform configuration will be generated and it will ask you to approve these actions – just type in “yes” then wait a few minutes.  Ok, actually you'll wait probably about 15-30 minutes for the cluster to spin up.  As of this writing it's not the latest and greatest Kubernetes version out, 1.15 but rather the cluster is set to install Kubernetes 1.13.6 which all in all isn't too bad as that's closer to what Red Hat OpenShift 3.11 is running right now.

{{< figure src="/images/posts/legacyUnsorted/Screenshot-from-2019-07-08-09-25-00-1024x653.png" class="col-sm-12 text-center" >}}

## Accessing and Interacting with the Kubernetes Cluster

Kubernetes is a platform – a platform that lets you build other platforms...ha.  Either way, the normal way you'll be interacting with the cluster is via the command line – this is because Kubernetes is intended to be heavily automated.  That's not fun though and we like Web UIs and Dashboards!  Once the cluster is spun up, run the following commands:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl cluster-info
$ kubectl get pods --all-namespaces
$ kubectl proxy
{{< /code >}}

Those commands do the following:

- Print out the basic cluster information
- Get all the of pods running in all namespaces in the cluster – check to ensure all of the pods are in a “Running” state
- Opens a proxy between the Kubernetes cluster and your local machine

Normally a Kubernetes cluster doesn't expose its resources as a security pattern – normally.  There are plenty of open and insecure K8s clusters and dashboards unknowingly mining Monero…we'll get into basic security in a second.

When running the kubectl proxy command, you'll create a direct proxy to the cluster so you can access things like the Kubernetes Dashboard via http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

Now you should be prompted with a login prompt with two ways of Signing In, either with a Kubeconfig file or a Bearer Token.

## Creating a new Service Account User – with the cluster-admin role!

The default system user isn't properly scoped so let's go ahead and [create a new user](https://github.com/kubernetes/dashboard/wiki/Creating-sample-user), add the cluster-admin ClusterRole to it, and log in with the new user's Bearer Token.  To do this, you'll need to create two new files, replacing YOUR-USER-NAME with a username of your choice:

**create-user.yaml**

{{< highlight yaml >}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: YOUR-USER-NAME
  namespace: kube-system
{{< /code >}}

**add-cluster-admin-role.yaml**

{{< highlight yaml >}}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: YOUR-USER-NAME
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: YOUR-USER-NAME
  namespace: kube-system
{{< /code >}}

Once you have those two files made, you can run them against your Kubernetes cluster by running the following commands:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl apply -f create-user.yaml
$ kubectl apply -f add-cluster-admin-role.yaml
{{< /code >}}

Something to make mention here is that we've just created a user with the cluster-admin role, which means they are as you can imagine, super-admin across the whole cluster and all namespaces. Be very careful with this user – but you'll notice we didn't apply a password. This is because we'll be using a Secret, specifically this user's Bearer Token which is another form of authentication that's tied to the user we just created. To find your user's Bearer Token run the following command, replacing YOUR-USER-NAME with whatever you chose earlier:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep YOUR-USER-NAME | awk '{print $1}')
{{< /code >}}

That will spit out your Service Account's Bearer Token, which you can use to authenticate with the cluster via things like the Kubernetes Dashboard…go back to that link http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/ and paste in your Bearer Token and you should now be greeted with full access to your Kubernetes cluster via the Dashboard! Woohoo! FINALLY!  We can start doing Kubernetes, right?!  Wrong.

{{< figure src="/images/posts/legacyUnsorted/1_TgP46mqoShBuHLK81H5ehA.jpeg" class="col-sm-12 text-center" >}}

## Installing Helm and Tiller

Helm Charts are a great way to deploy a set of Kubernetes objects as a bundle and has mechanisms for management and upgrades – think of it as the Kubernetes package manager.  There are other technologies similar to this such as Kubernetes Operators, you can use either or both.  Here we'll set up Helm and Tiller.  Helm is the client-side portion while Tiller is deployed onto the Kubernetes cluster and runs the Helm Charts.  It's pretty easy to deploy – you can glance at the instructions here, find your specific release and unpack it into a PATH directory.  Assuming you're running Linux AMD64 as I am, here are the commands as of the writing of this guide:

{{< code lang="bash" line-numbers="true" >}}
$ wget https://get.helm.sh/helm-v2.14.1-linux-amd64.tar.gz
$ tar zxvf helm-v2*.tar.gz
$ sudo mv linux-amd64/helm /usr/local/bin/helm
$ helm --help
{{< /code >}}

{{< figure src="/images/posts/legacyUnsorted/DmO3i5WWwAAUq4w.jpg" class="col-sm-12 text-center" >}}

You should now be able to see the Help output of the Helm command. These Go apps are so easy to install with their binaries… Anywho, the cluster has been provisioned with RBAC so let's create a Service Account for Tiller to use on the cluster. As listed in the documentation on Tiller and Role-Based Access Control, you can quickly make a Service Account with the following YAML:

**tiller-rbac-config.yaml**

{{< highlight yaml >}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
{{< /code >}}

Then apply the new Service Account to the cluster with the following command:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl apply -f tiller-rbac-config.yaml
{{< /code >}}

We can't deploy Helm and Tiller yet to the cluster – we still need to create some SSL certs as by default Tiller is left to be used by anyone, yikes! Let's generate a few SSL certs – the following will be a series of commands though you'll need to answer a few questions in most of the commands to continue:

{{< code lang="bash" line-numbers="true" >}}
$ mkdir helm-tiller-certs && cd helm-tiller-certs
$ echo subjectAltName=IP:127.0.0.1 > extfile.cnf
$ openssl genrsa -out ./ca.key.pem 4096
$ openssl req -key ca.key.pem -new -x509 -days 7300 -sha256 -out ca.cert.pem -extensions v3_ca
$ openssl genrsa -out ./tiller.key.pem 4096
$ openssl genrsa -out ./helm.key.pem 4096
$ openssl req -key tiller.key.pem -new -sha256 -out tiller.csr.pem
$ openssl req -key helm.key.pem -new -sha256 -out helm.csr.pem
$ openssl x509 -req -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -in tiller.csr.pem -out tiller.cert.pem -days 365 -extfile extfile.cnf
$ openssl x509 -req -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -in helm.csr.pem -out helm.cert.pem  -days 365 -extfile extfile.cnf
$ cp ca.cert.pem $(helm home)/ca.pem
$ cp helm.cert.pem $(helm home)/cert.pem
$ cp helm.key.pem $(helm home)/key.pem
{{< /code >}}

At this point, we should have generated a bunch of keys and certificates such as:

- The CA. Make sure the key is kept secret.
  - ca.cert.pem
  - ca.key.pem
- The Helm client files
  - helm.cert.pem
  - helm.key.pem
- The Tiller server files.
  - tiller.cert.pem
  - tiller.key.pem

You can read more about the PKI process here: https://helm.sh/docs/using_helm/#generating-certificate-authorities-and-certificates
Now, finally we can deploy Helm and Tiller to the Kubernetes cluster:

{{< code lang="bash" line-numbers="true" >}}
$ helm init \
--override 'spec.template.spec.containers[0].command'='{/tiller,--storage=secret}' \
--tiller-tls \
--tiller-tls-verify \
--tiller-tls-cert=tiller.cert.pem \
--tiller-tls-key=tiller.key.pem \
--tls-ca-cert=ca.cert.pem \
--service-account=tiller \
--history-max 200
{{< /code >}}

If all goes well, that should install the Tiller component on the Kubernetes cluster. To access Tiller you'll need to forward a port from the cluster to your local machine. You can test it with the following commands:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl -n kube-system port-forward svc/tiller-deploy 44134:44134
$ helm install stable/minio --tls --name my-minio
$ helm list --tls
$ helm delete my-minio --tls
{{< /code >}}

## Ingress Controller

There are a few different Ingress Controllers you can use such as a NodePort or Load Balancer, but for our purposes let's use an Nginx Ingress Controller as it's a little more flexible.  Also, when deploying a Load Balancer directly into Linode's NodeBalancer service, the charges start to stack up quickly.  Thankfully we can quickly deploy an Nginx Ingress Controller with a Helm Chart...

{{< code lang="bash" line-numbers="true" >}}
$ helm install stable/nginx-ingress --name nginx-ingress --set rbac.create=true --tls
{{< /code >}}

That will deploy an Nginx Ingress Controller which will create a Linode NodeBalancer pointing to your nodes. This is where things get kinda slick – we're only going to need one NodeBalancer as this Ingress Controller can route any domain we have pointing to it! Let's make sure to do that – this is the time that you'll add the desired DNS records.

## DNS on Linode

So DNS on Linode is a funny thing...if you go through their traditional Control Panel at https://manager.linode.com/ and try to set any wildcard DNS entries you'll get an error. However, if you goto their fancy-schmancy new https://cloud.linode.com Cloud Manager you can create wildcard DNS entries to your heart's content! This is what's key in being able to use only one NodeBalancer – if you went with the traditional ExternalDNS + LoadBalancer ingress objects then you'd have to wait while the Linode DNS servers propagate your entries which can take up to 30 minutes, and then you'd be buying a separate NodeBalancer for each Ingress object! Yikes!

{{< figure src="/images/posts/legacyUnsorted/d002cd3bce067290b5ea82850d862f4a15b8f0acaab7098cde9f8b1e24999f39.jpg" class="col-sm-12 text-center" >}}

Here are the general steps to do this One NodeBalancer + Wildcard DNS thing; you don't need a wildcard DNS entry, you can point a specific A record to the NodeBalancer but wildcards make it easier to deploy quickly on Kubernetes.

1. Log into your Linode account at https://cloud.linode.com and head over to the NodeBalancers page – you should see the NodeBalancer created by the Nginx Ingress Controller we just deployed with Helm
2. Take that external IP Address and copy it into your clipboard – we'll use this for whatever we point to the Kubernetes cluster
3. Go into the Domains page and select the Domain Name Zone that you'd like to use, let's just call it ***example.com***
4. If you wanted to have your exposed services as ***myapp.example.com, myotherapp.example.com, etc.example.com*** then you can create an A record of * pointing to the external IP of the NodeBalancer.  Any A record that isn't specifically named and pointing to another destination will be matched by this wildcard and sent to the NodeBalancer, which is pointed to the Nginx Ingress on the Kubernetes cluster
5. Wait a while as it propagates...
6. ????????
7. PROFIT!!!!!1

So one last thing you need to do is delete the ExternalDNS deployment in your Kubernetes cluster. As of this writing, the K8s cluster deployed with the linode-cli will try to provision DNS entries in Linode for every ingress route you publish on the cluster – Snoozeville, that takes too long. This can be bad since it'll create A records pointing the specific route directly to the external Kubernetes Worker Node IP address. We don't want this as it'll override the wildcards and any other DNS we set to the NodeBalancer. Go ahead and delete the ExternalDNS deployment with:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl delete deployment -n kube-system external-dns
{{< /code >}}

## On-Demand SSL Certificates for Routes

{{< figure src="/images/posts/legacyUnsorted/1cvwdb.jpg" class="col-sm-12 text-center" >}}

Once we've got DNS routing all our desired domains to the NodeBalancer in front of the Nginx Ingress on the Kubernetes cluster, we need to add SSL termination.  You can do this in a number of ways but the easiest one I've found so far is with cert-manager.  The idea is simple: if the domain responds then you get a cert.  Since we've got a wildcard A record pointing to the cluster, any of those subdomains should be able to automagically get an SSL certificate.  This doesn't do the whole ACME/DNS-tls01 thing as that requires access to the Linode DNS API which again, can be slow and I've seen only times out.  Anywho, let's get to deploying cert-manager which is pretty easy now that we have this fancy Helm thing...

First, we need a service to route to…let's use the KUAR Demo application.

{{< code lang="bash" line-numbers="true" >}}
$ kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/docs/tutorials/acme/quick-start/example/deployment.yaml
$ kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/docs/tutorials/acme/quick-start/example/service.yaml
{{< /code >}}

So we've got a basic application and service on the cluster, let's install the cert-manager service [as described by the [documentation](https://github.com/jetstack/cert-manager/blob/master/docs/tutorials/acme/quick-start/index.rst)]:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
$ kubectl create namespace cert-manager
$ kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
$ helm repo add jetstack https://charts.jetstack.io
$ helm repo update
$ helm install --tls --name cert-manager --namespace cert-manager --version v0.8.1 jetstack/cert-manager
{{< /code >}}

Give that a few seconds and you should have cert-manager deployed. We still need to provide it some certificate Issuers – we'll use the trusty Let's Encrypt with their Staging and Production issuers. The next few lines will create new Kubernetes objects but will allow you to modify the YAML file before importing – you'll need to add your email address at the appropriate lines:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl create --edit -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/docs/tutorials/acme/quick-start/example/staging-issuer.yaml
$ kubectl create --edit -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/docs/tutorials/acme/quick-start/example/production-issuer.yaml
{{< /code >}}

Now you can use the staging Let's Encrypt issuer which isn't rate-limited and great for testing:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl create --edit -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/docs/tutorials/acme/quick-start/example/ingress-tls.yaml
{{< /code >}}

Once you edit and deploy that you should have an SSL Certificate provided to that domain on that Ingress – it'll still an “invalid” self-signed cert but it should be issued directly to that domain. If so, then you can delete that ingress and deploy the final production issued SSL certificates with:

{{< code lang="bash" line-numbers="true" >}}
$ kubectl create --edit -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/docs/tutorials/acme/quick-start/example/ingress-tls-final.yaml
{{< /code >}}

If all things so far have gone well you should now be able to access your KUAR Demo (kuard) service that's being exposed via an ingress with a valid SSL certificate now!

## Conclusion

If you've made it this far then you've got a usable Kubernetes cluster running on Linode!  With one NodeBalancer!  And automagical SSL certificates for your ingress routes!

Either that or you're just skipping down for the comments because you got stuck somewhere – don't worry, it's easy to do this is Kubernetes after all.  This took me way longer than I'd like to admit my first go around.

To recap what we've done is:


1. Setup a new Fedora 30 VM as our jump-box of sorts
2. Deployed Kubernetes on Linode with the linode-cli k8s-alpha provisioner
3. Created a new service account user with cluster-admin roles to administer the cluster
4. Opened a proxy to the cluster and accessed the Kubernetes Dashboard
5. Installed Helm and Tiller
6. Deployed an Nginx Ingress Controller which created a single Linode NodeBalancer
7. Wrangled with Linode DNS to provide wildcard A name resolution to the NodeBalancer, removed ExternalDNS deployment
8. Deployed cert-manager to provide dynamically provisioned SSL certificates from Let's Encrypt
9. Accessed our first container (kuard) from the Internet with SSL!

{{< figure src="/images/posts/legacyUnsorted/1jlg14.jpg" class="col-sm-12 text-center" >}}

## Next Steps & Additional Resources

So what to do next?  Well, you'll probably want a private registry, and maybe some sorta Git, and/or Jenkins so you can do that DevOps-y thing everyone's talking about.  Gotta make sure you secure it, probably want to dump logs into Elastic or Prometheus, add some infrastructure auto-scaling for that Enterprise Container Orchestration feel.  There are lots of places you can go but what's important is that you just start working with the Kubernetes platform and learning what it can offer you.  Don't get me wrong, it'll likely suck and take days of effort to get rolling to where you'd like it, but once that platform is running it just hums.

There are a few other resources I'd suggest – including the obligatory books.


- [**Kubernetes: Up and Running**](https://amzn.to/2G3EhTF) – Written in part by the legend himself, Kelsey Hightower.  I like this book because it has a heavy focus on the “Why” and “How” of Kubernetes and the concepts for the new infrastructure patterns offered by the Kubernetes platform.  Also, they have a part about deploying K8s on Raspberry Pis which is how I rationalized my $1,600 RPi dual K8s+Gluster cluster spend…
- [**Kubernetes in Action**](https://amzn.to/2G0Jege) – This is a much deeper dive into Kubernetes and kinda gets you farther than ER-MA-GERD I HAZ DE KUBERNETES.
- [**Minikube**](https://kubernetes.io/docs/setup/learning-environment/minikube/) – If you have NO CLUE what or how Kubernetes anything, start locally with Minikube before you start burning up that cloud budget.
- [**OpenShift**](https://www.openshift.com/) – So the goal of this project is to lay a foundation of how to deploy OpenShift-like technology with vanilla K8s in a Public Cloud provider that resembles that of on-premise deployments.  OpenShift builds on top of Kubernetes and offers a lot of what we did today out of the box and more and I've used it for a year or so and am spoiled by it…not used to doing all this heavy lifting.
- [**Minishift**](https://github.com/minishift/minishift) – You bet there's a way to deploy OpenShift on your workstation as you would Minikube.
- [**Helm Charts**](https://github.com/helm/charts/tree/master/stable) – Most of the deployments we ran today were provisioned with Helm.  You can find repos and packaged Helm Charts all over.
