---
title: "Automate Microsoft 365 DNS in DigitalOcean"
date: 2020-05-21T21:02:47-05:00
draft: false
toc: false
hero: /images/posts/heroes/do-dns-m365.png
excerpt:
tags: 
  - microsoft
  - microsoft 365
  - office 365
  - dns
  - digitalocean
  - digital ocean
  - automation
authors:
  - Ken Moini
---

I really do need to get into the habit of writing more often.  It's good for the soul, ya know?

I can't even remember what the last thing I wrote here was...***checks receipts***...oh, wow, yeah, it's been a while.  That's not to say I haven't been writing, it's just not been here, and still not much...

***What's new?***  Well, left a number of toxic relationships, personally and professionally.  It's done a wonder for my health and well-being - "When you score, look out for your fans but pay attention to the ones who don't clap unless there's something in it for them too".

Oh, and I'll be ***launching my new business*** in a month or so - waiting until I move to do so, but I have at least been setting up some of the online properties and deploying some assets.  In this new venture, I'm actually using Microsoft 365 instead of my usual with Zoho or Google GSuite.

## To be honest, ***I really like Microsoft 365***.  

As a GSuite user for years, the portfolio of web-based apps work well enough for 80% of what everyone wants to do, but is seriously nerfed in others so having real Office is nice.  Also, Teams is ***pretty amazing*** - I work out of it centrally, this is pretty much what Sharepoint was *supposed* to be.

What I do not like though, is setting up a couple dozen domains as aliases in...well, it's not just a M365 problem, it'd be the same situation with any SaaS solution that requires DNS changes.  It's just that, well, I had to do it for a lot of domains.

Thankfully, I have already kinda automated some of this before, just not en mass.

## Automated DigitalOcean DNS

So there are a number of tools you could use to automate DNS records - Ansible, Terraform, etc, but sometimes a good ol' Bash script works just fine.

```bash
#!/bin/bash

## Configure DigitalOcean DNS via API requests

## set -x ## uncomment for debugging

export DO_PAT=${DO_PAT:=""}

PARAMS=""
domain=""
returned_record_id=""
ip_addr=""
record_name=""
record_type="A"
record_priority="null"
record_port="null"
record_weight="null"
record_ttl="3600"
force_overwrite='false'
force_add='false'

function print_help() {
  echo -e "\n=== Configure and set DNS on DigitalOcean via the API.\n"
  echo -e "=== Usage:\n\nexport DO_PAT=\"<your_digital_ocean_personal_access_token_here>\" # do this once\n"
  echo -e "./config_dns.sh [ -d|--domain 'example.com' ] [ -i|--ip '12.12.12.12' ] [ -r|--record 'k8s' ] [ -t|--type 'A' ] [ -f|--force ] [ -l|--ttl 3600 ]"
  echo -e "\n=== -t defaults to 'A', all other parameters except -f|--force are required.\n"
  exit
}

if [[ "$#" -gt 0 ]]; then
  while (( "$#" )); do
    case "$1" in
      -f|--force)
        force_overwrite="true"
        shift
        ;;
      -a|--force-add)
        force_add="true"
        shift
        ;;
      -d|--domain)
        domain="$2"
        shift 2
        ;;
      -i|--ip)
        ip_addr="$2"
        shift 2
        ;;
      -t|--type)
        record_type="$2"
        shift 2
        ;;
      -p|--priority)
        record_priority="$2"
        shift 2
        ;;
      -o|--port)
        record_port="$2"
        shift 2
        ;;
      -w|--weight)
        record_weight="$2"
        shift 2
        ;;
      -r|--record)
        record_name="$2"
        shift 2
        ;;
      -l|--ttl)
        record_ttl="$2"
        shift 2
        ;;
      -h|--help)
        print_help
        shift
        ;;
      -*|--*=) # unsupported flags
        echo "Error: Unsupported flag $1" >&2
        print_help
        ;;
      *) # preserve positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
  done
else
  echo -e "\n=== MISSING PARAMETERS!!!"
  print_help
fi

# set positional arguments in their proper place
eval set -- "$PARAMS"

if [ -z "$domain" ]; then
  echo "Domain is required!".
  exit 1
else
  echo "Domain - check..."
fi

if [ -z "$ip_addr" ]; then
  echo "IP Address is required!".
  exit 1
else
  echo "IP Address - check..."
fi

if [ -z "$record_name" ]; then
  echo "Record Name is required!".
  exit 1
else
  echo "Record Name - check..."
fi

function checkForProgram() {
    command -v $1
    if [[ $? -eq 0 ]]; then
        printf '%-72s %-7s\n' $1 "PASSED!";
    else
        printf '%-72s %-7s\n' $1 "FAILED!";
        exit 1
    fi
}

echo -e "\nChecking prerequisites...\n"
checkForProgram curl
checkForProgram jq

## check for the DNS zone
function checkDomain() {
  request=$(curl -sS -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${DO_PAT}" "https://api.digitalocean.com/v2/domains/$domain")
  if [ "$request" != "null" ]; then
    filter=$(echo $request | jq '.domain')
    if [ "$filter" != "null" ]; then
      echo -e "\nDomain [${domain}] DNS Zone exists...\n"
      return 0
    else
      echo "Domain [${domain}] DNS Zone does not exist!"
      return 1
    fi
  else
    echo "Domain [${domain}] DNS Zone does not exist!"
    return 1
  fi
}

## check to see if a record exists
function checkRecord() {
  request=$(curl -sS -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${DO_PAT}" "https://api.digitalocean.com/v2/domains/${domain}/records")
  filter=$(echo $request | jq '.domain_records[] | select((.name | contains("'"${record_name}"'")) and (.type == "'"${record_type}"'"))')
  FILTER_NO_EXTERNAL_SPACE="$(echo -e "${filter}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\n')"
  if [ -z "$FILTER_NO_EXTERNAL_SPACE" ]; then
    echo -e "Record [A - ${record_name}.${domain}.] does not exist!\n"
    return 1
  else
    IP_FILTER="$(echo "${FILTER_NO_EXTERNAL_SPACE}" | jq '.data')"
    returned_record_id="$(echo "${FILTER_NO_EXTERNAL_SPACE}" | jq '.id')"
    echo -e "Record [A - ${record_name}.${domain}.] exists at ${IP_FILTER}...\n"
    return 0
  fi
}

function deleteRecord() {
  request=$(curl -sS -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer ${DO_PAT}" "https://api.digitalocean.com/v2/domains/${1}/records/${2}")
  echo $request
}

## write a DNS record for the supplied arguments (domain, ip, type, record)
function writeDNS() {
  request=$(curl -sS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${DO_PAT}" -d '{"type":"'"${record_type}"'","name":"'"${record_name}"'","data":"'"${ip_addr}"'","priority":'"${record_priority}"',"port":'"${record_port}"',"ttl":'"${record_ttl}"',"weight":'"${record_weight}"',"flags":null,"tag":null}' "https://api.digitalocean.com/v2/domains/${domain}/records")
  echo $request
}

checkDomain $domain

if [ $? -eq 0 ]; then
  checkRecord $domain "@"
  if [ $? -eq 0 ]; then
    if [ "$force_overwrite" == "true" ]; then
      echo -e "Record exists at ID(s):\n ${returned_record_id}\n\nCommand run with -f, overwriting records now...\n"
      for recid in $returned_record_id; do
        deleteRecord $domain $recid
      done
      writeDNS $domain
    elif [ "$force_add" == "true" ]; then
      echo -e "Record exists at ID(s):\n ${returned_record_id}\n\nCommand run with -a, adding additional records now...\n"
      writeDNS $domain
    else
      echo -e "Record exists at ID(s):\n ${returned_record_id}\n\nRun with -f to overwrite.\n"
      exit 1
    fi
  else
    writeDNS $domain
  fi
else
  echo -e "Domain does not exist in DigitalOcean DNS, exiting...\n"
  exit 1
fi
```

***[See this Gist for the latest version](https://gist.github.com/kenmoini/d8926c433ba8ba5dd1341b7d50040aa3)***

So that script allows you to interact with the DigitalOcean API as long as you have the **Environment Variable** `DO_PAT` defined with your DigitalOcean Personal Access Token.

The functions in the script have a few safety precautions so you don't totally FUBAR your DNS zones, but make sure to use it only if you know what you're doing with your DNS records...

### Anywho, how about a few examples, like how to automate all the DNS records required for deploying Microsoft 365 to a domain?

```bash
#/bin/bash

DO_DOMAINS=("example.com" "example.net" "example.org" "example.us")

export DO_PAT="asdfasdfsdfasdf"


for d in ${DO_DOMAINS[@]}; do

    echo "Now processing domain: $d"
    SLUG=$(echo "$d" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr A-Z a-z)

    ./do_dns_worker.sh -d $d -t "MX" -r "@" --ip "$SLUG.mail.protection.outlook.com." --priority 0 --force-add
    ./do_dns_worker.sh -d $d -t "TXT" -r "@" --ip "v=spf1 include:spf.protection.outlook.com -all" --force
    ./do_dns_worker.sh -d $d -t "CNAME" -r "autodiscover" --ip "autodiscover.outlook.com." --force
    ./do_dns_worker.sh -d $d -t "CNAME" -r "sip" --ip "sipdir.online.lync.com." --force
    ./do_dns_worker.sh -d $d -t "CNAME" -r "lyncdiscover" --ip "webdir.online.lync.com." --force
    ./do_dns_worker.sh -d $d -t "CNAME" -r "enterpriseregistration" --ip "enterpriseregistration.windows.net." --force
    ./do_dns_worker.sh -d $d -t "CNAME" -r "enterpriseenrollment" --ip "enterpriseenrollment.manage.microsoft.com." --force
    ./do_dns_worker.sh -d $d -t "SRV" -r "_sip._tls" --ip "sipdir.online.lync.com." --priority 100 --weight 1 --port 443 --force
    ./do_dns_worker.sh -d $d -t "SRV" -r "_sipfederationtls._tcp" --ip "sipfed.online.lync.com." --priority 100 --weight 1 --port 5061 --force

done
```

***[See this Gist for the latest version](https://gist.github.com/kenmoini/d8926c433ba8ba5dd1341b7d50040aa3)***

Outside of the Domain Ownership Validation records, which there are a few ways to go about, these two scripts should automate the rest of your DNS records that are needed for Microsoft 365!  You can even define multiple domains and it'll just take care of all of them in a matter of seconds!

If you're migrating from another service, such as GSuite, make sure to cull your old records before running this.  

~~Don't blame me when you break your DNS~~ ***Enjoy!***
