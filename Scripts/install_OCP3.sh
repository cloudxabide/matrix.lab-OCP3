#!/bin/bash

#
# @(#)$Id$
#
# Purpose:  Script to roll-out an OCP3 cluster
#  Author:  jradtke@redhat.com
#    Date:  2019-10-31
#   Notes:  This is NOT IaC yet.  :-(
#           This a "non Production" build approach.  
#           I have the bastion setup to do NFS to the cluster (if/when Gluster is not being used)
#           This entire script is intended to be run from the bastion host to all the nodes (the bastion included).
#             Therefore, notice that commands are prefaced by "sudo" and the ssh command includes a '-t'
#             SSH ControlSockets is likely the better/best way to actually be doing this work - but, this is just 
#              a lab and NOT how OCP should be installed anyhow.
#
#    TODO:  Need to figure out a better way for sending the password to ssh-copy-id
#           use getops to either get the password as an ARGV, or set it to a default
#

PASSWORD="Passw0rd"

#set -o errexit
readonly LOG_FILE="/root/install_OCP3.sh.log"
echo "Output being redirected to log file - to see output:"
echo "tail -f $LOG_FILE"

touch $LOG_FILE
exec 1>$LOG_FILE 
exec 2>&1

# Make sure you're on the right host, else leave a message and exit 
[ `hostname -s` != "rh7-ocp3-bst01" ] && { echo "You are on the wrong host"; exit 9; }

# How to manually subscribe
#  subscription-manager register
#  subscription-manager refresh
#  POOLID=`subscription-manager list --available --matches 'Red Hat OpenShift Container Platform' | grep "Pool ID:" | awk '{ print $3 }' | tail -1`
#  subscription-manager attach --pool=$POOLID

# Remove the old ssh-key fingerprint
sed -i -e '/ocp3/d' ~/.ssh/known_hosts

#  Prep-work
(which git) || yum -y install git
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; }
cd ~/matrix.lab/Scripts; git pull

# I may remove this later, as it might actually goof something up
(grep OCP_VERSION ~/.bash_profile) ||  { echo -e "OCP_VERSION=3.11\nexport OCP_VERSION" >> ~/.bash_profile; }
. ~/.bash_profile

# Install "expect" if it is missing
(which expect) || yum -y install expect

# See if there is an ssh key, and create it if not
[ ! -f ~/.ssh/id_rsa ] && { echo | ssh-keygen -trsa -b2048 -N ''; }

# Alright - this next step is a bit "rammy".  HOWEVER... this host should only be used as the Bastion 
#   to an OCP3 Cluster (and, in my case, should not already have any customizations done)

# Establish connectivity and sync ssh-keys to hosts (as root) 
# PASSWORD="Passw0rd" # This was set towards the beginning of this script
[ -f ~/.ssh/config ] && mv ~/.ssh/config ~/.ssh/config.bak
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do 
  echo "Copy SSH key to $HOST"
  ./copy_SSHKEY.exp $HOST $PASSWORD
done
 
# Run the "post_install.sh" script on all the hosts (which adds user:mansible)
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | grep -v bst | awk '{ print $2 }'`
do 
  echo "Connecting to remote host:"
  ssh $HOST "uname -n; sh ./post_install.sh & " 
done
[ -f ~/.ssh/config.bak ] && mv ~/.ssh/config.bak ~/.ssh/config

# Switch the connections to the mansible user 
(grep mansible ~/.ssh/config) || cat << EOF > ~/.ssh/config
Host *.matrix.lab
  User mansible
EOF
chmod 0600 ~/.ssh/config

# Now, distribute the keys to the mansible user
# PASSWORD=Passw0rd
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do
  ./copy_SSHKEY.exp $HOST $PASSWORD
done

# Test the connection (and sudo - which should have been done in a previous script)
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo grep mansible /etc/shadow"; echo ; done

######################################################################
## NOTE: 
## NOTE - if the previous command failed to display the mansible information, 
##          then you need to fix sudo (see: post_install.sh)
## NOTE: 
######################################################################3
# Update the Repos on the hosts dependent on which version of OCP
case $OCP_VERSION in
  3.11)
    OCP_REPOS_MGMT='subscription-manager repos --disable="*" --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-server-ose-3.11-rpms" --enable="rhel-7-server-ansible-2.6-rpms"'
  ;;
  3.9)
    OCP_REPOS_MGMT='subscription-manager repos --disable="*" --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-server-ose-3.9-rpms" --enable="rhel-7-fast-datapath-rpms"  --enable="rhel-7-server-ansible-2.4-rpms"'
  ;;
esac

# Go update all the hosts with the correct/appropriate Repos
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do
  ssh -t $HOST << EOF
    uname -n
    sudo  $OCP_REPOS_MGMT &
    echo
EOF
done

# Install supporting pakcages on Bastion
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct

# Set Docker version depending on OCP version
case $OCP_VERSION in
  3.9)
    DOCKER_VERSION="docker-1.13.1 "
    OPENSHIFT_UTILS="atomic-openshift-utils "
  ;;
  *)
    DOCKER_VERSION="docker "
    OPENSHIFT_UTILS="openshift-ansible "
  ;;
esac 

# Setup Docker and OpenShift Utils on the Nodes
#  CLEAN THIS SUDO STUFF UP, IF NEEDED
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#' | awk '{ print $2 }'`
do
  ssh -t $HOST << EOF
    uname -n
    sudo wget http://10.10.10.10/Scripts/docker_setup.sh
    echo "sudo yum -y install $OPENSHIFT_UTILS $DOCKER_VERSION"
    sudo yum -y install $OPENSHIFT_UTILS $DOCKER_VERSION
    sudo sh ./docker_setup.sh
EOF
  echo
done

# Make sure docker-storage-setup ran correctly
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#' | awk '{ print $2 }'`
do
  ssh $HOST "uname -n; sudo df -h /var/lib/docker"
  echo
done

exit 0

LETS_CREATE_A_SNAPSHOT() {

# Shutdown all the VMs, then take a snapshot
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`
do 
  echo "$HOST"
  #ssh -t $HOST "uname -n;  sudo shutdown now -h"
done

 # This can be found in ./NOTES.md also 
 # I still need to work on this.  The hosts with the extra disks (/dev/vdc) can not be snapshot'd since
 #   the disk has not been used and appears to be "raw" - Idunno...
 for HOST in `virsh list --all | grep OCP | grep "shut off" | awk '{ print $2 }'`; do virsh snapshot-create-as --domain $HOST --name "post-install-snap" --description "post_install.sh has been run"; done
 for HOST in `virsh list --all | grep OCP | grep "shut off" | awk '{ print $2 }'`; do virsh snapshot-list --domain $HOST ; done
 for HOST in `virsh list --all | grep OCP | grep "shut off" | awk '{ print $2 }'`; do virsh start $HOST ; done 
}
 

# Run this to disable error logging
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`
do
  ssh -t $HOST << EOF
    uname -n
    #sudo grep IOA /etc/systemd/system.conf.d/origin-accounting.conf
    sudo sed -i -e 's/DefaultBlockIOAccounting=yes/DefaultBlockIOAccounting=no/g' /etc/systemd/system.conf.d/origin-accounting.conf
EOF
  echo
done

