---
title: "Your Own Git-driven Blog with Hugo and Kubernetes"
date: 2021-11-15T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/your-own-blog.png
tags:
  - homelab
  - containers
  - kubernetes
  - git
  - cloud
  - dns
  - hugo
  - blogging
  - ingress-nginx
  - cert-manager
  - automation
  - github actions
authors:
  - Ken Moini
---

> We lost the Golden Age of the Internet somewhere between GeoCities and Facebook - and Xanga was so much better than LiveJournal

There are ***SO*** many people doing ***really*** cool things that...*just need a place to live and be shared from.*

You have the usuals - Mediums, Dev.to, and Hashinode...which really is a tragic name because I think it's just some weird new Hashicorp product.

What if you want to forgo having your content hosted on some other platform - and host it yourself without having to go through all the tedium of something like WordPress?  Ask yourself the following questions:

- Can you use and write in Asciidoc or Markdown?
- Is most of the content static, outside of maybe something like Comments?
- Do you want to be able to deploy your blog on VMs or in containers, maybe even onto Kubernetes without much funny business?

> ***If so, then [Hugo](https://gohugo.io/) is for you!***

Follow along for a step-by-step tutorial on how I built this very blog and how you can too - just make sure to change your answers a bit so it doesn't look exactly like mine, eh?

---

## What is Hugo?

[Hugo](https://gohugo.io/), much like [Jekyll](https://jekyllrb.com/) and many of its ilk, is a Static Site Generator - meaning it takes content from Asciidoc or Markdown and turns it into static HTML with the needed CSS and JavaScript.  No databases, no extra runtimes, just serve it via any HTTP server.

This works out for more situations than you'd think of initially.

Static sites also have the benefit of a smaller surface area for attacks - no Drupal or PHP to exploit, fewer plugins to XSS, no unstanitized inputs streamed into a database.  Note that you're likely to have some Javascript on the site, and you can still use this as the frontend in a classic 3-tier architecture.

---

## Got a domain?

So first thing is you probably need a domain name, ya know, like `kenmoini.com` but with your name/moniker instead.  I suggest using something like [Namecheap](https://www.namecheap.com/) - something better than GoDaddy ideally.

Register your domain, then you'll need to point it to your DNS Servers.  You could use the DNS Servers that Namecheap provides but for this article we'll assume you're going to use [DigitalOcean's DNS service](https://docs.digitalocean.com/products/networking/dns/).

---

## Got a host?

Speaking of [DigitalOcean](https://m.do.co/c/9058ed8261ee "A referral link, get $100 in free credits") - where are you going to host this site?

Sure, you could spin up a little DigitalOcean Droplet VM, `dnf install nginx`, and you're on your way more or less...but...***why not deploy to Kubernetes instead?***

If you need a primer on setting up a DigitalOcean Kubernetes cluster, you can read more about it here: [Functional Kubernetes on DigitalOcean](https://kenmoini.com/post/2021/10/functional-kubernetes-on-digitalocean/)

---

## Your Development Environment

This guide will assume you're on a Linux or Mac system - if you're using Windows then check out Windows Subsystem for Linux.

### Directory Structure

You could lump everything into one directory, but let's set up some organized chaos with a basic directory structure for a site at `example.com`:

{{< code lang="bash" command-line="true" output="" >}}
## Create Project folder
mkdir -p ~/Development/example-com

## Create Project binary directory
mkdir -p ~/Development/example-com/bin

## Navigate to the Project folder
cd ~/Development/example-com/
{{< /code >}}

### Get Binaries

Next what's needed is to be able to run the Hugo binaries and a `podman {build,run}`.  You could of course use `docker` instead but all the cool kids are using `podman` now.

Download the Hugo binary for your system from here - ideally the Extended version so you can have it do SCSS compilation and other fun things: https://github.com/gohugoio/hugo/releases

Store the extracted Hugo binary in the `~/Development/example-com/bin` directory:

{{< code lang="bash" command-line="true" output="" >}}
## Create a temporary working directory and enter it
mkdir -p ~/Development/example-com/tmp
cd ~/Development/example-com/tmp

## Download the Hugo Extended Binary for Linux x86_64
wget https://github.com/gohugoio/hugo/releases/download/v0.89.2/hugo_extended_0.89.2_Linux-64bit.tar.gz

## Extract the TAR package
tar zxvf hugo_extended_0.89.2_Linux-64bit.tar.gz

## Move the binary to our bin directory
mv hugo ../bin/hugo-linux-amd64

## Download the Hugo Extended Binary for MacOS x86_64
wget https://github.com/gohugoio/hugo/releases/download/v0.89.2/hugo_extended_0.89.2_macOS-64bit.tar.gz

## Extract the TAR package
tar zxvf hugo_extended_0.89.2_macOS-64bit.tar.gz

## Move the binary to our bin directory
mv hugo ../bin/hugo-macosx-amd64

## Make binaries executable
chmod +x ../bin/*

## Clean up
cd ..
rm -rf tmp/
{{< /code >}}

Having a copy of the binary local to the project helps build compatability and speeds up CI/CD builds vs having to fetch them from the Internet.

---

## Building a New Hugo Site

Now that the Hugo binary is available, we can use it to generate the base skeleton of a new site to build on:

{{< code lang="bash" command-line="true" output="" >}}
## Change to the project root if not there already
cd ~/Development/example-com/

## Generate the site with the linux binary
./bin/hugo-linux-amd64 new site site -f yaml

## OR...
./bin/hugo-macos-amd64 new site site -f yaml
{{< /code >}}

That command will generate the skeleton in a subdirectory called `./site`, which will make it easier to organize our site content separately from the automation and deployment content.  The `-f yaml` suffix tells Hugo to create a site with a YAML-based configuration file which is easier to use than the TOML based one.

---

## Finding & Using a Theme

Now that we have a skeleton, the first thing you'll need to do is find a theme - there's a great site for free Hugo themes: https://themes.gohugo.io/

For the purposes of this article, let's assume to use the [terminal](https://themes.gohugo.io/themes/hugo-theme-terminal/) theme.  Note that different themes will have different configuration and features.

You can initialize the theme as a Go module, but I prefer to do it the old fashioned way by extracting the Git repo's package:

{{< code lang="bash" command-line="true" output="" >}}
## Change to the project root if not there already
cd ~/Development/example-com/

## Change to the site's themes directory
cd site/themes

## Download the theme
wget https://github.com/panr/hugo-theme-terminal/archive/refs/heads/master.zip

## Extract the theme
unzip master.zip

## Delete the zip
rm master.zip

## Move the theme
mv hugo-theme-terminal-master/ terminal/
{{< /code >}}

With the theme where it needs to be, tell your Hugo site to use it by modifying the site's config file - modify your `~/Development/example-com/site/config.yaml` file to look something like this:

{{< code lang="yaml" line-numbers="true" >}}
baseURL: http://example.com/
languageCode: en-us
title: My New Hugo Site
theme: terminal
{{< /code >}}

To see additional configuration supported by the theme look in `~/Development/example-com/site/themes/terminal/exampleSite/` and you'll find a set of files you could drop into the site root for some example content - one of those files is a `config.toml` file with other theme-supported configuration.  You can use this site to convert TOML into YAML: https://toolkit.site/format.html

## Your First Blog Post

Now that we have a basic site and basic theme, what's needed is some content!  Let's add our first blog post:

{{< code lang="bash" command-line="true" output="" >}}
## Change to the project root if not there already
cd ~/Development/example-com/

## Change to the site root
cd site

## Add a new blog post
../bin/hugo-linux-amd64 new posts/my-awesome-blog-entry.md
{{< /code >}}

Hugo will generate a new file in `~/Development/example-com/site/content/posts/my-awesome-block-entry.md` - make sure to add some content to it.

This uses the default [Archetype](https://gohugo.io/content-management/archetypes/) of `posts` - you can include additional Archetypes and set their defaults with the files located in `~/Development/example-com/site/archetypes/`.

There is some default [Front Matter](https://gohugo.io/content-management/front-matter/) metadata that is useful, such as the `drafts: true` Front Matter that allows you to have content you're working on not be included in the static site generation.

The theme can also extend the Front Matter of content so make sure to `cat ~/Development/example-com/site/themes/terminal/exampleSite/content/posts/hello.md` for an overview of the options it provides, such as `cover: header.jpg`.

### Cheat Code: Theme-Provided Example Content

In case you're one to learn by disassembly and tinkering then you may find benefit in just using the exampleSite content provided by the theme and modifying from there:

{{< code lang="bash" command-line="true" output="" >}}
## Change to the project root if not there already
cd ~/Development/example-com/

## Change to the site root
cd site

## Copy exampleSite files to our site
cp -R themes/terminal/exampleSite/{content,static}/ .
{{< /code >}}

---

## Preview Your Website

Now that you have a site with a theme and some content, you can finally generate the static site content.  To do this locally, use the developmental HTTP server built into Hugo:

{{< code lang="bash" command-line="true" output="" >}}
## Change to the project root if not there already
cd ~/Development/example-com/

## Change to the site root
cd site

## Start the Hugo development server
../bin/hugo-linux-amd64 serve --bind 0.0.0.0 --port 1234
{{< /code >}}

Now you can navigate to http://localhost:1234/ and access the site - you can also develop and update content and it should reload on the fly!

---

## General Configuration & Settings

With the basic site, theme, and a bit of content you're off to the races - of course, a site is nothing without the content so make sure to add plenty of pages and posts.

There are probably a few places that you'll want to make some preliminary changes before hosting the site, such as maybe adding your social information, changing pagination limits, and modifying your menu.

---

## Basic Theme Modifications

---

## Hugo in a Container

There are always different ways to containerize applications - since Hugo generates static sites using just a binary it's pretty easy to stick that process in a multi-layer container image build.

So the process for our container build would look like:

- First layer, the Builder image, runs the `hugo` command to generate the site
- Second layer, the Runtime image which is just a simple NGINX container, has the generated files copied over from the Builder image to the web root

This is what it looks like in our `Containerfile`:

{{< code lang="docker" line-numbers="true" >}}
## Pull a Golang Builder image
FROM quay.io/polyglotsystems/golang-ubi AS builder

## Set a working directory
WORKDIR /workspace

## Copy files from the Git repo over to the working directory
COPY . /workspace

## Generate the static files
RUN cd /workspace/site \
 && ../bin/hugo-linux-amd64

## Switch to the NGINX Runtime image layer
FROM quay.io/polyglotsystems/ubi8-nginx

## Copy files from the Builder image layer to the webroot of our NGINX container
COPY --from=builder /workspace/site/public /var/www/html

## Add some metadata to help users find what port to use
EXPOSE 8080

## Set a default non-root user that will work well in almost any K8s/OCP cluster
USER 1001
{{< /code >}}

This uses images offered by Polyglot Systems on [Quay](https://quay.io/) - you can swap out for any other Golang and Nginx/Httpd image from something like Docker Hub but just know that using Docker Hub will likely cause your automated builds to fail due to pull limits.  Quay does not have pull limits and provides container security scanning which is why I prefer it.

Anyway, with that Containerfile created, you can build and run it with the following commands locally:

{{< code lang="bash" command-line="true" output="" >}}
## Build a container from the Containerfile with a tag of my-blog
podman build -f Containerfile -t my-blog .

## Run the my-blog tagged image and expose the port
podman run -p 8080:8080 my-blog
{{< /code >}}

From there you should be able to access the container running at `http://localhost:8080`

This is great and all for local development but how do we do automatic builds and deployment?  This is where some basic CI/CD comes into play and we'll use GitHub Actions in this scenario.

---

## Git It Loaded

---

## Automate Deployment with GitHub Actions

---

## Taking Pulse - Plausible Analytics

So it's always handy to have some analytics of the consumption of your site - did you just get dropped on HackerNews and not know it?  What's your most popular content?  Where are your users coming/going from?  Are they actually reading any of what you've typed?

There's always Google Analytics but something better would may be something like [Plausible Analytics](https://plausible.io/self-hosted-web-analytics) - it's open-source and much kinder on the whole privacy thing.

You can read all about how to deploy it on this very same Kubernetes cluster here: [Goodbye Google, Hello Plausible](https://kenmoini.com/post/2021/11/goodbye-google-hello-plausible/)

---

## The Peanut Gallery - Comments via Disqus