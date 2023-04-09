---
title: Monitoring and Observability with Grafana and Prometheus
date: 2022-01-16T04:20:47-05:00
draft: true
publiclisting: true
toc: true
hero: /images/posts/heroes/metrics-dashboard.png
tags:
  - rhel
  - red hat
  - enterprise linux
  - kvm
  - libvirt
  - bash
  - oss
  - homelab
  - linux
  - grafana
  - prometheus
  - prom
  - node exporter
  - metrics
  - observability
  - visibility
  - dashboards
  - monitoring
  - containers
  - podman
  - docker
  - alert manager
  - alertmanager
  - ansible
  - automation
authors:
  - Ken Moini
---

> Mastering time-series like Dr Strange

Something I've been needing to do for a while is set up some observability in my networks - mostly to make sure things aren't overheating and are working *tip-top*.

There are at least a few ways to screw this deck together but the way I'm going to go with is with Grafana, Prometheus, Node Exporter, and AlertManager - the last 3 being part of the core Prometheus stack that's widely used by Kubernetes services for monitoring and observability.

This is ***of course*** going to be run as an ensemble of containers with Podman via SystemD.

Since this can get complex very quickly I won't be covering all the dashboards and integrations I'm using - what I will be covering is how to get started with Linux system observability.

---

## Overview

Quickly before diving right in let's take a look over the components beind deployed and their roles in this stack:

- ***[Grafana](https://grafana.com/)*** is a very robust observability and visualization tool that can pull data from many **Data Sources**, display them over many **Dashboards**, with a pluggable architecture.
- ***[Prometheus](https://en.wikipedia.org/wiki/Prometheus_(2012_film))*** is that kick ass movie that's part of the Aliens franchise - it's also a [time-series monitoring tool](https://prometheus.io/) that can scrape and serve metrics from and to different sources.  Instead you could use something like [InfluxDB](https://www.influxdata.com/)
- ***[Node Exporter](https://github.com/prometheus/node_exporter)*** is a piece of software that sits on your *nix nodes and scrapes data from various parts of the system and then aggrigates them into a metrics format that Prometheus can then scrape.  Alternatively there are solutions like [collectd](https://collectd.org/) and [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) that can work with Grafana as agents that scrape metrics from systems.
- ***[AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/)*** handles alerts sent by client applications such as the Prometheus server. It takes care of deduplicating, grouping, and routing them to the correct receiver integration such as email, PagerDuty, or OpsGenie. It also takes care of silencing and inhibition of alerts.

The following exercises will go through deploying Grafana, Prometheus, and AlertManager centrally to a RHEL host with Podman, then deploying NodeExporter to a series of different nodes across my lab with Ansible!

---

## Deploying Node Exporter containers with Ansible

Before setting up the centralized metrics services, let's deploy Node Exporter to a few RHEL hosts via Ansible.  This is pretty easy to do, and isn't dependant on many things since it just scrapes system data and offers it as a flat file at a port on the systems.

### Ansible Directory Structure

Make a few directories for our Ansible Automation files - this won't be the full set of normal directories since the logic isn't too complicated and the tasks and variables will be kept to a single Playbook:

{{< code lang="bash" line-numbers="true" >}}
mkdir -p /opt/ansible-projects/node-exporter/files
{{< /code >}}

---

### Ansible Inventory

Next, define an Inventory file containing the RHEL hosts that will run the Node Exporter contianers:

##### `/opt/ansible-projects/node-exporter/inventory`

{{< code lang="ini" line-numbers="true" >}}
[nodeExporterHosts]
raza ansible_host=192.168.42.40
suki ansible_host=192.168.42.46
endurance ansible_host=192.168.42.49

[nodeExporterHosts:vars]
ansible_ssh_user=kemo
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_ssh_private_key_file=~/.ssh/MasterKemoKey.pem
{{< /code >}}

---

### SystemD Service File

Ansible will be used to deploy a SystemD service to the different Linux hosts - create that service unit file:

##### `/opt/ansible-projects/node-exporter/files/node-exporter.service`

{{< code lang="ini" line-numbers="true" >}}
[Unit]
Description=Metrics Prometheus Node Exporter Container
After=network-online.target
Wants=network-online.target

[Service]
TimeoutStartSec=15
ExecStop=/opt/service-containers/metrics-node-exporter/containerctl.sh stop
ExecStart=/opt/service-containers/metrics-node-exporter/containerctl.sh start
ExecReload=/opt/service-containers/metrics-node-exporter/containerctl.sh restart

Type=forking
Restart=on-failure

[Install]
WantedBy=multi-user.target
{{< /code >}}

---

### Container Init Script

Now we need a small script that will store the logic to actually start and stop the container service:

##### `/opt/ansible-projects/node-exporter/files/containerctl.sh`

{{< code lang="bash" line-numbers="true" >}}
#!/bin/bash

################################################################################### SERVICE VARIABLES
## General Variables
CONTAINER_NAME="metrics-node-exporter"
NETWORK_NAME="host"

CONTAINER_PORTS="-p 9100:9100"

CONTAINER_SOURCE="quay.io/prometheus/node-exporter:latest"

RESOURCE_LIMITS="-m 512m"

################################################################################### EXECUTION PREFLIGHT
## Ensure there is an action arguement
if [ -z "$1" ]; then
  echo "Need action arguement of 'start', 'restart', or 'stop'!"
  echo "${0} start|stop|restart"
  exit 1
fi

################################################################################### SERVICE ACTION SWITCH
case $1 in

  ################################################################################# RESTART/STOP SERVICE
  "restart" | "stop" | "start")
    echo "Stopping container services if running..."

    echo "Killing Node Exporter container..."
    /usr/bin/podman kill ${CONTAINER_NAME}

    echo "Removing Node Exporter container..."
    /usr/bin/podman rm -f -i ${CONTAINER_NAME}
    ;;

  ################################################################################# RESTART/START SERVICE
  "restart" | "start")
    echo "Starting container services..."

    # Deploy Node Exporter
    echo -e "Deploying Node Exporter...\n"
    podman run -dt --name ${CONTAINER_NAME} \
    --net ${NETWORK_NAME} \
    ${CONTAINER_PORTS} \
    ${RESOURCE_LIMITS} \
    ${CONTAINER_SOURCE}

    ;;

esac
{{< /code >}}

### Ansible Playbook

Now we can create the Ansible Playbook that will perform some automation across our 3 defined inventory hosts:

{{< code lang="yaml" line-numbers="true" >}}
---
- name: Deploy Node Exporter to Linux Hosts
  hosts: nodeExporterHosts
  vars:
    installUpdates: true
    installPodman: true
    restartAfterKernelUpdate: true
    service_containers_path: /opt/service-containers/node-exporter
    container_image: quay.io/prometheus/node-exporter:latest

  tasks:
    - name: Update system
      when: installUpdates|bool
      block:
        - name: Update system
          dnf:
            name: "*"
            state: latest
            update_cache: yes
          register: yum_updates

        - name: server update reboot | Check if reboot is needed because kernel was upgraded
          shell: LAST_KERNEL=$(rpm -q --last kernel | awk 'NR==1{sub(/kernel-/,""); print $1}'); CURRENT_KERNEL=$(uname -r); if [ $LAST_KERNEL != $CURRENT_KERNEL ]; then echo 'reboot'; else echo 'no'; fi # noqa 204 306
          register: yum_reboot_hint_result

        - name: set_fact for reboot
          set_fact:
            reboot_hint_result: false
          when: yum_reboot_hint_result.stdout.find("no") != -1

        - name: set_fact for reboot
          set_fact:
            reboot_hint_result: true
          when: yum_reboot_hint_result.stdout.find("reboot") != -1

        - name: Reboot if needed
          reboot:
            reboot_timeout: 3600
          when: reboot_hint_result|bool and restartAfterKernelUpdate|bool

    - name: Install Podman
      dnf:
        name: podman
        state: latest
      when: install_podman|bool

    - name: Create Service Containers Directory
      ansible.builtin.file:
        path: "{{ service_containers_path }}"
        state: directory
        owner: root
        group: root

    - name: Install SystemD Service
      copy:
        src: "files/node-exporter.service"
        dest: "/etc/systemd/system/node-exporter.service"
        owner: root
        group: root
        mode: 0755

    - name: Copy over Init script
      copy:
        src: "files/containerctl.sh"
        dest: "{{ service_containers_path }}/containerctl.sh"
        owner: root
        group: root
        mode: 0755

    - name: Reload systemd
      ansible.builtin.systemd:
        daemon_reload: yes

    - name: Prepull the image
      shell: "podman pull {{ container_image }}"

    - name: Enable and Start Service
      ansible.builtin.service:
        name: node-exporter
        state: restarted
        enabled: yes
{{< /code >}}



---

## Assemble the Metrics Container Ensemble

Now what needs to be done is setting up the central resources which involves a few more steps than just `podman run` to get to the target of something like this...

{{< imgSet cols="1" name="def-grafana-dash" >}}
{{< imgItem src="/images/posts/2022/01/nodeexporter-grafana-dashboard.png" alt="A nice dashboard with many sections of observability goodness!" >}}
{{< /imgSet >}}

### Supporting Directory Structure

There are a few directories that need to be made to support the different container configurations and volumes - make them with the following commands:

{{< code lang="bash" line-numbers="true" >}}
## Create the secret directory
mkdir -p /opt/service-containers/metrics/secrets

## Create the directories needed by Grafana and its DB
mkdir -p /opt/service-containers/metrics/volumes/grafana-config
mkdir -p /opt/service-containers/metrics/volumes/grafana-postgresql-data
mkdir -p /opt/service-containers/metrics/volumes/grafana-data/plugins
mkdir -p /opt/service-containers/metrics/volumes/grafana-provisioning/{dashboards,datasources,notifiers,plugins}

## Create the directories needed the Prometheus stack
mkdir -p /opt/service-containers/metrics/volumes/prom-config
mkdir -p /opt/service-containers/metrics/volumes/prom-data
mkdir -p /opt/service-containers/metrics/volumes/alertmanager-data
{{< /code >}}

Now to load up those directories!

---

### That's a Service Script, init?

*plz read that heading in a British accent*

We'll use SystemD to control the ensemble of pods but the SystemD unit file looks super ugly if we're gonna try to fit everything inside of it - let's break out that logic into a separate Bash script:

##### `/opt/service-containers/metrics/podctl.sh`

{{< code lang="bash" line-numbers="true" >}}
#!/bin/bash

################################################################################### SERVICE VARIABLES
## General Variables
POD_NAME="metrics"
## You can also set the NETWORK_NAME to 'host' and omit the IP_ADDRESS if you're just using container host networking
NETWORK_NAME="lanBridge"
IP_ADDRESS="192.168.42.27"
CONTAINER_PORTS="-p 3000/tcp -p 8080/tcp -p 9090/tcp -p 9093/tcp -p 5432/tcp"

## The base path where configuration and scripts are stored
POD_VOLUME_ROOT="/opt/service-containers/${POD_NAME}"

## Grafana Container Variables
GRAFANA_CONTAINER_NAME="grafana"
GRAFANA_IMAGE="quay.io/bitnami/grafana:latest"
GRAFANA_VOLUME_MOUNTS="-v ${POD_VOLUME_ROOT}/volumes/grafana-provisioning:/opt/bitnami/grafana/conf/provisioning -v ${POD_VOLUME_ROOT}/volumes/grafana-config/grafana.ini:/opt/bitnami/grafana/conf/grafana.ini -v ${POD_VOLUME_ROOT}/volumes/grafana-data:/opt/bitnami/grafana/data"
GRAFANA_ENV_VARS="-e GF_SECURITY_ADMIN_USER=admin -e GF_SECURITY_ADMIN_PASSWORD=$(cat ${POD_VOLUME_ROOT}/secrets/grafana-admin-password) -e GF_RENDERING_SERVER_URL=http://localhost:8080/render -e GF_RENDERING_CALLBACK_URL=http://localhost:3000/"
GRAFANA_RESOURCE_LIMITS="-m 2048m"

## Grafana Image Renderer Container Variables
GRAFANA_IMAGE_RENDERER_NAME="grafana-image-renderer"
GRAFANA_IMAGE_RENDERER_IMAGE="quay.io/bitnami/grafana-image-renderer:latest"
GRAFANA_IMAGE_RENDERER_ENV_VARS='-e HTTP_PORT=8080 -e ENABLE_METRICS="true"'
GRAFANA_IMAGE_RENDERER_RESOURCE_LIMITS="-m 512m"

## Grafana's PostgreSQL Container Variables
GRAFANA_POSTGRESQL_CONTAINER_NAME="grafana-postgresql"
GRAFANA_POSTGRESQL_IMAGE="quay.io/bitnami/postgresql:latest"
GRAFANA_POSTGRESQL_VOLUME_MOUNTS="-v ${POD_VOLUME_ROOT}/volumes/grafana-postgresql-data:/bitnami/postgresql"
GRAFANA_POSTGRESQL_RESOURCE_LIMITS="-m 512m"
GRAFANA_POSTGRESQL_ENV_VARS="-e POSTGRESQL_USERNAME=metrics -e POSTGRESQL_PASSWORD=observability -e POSTGRESQL_DATABASE=grafana"

## Prometheus Container Variables
PROMETHEUS_CONTAINER_NAME="prometheus"
PROMETHEUS_IMAGE="quay.io/prometheus/prometheus:latest"
PROMETHEUS_VOLUME_MOUNTS="-v ${POD_VOLUME_ROOT}/volumes/prom-config:/etc/prometheus:ro -v ${POD_VOLUME_ROOT}/volumes/prom-data:/prometheus:rw"
PROMETHEUS_RESOURCE_LIMITS="-m 2048m"

## Alertmanager Container Variables
ALERT_MANAGER_CONTAINER_NAME="alertmanager"
ALERT_MANAGER_IMAGE="quay.io/prometheus/alertmanager:latest"
ALERT_MANAGER_RESOURCE_LIMITS="-m 512m"
ALERT_MANAGER_VOLUME_MOUNTS="-v ${POD_VOLUME_ROOT}/volumes/alertmanager-data:/alertmanager"

################################################################################### EXECUTION PREFLIGHT
## Ensure there is an action arguement
if [ -z "$1" ]; then
  echo "Need action arguement of 'start', 'restart', or 'stop'!"
  echo "${0} start|stop|restart"
  exit 1
fi

################################################################################### SERVICE ACTION SWITCH
case $1 in

  ################################################################################# RESTART/STOP SERVICE
  "restart" | "stop" | "start")
    echo "Stopping container services if running..."
    
    # Restart Podman to avoid any sort of API issues
    systemctl restart podman

    echo "Killing containers and pods..."
    /usr/bin/podman kill "${POD_NAME}-${GRAFANA_CONTAINER_NAME}"
    /usr/bin/podman kill "${POD_NAME}-${GRAFANA_IMAGE_RENDERER_NAME}"
    /usr/bin/podman kill "${POD_NAME}-${PROMETHEUS_CONTAINER_NAME}"
    /usr/bin/podman kill "${POD_NAME}-${ALERT_MANAGER_CONTAINER_NAME}"
    /usr/bin/podman kill "${POD_NAME}-${GRAFANA_POSTGRESQL_CONTAINER_NAME}"
    /usr/bin/podman pod kill $POD_NAME

    echo "Removing containers and pods..."
    /usr/bin/podman rm -f -i "${POD_NAME}-${GRAFANA_CONTAINER_NAME}"
    /usr/bin/podman rm -f -i "${POD_NAME}-${GRAFANA_IMAGE_RENDERER_NAME}"
    /usr/bin/podman rm -f -i "${POD_NAME}-${PROMETHEUS_CONTAINER_NAME}"
    /usr/bin/podman rm -f -i "${POD_NAME}-${ALERT_MANAGER_CONTAINER_NAME}"
    /usr/bin/podman rm -f -i "${POD_NAME}-${GRAFANA_POSTGRESQL_CONTAINER_NAME}"
    /usr/bin/podman pod rm -f -i $POD_NAME
    
    # Restart Podman to avoid any sort of API issues
    systemctl restart podman

    ;;

  ################################################################################# RESTART/START SERVICE
  "restart" | "start")
    echo "Starting container services..."

    ## If using IP Addresses with Podman, make sure there's no stale lock file left around
    echo "Checking for stale network lock file..."
    FILE_CHECK="/var/lib/cni/networks/${NETWORK_NAME}/${IP_ADDRESS}"
    if [[ -f "$FILE_CHECK" ]]; then
        rm $FILE_CHECK
    fi

    # Create Pod
    echo -e "Deploying Pod...\n"
    podman pod create --name "${POD_NAME}" --network "${NETWORK_NAME}" --ip "${IP_ADDRESS}" ${CONTAINER_PORTS}

    sleep 3

    # Deploy Grafana Image Renderer
    echo -e "Deploying Grafana Image Renderer...\n"
    podman run -dt --pod "${POD_NAME}" \
    --name "${POD_NAME}-${GRAFANA_IMAGE_RENDERER_NAME}" \
    ${GRAFANA_IMAGE_RENDERER_ENV_VARS} \
    ${GRAFANA_IMAGE_RENDERER_RESOURCE_LIMITS} \
    ${GRAFANA_IMAGE_RENDERER_IMAGE}

    sleep 3

    # Deploy Grafana PostgreSQL DB
    echo -e "Deploying Grafana PostgreSQL DB...\n"
    podman run -dt --pod "${POD_NAME}" \
    --name "${POD_NAME}-${GRAFANA_POSTGRESQL_CONTAINER_NAME}" \
    ${GRAFANA_POSTGRESQL_ENV_VARS} \
    ${GRAFANA_POSTGRESQL_RESOURCE_LIMITS} \
    ${GRAFANA_POSTGRESQL_VOLUME_MOUNTS} \
    ${GRAFANA_POSTGRESQL_IMAGE}

    sleep 3

    # Deploy Grafana
    echo -e "Deploying Grafana...\n"
    podman run -dt --pod "${POD_NAME}" \
    --name "${POD_NAME}-${GRAFANA_CONTAINER_NAME}" \
    ${GRAFANA_ENV_VARS} \
    ${GRAFANA_RESOURCE_LIMITS} \
    ${GRAFANA_VOLUME_MOUNTS} \
    ${GRAFANA_IMAGE}

    sleep 3

    # Deploy Alertmanager
    echo -e "Deploying Alertmanager...\n"
    podman run -dt --pod "${POD_NAME}" \
    --name "${POD_NAME}-${ALERT_MANAGER_CONTAINER_NAME}" \
    ${ALERT_MANAGER_RESOURCE_LIMITS} \
    ${ALERT_MANAGER_VOLUME_MOUNTS} \
    ${ALERT_MANAGER_IMAGE}

    sleep 3

    # Deploy Prometheus
    echo -e "Deploying Prometheus...\n"
    podman run -dt --pod "${POD_NAME}" \
    --name "${POD_NAME}-${PROMETHEUS_CONTAINER_NAME}" \
    ${PROMETHEUS_RESOURCE_LIMITS} \
    ${PROMETHEUS_VOLUME_MOUNTS} \
    ${PROMETHEUS_IMAGE}

    ;;

esac
{{< /code >}}

What that script does is:

- Define General and Pod scoped variables
- Define variables for the individual container services for Grafana, the PostgreSQL DB that Grafana will use for persistence, the Grafana Image Rendering service, Prometheus, and Alertmanager
- Stop the containers and pods if a start, stop, or restart action is taken - restarts Podman as well just to be safe
- Create the Pod and start the containers if a start or restart action is taken

---

### SystemD Service Unit File

With the control script created, let's make the SystemD service unit file:

##### `/etc/systemd/system/metrics-ensemble.service`

{{< code lang="ini" line-numbers="true" >}}
[Unit]
Description=Metrics Ensemble
After=network-online.target
Wants=network-online.target

[Service]
TimeoutStartSec=45
Type=forking
Restart=on-failure
ExecStop=/opt/service-containers/metrics/podctl.sh stop
ExecStart=/opt/service-containers/metrics/podctl.sh start
ExecReload=/opt/service-containers/metrics/podctl.sh restart

[Install]
WantedBy=multi-user.target
{{< /code >}}

With that unit file created make sure to reload SystemD: `systemctl daemon-reload`

### Configuration Files

We have the functions needed to manage the service and pod/containers but before we start we need to create some configuration files for some of the services before it'll start all nice and happily...

#### Prometheus Configuration

Prometheus is the time-series database that scrapes and aggrigates all the different monitoring targets - it needs a little information on how often to do said scraping and what targets are in scope.:

##### `/opt/service-containers/metrics/volumes/prom-config/prometheus.yml`

{{< code lang="yaml" line-numbers="true" >}}
global:
  scrape_interval: 10s
  scrape_timeout: 5s
  evaluation_interval: 15s
alerting:
  alertmanagers:
  - static_configs:
    - targets: ['127.0.0.1:9093']
    scheme: http
    timeout: 10s
    api_version: v2
scrape_configs:
- job_name: prometheus
  static_configs:
  - targets: ['localhost:9090']
- job_name: nodeExporter
  static_configs:
  - targets: ['raza.kemo.labs:9100']
  - targets: ['suki.kemo.labs:9100']
  - targets: ['endurance.kemo.labs:9100']
{{< /code >}}

A few key parts of that YAML document are:

- `.global` defines general Prometheus configuration such as how often to scrape data from targets
- `.alerting` configures what Alertmanager instances the Prometheus server sends alerts to, in this case the Alertmanager running in the Pod at port 9093
- `.scrape_configs` sets what targets Prometheus scrapes from - defined are two Jobs, one for scraping the internal Prometheus metrics, and another for NodeExporter metrics scraped from 3 of my RHEL systems

You can find other Prometheus configuration options by [reading more here](https://prometheus.io/docs/prometheus/latest/configuration/configuration/).

---

#### Grafana Admin Password

Instead of passing the default user password into env vars plaintext we can store the value in a file that will be read when the container starts - the init script defined above already has it defined and will look for the password in `/opt/service-containers/secrets/grafana-admin-password`

{{< code lang="bash" line-numbers="true" >}}
echo "someR3allyS3cur3Pa55" > /opt/service-containers/metrics/secrets/grafana-admin-password
{{< /code >}}

---

#### Grafana Configuration

Since this ensemble uses a PostgreSQL DB for configuration persistence we need to define those connection details in some way - this is done via the Grafana configuration file.  There are a few other things that we'll define, for the full list of options you can [read more here](https://grafana.com/docs/grafana/latest/administration/configuration/).

##### `/opt/service-containers/metrics/volumes/grafana-config/grafana.ini`

{{< code lang="ini" line-numbers="true" >}}
# default section
instance_name = grafana

# enable anonymous read access
[auth.anonymous]
enabled = true

[database]
type = postgres
host = 127.0.0.1:5432
name = grafana
user = metrics
password = observability
{{< /code >}}

*The database connection details are defined as environment variables passed to the PostgreSQL container in the above init script.*

---

#### Grafana Data Sources

Next we'll define what Data Sources Grafana will use - in this case it's simply the single Prometheus source, but you could have multiple Prometheus sources, or Telegraf sources, etc...

##### `/opt/service-containers/metrics/volumes/grafana-provisioning/datsources/datasource.yml`

{{< code lang="yaml" line-numbers="true" >}}
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  url: http://localhost:9090
  isDefault: true
  access: proxy
  editable: true
{{< /code >}}

Different options exist for different Data Sources, to learn more about the available configuration options, [read more here](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources).

---

#### Grafana Provisioned Dashboards

Grafana needs to know what sources to pull Dashboards from during automatic provisioning - for our purposes, we'll add the option to pull default Dashboards from the container's mounted file system and sort them by folder name:

##### `/opt/service-containers/metrics/volumes/grafana-provisioning/dashboards/all.yml`

{{< code lang="yaml" line-numbers="true" >}}
apiVersion: 1
providers:
- name: dashboards
  type: file
  updateIntervalSeconds: 30
  allowUiUpdates: true
  options:
    path: /opt/bitnami/grafana/conf/provisioning
    foldersFromFilesStructure: true
{{< /code >}}

There are various options that can be set for Dashboards during the Provisioning process, [read more here](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards).

---

### File System Permissions

Before getting to far and smashing that *Start* button, a few permissions need to be set in order for the different containers to access (or not access) mounted file systems:

{{< code lang="bash" line-numbers="true" >}}
## Set the permissions so the container can access the filesystem

## Bitnami containers classically run as 1001:1001 - set that for Grafana n Co
chown -R 1001:1001 /opt/service-containers/metrics/volumes/grafana-*

## The Prometheus stack runs as nobody:nobody (or 65534:65534)
chown -R nobody:nobody /opt/service-containers/metrics/volumes/prom-*
chown -R nobody:nobody /opt/service-containers/metrics/volumes/alertmanager-data

## Make sure only root can access the secrets path with passwords
chown -R root:root /opt/service-containers/metrics/secrets

## Make the init script executable
chmod a+x /opt/service-containers/metrics/podctl.sh

## Reload SystemD in case it wasn't done before
systemctl daemon-reload
{{< /code >}}

***Note:*** If you still get *Permission Denied* errors from the container logs it might be AppArmor/SELinux...I have SELinux disabled because I'm a lazy bastard.

---

### Start the Metrics Ensemble

With everything in place, it's time to start things up!  And it's more or less a push-button operation now - before having SystemD start the containers, test it by calling the init script manually:

{{< code lang="bash" line-numbers="true" >}}
## Do a start test of the init script
/opt/service-containers/metrics/podctl.sh start

## Do a restart test of the init script
/opt/service-containers/metrics/podctl.sh restart

## Do a stop test of the init script
/opt/service-containers/metrics/podctl.sh stop
{{< /code >}}

If everything started/restarted/stopped without errors then enable and start the SystemD service!

{{< code lang="bash" line-numbers="true" >}}
systemctl enable --now metrics-ensemble
{{< /code >}}

From here you can access the Grafana WebUI from Port 3000 - or if you can setup an [Ingress with HAProxy](/post/2021/10/homelab-haproxy-ingress-with-letsencrypt/) and access something like https://grafana.example.com/ secured by a wildcard certificate on standard ports.

{{< imgSet cols="1" name="grafana-welcome-dash" >}}
{{< imgItem src="/images/posts/2022/01/default-grafana-ui.png" alt="A blank canvas just waiting to report on metrics!" >}}
{{< /imgSet >}}

You can find the ***Login*** button in the bottom left hand corner, and most other navigation functions in the toolbar to the left.  Once logged in you'll find many more buttons available in the left navigation bar.

---

### Dashboards

Speaking of Dashboards, there's a mighty need for some!

You can pull Dashboards from the [Grafana website](https://grafana.com/grafana/dashboards/) dynamically, however you'll find that most of them don't work out of the box and you'll need to perform some modifications.  For this reason I find it best to just download the Dashboard files, modify as needed, and load locally during provisioning.  There's always going to be some initial massaging of a Dashboard because of the sources/inputs/variables/etc that are needed to match your environment.

Since we're going to pull in Linux system information, the Dashboard for this article will be the [Node Exporter Full](https://grafana.com/grafana/dashboards/1860) Dashboard.

{{< imgSet cols="1" name="def-grafana-dash" >}}
{{< imgItem src="/images/posts/2022/01/default-noteexporter-dash.png" alt="What a nice looking Dashboard" >}}
{{< /imgSet >}}

You can download the latest version with the following:

{{< code lang="bash" line-numbers="true" >}}
mkdir -p /opt/service-containers/metrics/grafana-provisioning/dashboards/Lab\ Infrastructure/
cd /opt/service-containers/metrics/grafana-provisioning/dashboards/Lab\ Infrastructure/

wget -O node-exporter-full.json https://grafana.com/api/dashboards/1860/revisions/latest/download 
{{< /code >}}

With that Dashboard located to be mounted by the container, Grafana will automatically load it and store it in a ***Lab Infrastructure*** folder logically in the Dashboard browser.

{{< imgSet cols="1" name="grafana-dashes" >}}
{{< imgItem src="/images/posts/2022/01/grafana-dashboard-browser.png" alt="Use the navigation bar to the left to browse to the Dashboard listing" >}}
{{< /imgSet >}}

The Dashboard Provisioning configuration that was set just before this also allows modification via the UI so we'll use that to modify the Dashboard to work once the container services are started.

---

