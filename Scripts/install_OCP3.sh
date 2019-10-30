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
cat << EOF > /etc/sysconfig/docker-storage-setup
VG=docker-vg
DEVS=/dev/vdb
EOF
docker-storage-setup
systemctl enable docker --now

# Create an NFS share for the registry on Bastion (VDC in this case)
parted -s /dev/vdc mklabel gpt mkpart pri ext4 2048s 100% set 1 lvm on
pvcreate /dev/vdc1
vgcreate vg_exports /dev/vdc1
lvcreate -nlv_registry -L+10g vg_exports
mkfs.xfs /dev/mapper/vg_exports-lv_registry 

# semanage fcontext --list
yum -y install nfs-utils

mkdir -p /exports/nfs/ocp3.matrix.lab/registry
chmod 000 /exports/nfs/ocp3.matrix.lab/registry/
echo "/dev/mapper/vg_exports-lv_registry /exports/nfs/ocp3.matrix.lab/registry xfs defaults 0 0" >> /etc/fstab
mount -a 
chmod 2770 /exports/nfs/ocp3.matrix.lab/registry
chown nfsnobody:nfsnobody /exports/nfs/ocp3.matrix.lab/registry

echo "/exports/nfs/ocp3.matrix.lab/registry 10.10.10.0/24(rw,sync,no_root_squash)" >> /etc/exports
exportfs -a

firewall-cmd --permanent --zone=$(firewall-cmd --get-default-zone) --add-service={nfs,mountd,rpc-bind}
firewall-cmd --reload
systemctl enable nfs-server.service  --now

cp ../Files/ocp-3.11-multiple_mastes_native_ha.yml ~/
ansible all --list-hosts -i ~/ocp-3.11-multiple_mastes_native_ha.yml 
cd /usr/share/ansible/openshift-ansible
ansible-playbook -i ~/ocp-3.11-multiple_mastes_native_ha.yml playbooks/prerequisites.yml

