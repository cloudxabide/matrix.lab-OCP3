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
  StrictHostKeyChecking no
EOF
chmod 0600 ~/.ssh/config

# Establish connectivity and sync ssh-keys to hosts (as root) 
# Need to figure out a IaC way of doing this
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do 
  echo -e "Passw0rd\n" | ssh-copy-id $HOST
done
# Remove the StrickHostKey line
sed -i -e '/StrictHostKeyChecking/d' ~/.ssh/config

# Run the "post_install.sh" script on all the hosts
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`
do 
  ssh -t $HOST "sh ./post_install.sh" 
done

# Update Bastion so that it now connects using "mansible"
cat << EOF > ~/.ssh/config
Host *.matrix.lab
  User mansible
EOF
chmod 0600 ~/.ssh/config

# Now, distribute the keys to the mansible user
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | awk '{ print $2 }'`; do ssh-copy-id $HOST; echo; done
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
    sudo subscription-manager repos --disable="*" --enable="rhel-7-server-rpms" --enable="rhel-7-server-extras-rpms" --enable="rhel-7-server-ose-3.11-rpms" --enable="rhel-7-server-ansible-2.6-rpms"
EOF
  echo
done

# Install supporting pakcages on Bastion
yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct

# Install openshift-ansible and docker on Bastion
yum -y install openshift-ansible docker
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

# Setup Docker on the Nodes
for HOST in `grep ocp3 ../Files/etc_hosts | grep -v \# | grep -v bst | awk '{ print $2 }'`
do
  ssh -t $HOST << EOF
    uname -n
    wget http://10.10.10.10/Scripts/docker_setup.sh
    sh ./docker_setup.sh
EOF
  echo
done

cp ../Files/ocp-3.11-multiple_mastes_native_ha.yml ~/
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ~/ocp-3.11-multiple_mastes_native_ha.yml 
ansible-playbook -i ~/ocp-3.11-multiple_mastes_native_ha.yml playbooks/prerequisites.yml

