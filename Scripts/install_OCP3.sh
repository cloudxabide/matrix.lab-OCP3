#!/bin/bash


# git clone https://github.com/cloudxabide/matrix.lab
# cd matrix.lab/Scripts
# ./
# Passw0rd
#  This entire script is intended to be run from the bastion host to all the nodes (the bastion included).
#  Therefore, notice that commands are prefaced by "sudo" and the ssh command includes a '-t'
#  SSH ControlSockets is likely the better/best way to actually be doing this work - but, this is just a lab and NOT 
#    how OCP should be installed anyhow.

# How to subscribe
#  subscription-manager register
#  subscription-manager refresh
#  POOLID=`subscription-manager list --available --matches 'Red Hat OpenShift Container Platform' | grep "Pool ID:" | awk '{ print $3 }' | tail -1`
#  subscription-manager attach --pool=$POOLID

# Alright - this next step is a bit "rammy".  HOWEVER... this host should only be used as the Bastion 
#   to an OCP3 Cluster (and, in my case, should not already have any customizations done)
cat << EOF > ~/.ssh/config
Host *.matrix.lab
  User mansible
  StrictHostKeyChecking no
EOF
chmod 0600 ~/.ssh/config

# Establish connectivity and sync ssh-keys to hosts
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do 
  echo ssh-copy-id $HOST
done
# Remove the StrickHostKey line
sed -i -e '/StrictHostKeyChecking/d' ~/.ssh/config

# Test the connection (and sudo - which should have been done in a previous script)
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo grep mansible /etc/shadow"; echo ; done

######################################################################3
## NOTE: 
## NOTE - if the previous command failed to display the mansible information - you need to fix sudo (see: post_install.sh)
## NOTE: 
######################################################################3
# Update the Repos on the hosts
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do 
  ssh -t $HOST << EOF
    uname -n
    sudo subscription-manager repos --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-server-ose-3.11-rpms" --enable="rhel-7-server-ansible-2.6-rpms"
EOF
  echo
done

# Install supporting pakcages on Bastion
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct

# Install openshift-ansible on Bastion
yum -y install openshift-ansible
yum -y install docker
