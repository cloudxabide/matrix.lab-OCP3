#!/bin/bash

#
# @(#)$Id$
#
# Purpose:  Script to roll-out an OCP3 cluster
#  Author:  jradtke@redhat.com
#    Date:  2019-10-31
#   Notes:  This is NOT IaC yet.  :-(
#    TODO:  Need to figure out a better way for sending the password to ssh-copy-id

#set -o errexit
readonly LOG_FILE="/root/install_OCP3.sh.log"
echo "Output being redirected to log file - to see output:"
echo "tail -f $LOG_FILE"

touch $LOG_FILE
exec 1>$LOG_FILE 
exec 2>&1

# Make sure you're on the right host, else leave a message and exit 
[ `hostname -s` != "rh7-ocp3-bst01" ] && { echo "You are on the wrong host"; exit 9; }

git clone https://github.com/cloudxabide/matrix.lab
cd matrix.lab/Scripts

#  This entire script is intended to be run from the bastion host to all the nodes (the bastion included).
#  Therefore, notice that commands are prefaced by "sudo" and the ssh command includes a '-t'
#  SSH ControlSockets is likely the better/best way to actually be doing this work - but, this is just a lab and NOT 
#    how OCP should be installed anyhow.

# I may remove this later, as it might actually goof something up
echo -e "OCP_VERSION=3.11\nexport OCP_VERSION" >> ~/.bash_profile
. ~/.bash_profile

# How to manually subscribe 
#  subscription-manager register
#  subscription-manager refresh
#  POOLID=`subscription-manager list --available --matches 'Red Hat OpenShift Container Platform' | grep "Pool ID:" | awk '{ print $3 }' | tail -1`
#  subscription-manager attach --pool=$POOLID


# See if there is an ssh key, and create it if not
[ ! -f ~/.ssh/id_rsa ] && { echo | ssh-keygen -trsa -b2048 -N ''; }

# Alright - this next step is a bit "rammy".  HOWEVER... this host should only be used as the Bastion 
#   to an OCP3 Cluster (and, in my case, should not already have any customizations done)
cat << EOF > ~/.ssh/config
Host *.matrix.lab
  StrictHostKeyChecking no
EOF
chmod 0600 ~/.ssh/config

# Establish connectivity and sync ssh-keys to hosts (as root) 
# Need to figure out a IaC way of doing this
# Passw0rd
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do 
  ssh-copy-id $HOST
done
unalias rm
rm ~/.ssh/config

# Run the "post_install.sh" script on all the hosts (which adds user:mansible)
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | grep -v bst | awk '{ print $2 }'`
do 
  ssh -t $HOST "uname -n; sh ./post_install.sh" 
done

# Switch the connections to the mansible user 
cat << EOF > ~/.ssh/config
Host *.matrix.lab
  User mansible
EOF
chmod 0600 ~/.ssh/config

# Now, distribute the keys to the mansible user
# Passw0rd
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`; do ssh-copy-id $HOST; echo; done
# Test the connection (and sudo - which should have been done in a previous script)
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo grep mansible /etc/shadow"; echo ; done

######################################################################3
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
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do
  ssh -t $HOST << EOF
    uname -n
    sudo  $OCP_REPOS_MGMT
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

# Install openshift-ansible and docker on Bastion
yum -y install $OPENSHIFT_UTILS $DOCKER_VERSION 

# Configure Docker Storage (this section *may* be version specific also)
cat << EOF > /etc/sysconfig/docker-storage-setup
STORAGE_DRIVER=overlay2
VG=docker-vg
DEVS=/dev/vdb
CONTAINER_ROOT_LV_NAME="docker-root-lv"
CONTAINER_ROOT_LV_SIZE="100%FREE"
CONTAINER_ROOT_LV_MOUNT_PATH="/var/lib/docker"
EOF

docker-storage-setup
systemctl enable docker --now

# I made the NFS portion a "routine" as I don't think I'll end up using it (but wanted to retain it)
create_nfs_shares() {
# Create an NFS share for the registry on Bastion (VDC in this case)
parted -s /dev/vdc mklabel gpt mkpart pri ext4 2048s 100% set 1 lvm on
pvcreate /dev/vdc1 
vgcreate vg_exports /dev/vdc1
lvcreate -nlv_registry -L+10g vg_exports
lvcreate -nlv_metrics -L+10g vg_exports
mkfs.xfs /dev/mapper/vg_exports-lv_registry
mkfs.xfs /dev/mapper/vg_exports-lv_metrics

# semanage fcontext --list
yum -y install nfs-utils

mkdir -p /exports/nfs/ocp3.matrix.lab/{registry,metrics}
chmod 000 /exports/nfs/ocp3.matrix.lab/{registry,metrics}/
echo "/dev/mapper/vg_exports-lv_registry /exports/nfs/ocp3.matrix.lab/registry xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/vg_exports-lv_metrics /exports/nfs/ocp3.matrix.lab/metrics xfs defaults 0 0" >> /etc/fstab
mount -a 
chmod 2770 /exports/nfs/ocp3.matrix.lab/{registry,metrics}
chown nfsnobody:nfsnobody /exports/nfs/ocp3.matrix.lab/{registry,metrics}
ls -laZ /exports/nfs/ocp3.matrix.lab/* -d

echo "/exports/nfs/ocp3.matrix.lab/registry 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports
echo "/exports/nfs/ocp3.matrix.lab/metrics 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports
exportfs -a; exportfs

firewall-cmd --permanent --zone=$(firewall-cmd --get-default-zone) --add-service={nfs,mountd,rpc-bind}
firewall-cmd --reload
systemctl enable nfs-server.service  --now
}


# Setup Docker on the Nodes
#  CLEAN THIS SUDO STUFF UP, IF NEEDED
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | grep -v bst | awk '{ print $2 }'`
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
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | grep -v bst | awk '{ print $2 }'`
do
  ssh $HOST "uname -n; sudo df -h /var/lib/docker"
  echo
done

cp ~/matrix.lab/Files/ocp-${OCP_VERSION}-multiple_master_native_ha.yml ~/
# Update reg_auth_{user,password} manually
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ~/ocp-${OCP_VERSION}-multiple_master_native_ha.yml 
ansible-playbook -i ~/ocp-${OCP_VERSION}-multiple_master_native_ha.yml playbooks/prerequisites.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}-multiple_master_native_ha.yml playbooks/deploy_cluster.yml

for HOST in `grep mst0 ~/matrix.lab/Files/etc_hosts | awk '{ print $2 }'`; do ssh -t $HOST "sudo  htpasswd -b /etc/origin/master/htpasswd morpheus Passw0rd "; done

exit 0
Passw0rd

