# Lets Encrypt Certificates

Status:   Work in Progress (2020-04-05)
Purpose:  To detail what is necessary to utilize LetsEncrypt certs in your 
          cluster.  Additionally, I may try to figure out where the certs you
          provide in your inventory, actually end up on the filesystem.


## Overview
My environment is a home lab which has a single ingress/egress point and a single IP.  I also have a domain (linuxrevolution.com) with DNS provided by route53.  Generally OpenShift has a tertiary domain provided - "cloudapps" is usually referenced - in my case it is "ocp3-mwn" (ocp3-mwn.linuxrevolution.com).  My tertiary domain is also handled by route53.


## The process
I'm not going to provide details on how to install RHEL, nor LetsEncrypt - mostly because there are *plenty* of docs out there, and the moment I run "git push" my docs will probably be out of date.  

Now that I have explained the domain name setup - review the command to request the certificates from LetsEncrypt 
NOTE:  I recommend you login to your AWS console and have your domain(s) in-focus before you proceed with the certbot command.
```
certbot-auto certonly --server https://acme-v02.api.letsencrypt.org/directory --manual --preferred-challenges dns -d 'linuxrevolution.com,*.linuxrevolution.com,*.ocp3-mwn.linuxrevolution.com'
```
the command will generate a random string for you to enter as a TXT value with the name "_acme-challenge.linuxrevolution.com" (I don't recall whether I had to do a separate one for "*.ocp3-mwn...")

## Update Inventory
You will need to retrieve the 3 files listed below and put them in /root/TLS
```
# Certificate Foo (testing)
openshift_hosted_router_certificate={"certfile": "/root/TLS/router.pem", "keyfile": "/root/TSL/privkey2.pem", "cafile": "/root/TLS/chain2.pem"}
```
