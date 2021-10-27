---
title: "GitLab Container Registry with Minio Custom S3 Endpoint"
date: 2019-04-07T22:31:48-05:00
draft: false
listed: true
aliases:
    - /blog/gitlab-container-registry-with-minio-custom-s3-endpoint/
hero: /images/posts/heroes/resized/resized-gitlab-registry-minio-s3.png
tags: 
  - amazon
  - ansible
  - aws
  - buildah
  - CI/CD
  - containers
  - devops
  - gitlab
  - minio
  - podman
  - red hat
  - rhel
  - s3
  - skopeo
  - storage
authors:
  - Ken Moini
---

Every time I get on this site to try to write something and post a new blog entry, it just ends up in the Elephant Graveyard of Drafts.

I have half a dozen other posts waiting to be completed, on things such as how WordPress causes 1/3rd of the Internet to be vulnerable due to shipping old code, to a top-to-bottom view of Progressive Web Apps and Service Workers (super fun), OpenSCAP, and GPS NTP servers.  Just need time to sit down and finish them, which is easier said than done since many of those subjects are kind of in-depth.

I’ll keep this one short and simple: I’ve got a bunch of DevOps-y things running, two of them being Minio for S3 storage, and GitLab for SCM and to act as a Container Registry (!).  There were some issues in getting it to work together, here’s how I fixed them and to set GitLab’s Container Registry to use a custom S3 solution like Minio as a storage layer.

## K.I.S.S. Me

Ok, so a complex problem – scalable enterprise application development with DIY S3 storage.  We’re building containers and managing them in a registry to enable some microservice based DevSecOps hoop-de-la and all sorts of other fun stuff.  Bottom line, I need to deploy a vendor-neutral S3 storage solution to back our container registry and applications.  Enter [Minio](https://github.com/minio/minio).

**Minio** is an S3-compliant application stack which includes a server and client.  This means we can host our own "AWS S3" on any normal server anywhere.

**Now to make things even easier, I’ve created an Ansible Playbook that’ll configure any host you point it to configure and run a Minio server**.  You can get all of the goodness here: https://github.com/kenmoini/ansible-minio.

Great, now that we’ve got a Minio server running just by running an Ansible Playbook, we can move onto our next task of installing GitLab.

Thankfully, installing GitLab couldn’t be easier.  [Take a quick drive through the process](https://about.gitlab.com/install/), or continue to the configuration steps.

## Plug-n-Play

So if you were to use Amazon’s S3 SaaS, it’s a quick and easy plug and play solution – drop a few variables in and it just knows where to go and what to do.

The documentation for GitLab is normally fantastic and very detailed, though it can’t cover every possible combination or configuration switch.  Though I do wish it were easier to find…I had to basically fuzz test with the Docker Distribution Registry options and find something that worked.  The documentation shows how to use an S3 store as the container registry storage backing, but not with a custom endpoint URL.

So let’s open up our /etc/gitlab/gitlab.rb file and modify a few things...

{{< highlight bash >}}
$ # vi /etc/gitlab/gitlab.rb
{{< /highlight >}}

You’ll want to find the section about registries and make sure your config looks at least a little like this:

{{< highlight yaml >}}
...
################################################################################
## Container Registry settings
##! Docs: https://docs.gitlab.com/ce/administration/container_registry.html
################################################################################

registry_external_url 'https://registry.gitlab.example.com'

##c Settings used by GitLab application
gitlab_rails['registry_enabled'] = true
gitlab_rails['registry_host'] = "registry.gitlab.example.com"
gitlab_rails['registry_port'] = "5000"
gitlab_rails['registry_path'] = "/var/opt/gitlab/gitlab-rails/shared/registry"

###! **Do not change the following 3 settings unless you know what you are
###!   doing**
# gitlab_rails['registry_api_url'] = "http://localhost:5000"
# gitlab_rails['registry_key_path'] = "/var/opt/gitlab/gitlab-rails/certificate.key"
# gitlab_rails['registry_issuer'] = "omnibus-gitlab-issuer"

### Settings used by Registry application
registry['enable'] = true
# registry['username'] = "registry"
# registry['group'] = "registry"
# registry['uid'] = nil
# registry['gid'] = nil
# registry['dir'] = "/var/opt/gitlab/registry"
# registry['registry_http_addr'] = "localhost:5000"
# registry['debug_addr'] = "localhost:5001"
# registry['log_directory'] = "/var/log/gitlab/registry"
# registry['env_directory'] = "/opt/gitlab/etc/registry/env"
# registry['env'] = {
#   'SSL_CERT_DIR' => "/opt/gitlab/embedded/ssl/certs/"
# }
# registry['log_level'] = "info"
# registry['log_formatter'] = "text"
# registry['rootcertbundle'] = "/var/opt/gitlab/registry/certificate.crt"
# registry['health_storagedriver_enabled'] = true
# registry['storage_delete_enabled'] = true
# registry['validation_enabled'] = false
# registry['autoredirect'] = false
# registry['compatibility_schema1_enabled'] = false

### Registry backend storage
###! Docs: https://docs.gitlab.com/ce/administration/container_registry.html#container-registry-storage-driver
registry['storage'] = {
  's3' => {
    'accesskey' => 'myReallyLongAccessKey123',
    'secretkey' => 'mySuperSecretKey123',
    'bucket' => 'gitlab-registry',
    'region' => 'us-east-1',
    'regionendpoint' => 'http://minio.example.com:9000',
    'secure' => false,
    'encrypt' => false,
    'v4Auth' => true
  }
}
...
{{< /highlight >}}

Now once you change the GitLab configuration you need to run the Chef reconfiguration script…that’s easy too...

{{< highlight bash >}}
# gitlab-ctl reconfigure
{{< /highlight >}}

## Push it real good

Once you have GitLab reconfigured you can push to your Minio S3 GitLab-backed Container Registry! You’re using Podman, Buildah, and Skopeo, right?
***Pro-tip:*** Don’t create OCI format containers if you’re planning on storing containers in GitLab. They use the Docker Distribution default registry which, well, only accepts Docker format containers, not OCI.

{{< highlight bash >}}
# podman login gitlab.example.com
# podman push base-rhel7 gitlab.example.com/my_user/my_repo/base-rhel7:latest
{{< /highlight >}}

{{< figure src="/images/posts/legacyUnsorted/k33jf.jpg" class="col-sm-12 text-center" >}}
