#!/bin/bash

#  NOTES:  Separated this to its own script
# STATUS:  Not even close to finished and not that important right now.
#   TODO:  add post_install.sh, docker stuff, channel mgmt

# Install supporting pakcages on Bastion
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct

