# NOTE.md

NOTES:
* I had to modify this to be "host aware" - I.e. install certain VMs on one Hypervisor and the others on the other.k
* STATUS:  This is absolutely not ready for prime time.  The bits are here, but need to be re-organized.

## TODO
--
  figure out how to alternate builds between the X# of hypervisors.  I.e. provide a list of (somewhat) equal nodes and just keep cycling between them.

## Issues
---
## Rebuilding the Lab - this is run on apoc (KVM Host) (and now morpheus)

## Teardown (unregister nodes)
```
# Passw0rd
ssh rh7-ocp3-bst01.matrix.lab
HYPERVISORS="apoc neo trinity morpheus"
for HOST in $HYPERVISORS; do ssh -t $HOST "matrix.lab/Scripts/lab_control.sh teardown &"; done
for HOST in $HYPERVISORS; do ssh -t $HOST "cd matrix.lab/Scripts/; nohup ./lab_control.sh build &  "; done 
for HOST in $HYPERVISORS; do ssh -t $HOST "virsh list --all"; done

```

### Build VMs
Do this on ALL the Hypervisors (and zion)  
# Base OS Install (VM provision)  

```
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; } || { cd ~/matrix.lab/Scripts/; git pull; }
# SLEEPYTIME=xxx - Time, in seconds, before script should start to build next VM (it's
SLEEPYTIME=200; 
HYPERVISOR=`hostname -s`
for GUEST in `grep -v \# .myconfig | grep  $HYPERVISOR | awk -F: '{ print $1 }'`
do 
  cd ~/matrix.lab/Scripts
  echo "./build_KVM.sh $GUEST"
  COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done;
done

## OLD METHOD - I'm leaving this as I might need it later
#case `hostname -s` in 
#  apoc)
#    for GUEST in `grep -v \# ~/matrix.lab/Files/etc_hosts | grep ocp | egrep -v 'bst|ocs' | egrep '1$|3$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done; done
#  ;;
#  morpheus)
#    for GUEST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep ocp | egrep -v 'bst|ocs' | egrep '2$|4$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done; done
#    # Build the Load Balancer (which has no numeric representation in the hostname, nor VM name)
#    ./build_KVM.sh RH7-OCP3-PROXY; sleep $SLEEPYTIME
#  ;;
#  sati)
#    # Don't rebuild the bastion every time any longer...
#    ./build_KVM.sh RH7-OCP3-BST01; sleep $SLEEPYTIME
#  ;;
#esac
```

## Finish up the bastion
```
sed -i -e '/ocp3/d' ~/.ssh/known_hosts
ssh-copy-id rh7-ocp3-bst01.matrix.lab
ssh rh7-ocp3-bst01.matrix.lab "sh /root/post_install.sh"  # This will reboot the bastion

ssh rh7-ocp3-bst01.matrix.lab
HYPERVISORS="apoc neo trinity morpheus zion sati"
for HOST in $HYPERVISORS
do 
  ssh-copy-id $HOST
done

HYPERVISORS="apoc neo trinity morpheus zion sati"
for HYPERVISOR in $HYPERVISORS
do
  ssh -t $HYPERVISOR << EOF
  (which git) || yum -y install git
  [ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
EOF
done

# START THE VMS  (need to make this executable via SSH)
for HOST in `/usr/bin/sudo /usr/bin/virsh list --all | grep -i ocp | awk '{ print $2 }'`; do echo "$HOST"; /usr/bin/sudo /usr/bin/virsh start $HOST; echo; sleep 2; done
#  Wait about 3 minutes for things to settle
```

## Go and prep all the nodes
```
ssh -t rh7-ocp3-bst01.matrix.lab << EOF
(which git) || yum -y install git
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; } || {  cd ~/matrix.lab/Scripts; }
sh ./OCP3_prep_hosts.sh
EOF
```

### Make a copy of the config, then copy it to bastion
## Run the (actual) OCP Ansible Playbooks now:
```
### THE FOLLOWING WILL NEED TO BE DONE MANUALLY (AND PROBABLY SHOULD ANYHOW)
cp ~/matrix.lab/Files/ocp-${OCP_VERSION}-multiple_master_native_ha.yml ~/
# If you need to wipe /dev/vdc after snapshots (this needs to be tested)
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; [ -b /dev/vdc ] && sudo wipefs -a /dev/vdc"; echo ; done

# The following *absolutely* makes an assumption that there is only ONE inventory file in your home dir.  
#    Update accordingly
#
# The following updates RHN info, or update reg_auth_{user,password} manually
cd ~/matrix.lab/Scripts/
cp ocp-3.11-multiple_master_native_ha-2xOCS.yml ocp-3.11-multiple_master_native_ha-2xOCS-pre.yml ~
sed -i -e 's/<rhnuser>/PutYourRHNUserHere/'g ~/ocp-${OCP_VERSION}*.yml
sed -i -e 's/<rhnpass>/PutYourRHNPassHere/'g ~/ocp-${OCP_VERSION}*.yml
# 
# The prereqs can be executed with the Gluster components present in the Inventory
INVENTORY="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS.yml"
INVENTORY_NOGLUSTER="${HOME}/ocp-3.11-multiple_master_native_ha-2xOCS-noGluster.yml"
cd /usr/share/ansible/openshift-ansible
ansible all --list-hosts -i ${INVENTORY} 
# Run preReqs with full inventory (will succeed)
nohup ansible-playbook -i ${INVENTORY} playbooks/prerequisites.yml -vvv | tee 01-ocp_prerequisites-`date +%F`.logs &
# Run deploy_cluster with full inventory (will fail with "GlusterFS pods not found")
nohup ansible-playbook -i ${INVENTORY} playbooks/deploy_cluster.yml -vvv | tee 02-ocp_deploy_cluster-`date +%F`.logs &
# Run deploy_cluster with Gluster resources removed (will succeed)
nohup ansible-playbook -i ${INVENTORY_NOGLUSTER} playbooks/deploy_cluster.yml -vvv | tee 03-ocp_deploy_cluster_noGluster-`date +%F`.logs &
# Run deploy_cluster with Gluster present again (will succeed)
nohup ansible-playbook -i ${INVENTORY_NOGLUSTER} playbooks/openshift-glusterfs/config.yml -vvv | tee 03-ocp_deploy_cluster-noGluster-`date +%F`.logs &

# NOTE:  this is where things become unclear.... do I just run the full inventory, or do I have to run the remaining playbooks manually/individually 
# Run deploy_cluster with full inventory (will succeed)
nohup ansible-playbook -i ~/ocp-3.11-multiple_master_native_ha-2xOCS.yml playbooks/deploy_cluster.yml -vvv | tee 05-ocp_deploy_cluster-noGluster-`date +%F`.logs &


ansible-playbook --flush-cache ...
```

## Create Snapshots, if you want to.  (Shutdown the VM though)
```
for HOST in `virsh list --all | grep OCP | grep "shut off" | awk '{ print $2 }'`; do virsh snapshot-create-as --domain $HOST --name "post-install-snap" --description "post_install.sh has been run"; done 
for HOST in `virsh list --all | grep OCP | grep "shut off" | awk '{ print $2 }'`; do virsh start $HOST ; done 
```

## Update Login Password for OCP console
Discovered this as I had put the plain-text password in my inventory.. Ugh.
This is how you update the htpasswd on the masters
```
# for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST.matrix.lab  "sudo htpasswd -b /etc/origin/master/htpasswd ocpadmin Passw0rd"; done
```

## Update Memory settings on the VMs
```
#  OCS Nodes
for HOST in `virsh list --all | grep OCP | egrep 'OCS' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'OCS' | awk '{ print $2 }'`; do virsh setmem $HOST --size 6G --config; done
#  INF/APP Nodes
for HOST in `virsh list --all | grep OCP | egrep 'INF|APP' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 8G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'INF|APP' | awk '{ print $2 }'`; do virsh setmem $HOST --size 8G --config; done
#  MASTERS
for HOST in `virsh list --all | grep OCP | egrep 'MST' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 8G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST' | awk '{ print $2 }'`; do virsh setmem $HOST --size 8G --config; done
#
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do  virsh setvcpus --count 2 $HOST --config; done

```

## Random Stuff
### THE FOLLOWING WILL NEED TO BE DONE MANUALLY (AND PROBABLY SHOULD ANYHOW)
cp ~/matrix.lab/Files/ocp-${OCP_VERSION}-multiple_master_native_ha.yml /tmp/
# The following updates RHN info, or update reg_auth_{user,password} manually
sed -i -e 's/<rhnuser>/PutYourRHNUserHere/'g /tmp/ocp-${OCP_VERSION}*.yml
sed -i -e 's/<rhnpass>/PutYourRHNPassHere/'g /tmp/ocp-${OCP_VERSION}*.yml
scp /tmp/ocp-${OCP_VERSION}*.yml rh7-ocp3-bst01.matrix.lab:

ssh -t rh7-ocp3-bst01.matrix.lab << 
cd /usr/share/ansible/openshift-ansible
# The following *absolutely* makes an assumption that there is only ONE inventory file in your home dir.  Update accordingly
ansible all --list-hosts -i ~/ocp-${OCP_VERSION}*.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/prerequisites.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/deploy_cluster.yml
EOF
```

### NFS Server
```
###############################
#### NFS STUFF
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
```



### LETS_CREATE_A_SNAPSHOT
```

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
```

### Disable Error Logging for IOAccounting
```
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
```
Random Bits
```
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo subscription-manager unregister"; echo ; done
```
