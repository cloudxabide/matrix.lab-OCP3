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
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo subscription-manager unregister"; echo ; done
```

### Teardown (remove VMs)

```
# ssh to apoc.matrix.lab morpheus.matrix.lab
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh snapshot-delete $HOST post-install-snap; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -rf /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done
```

### Build VMs
Do this on ALL the Hypervisors (and zion)  
# Base OS Install (VM provision)  

```
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; }
cd ~/matrix.lab/Scripts/; git pull
# SLEEPYTIME=xxx - Time, in seconds, before script should start to build next VM (it's
SLEEPYTIME=240; 
case `hostname -s` in 
  apoc)
    for GUEST in `grep -v \# ~/matrix.lab/Files/etc_hosts | grep ocp | egrep -v 'bst|ocs' | egrep '1$|3$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done; done
  ;;
  morpheus)
    for GUEST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep ocp | egrep -v 'bst|ocs' | egrep '2$|4$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done; done
    # Build the Load Balancer (which has no numeric representation in the hostname, nor VM name)
    ./build_KVM.sh RH7-OCP3-MST; sleep $SLEEPYTIME
  ;;
  sati)
    # Don't rebuild the bastion every time any longer...
    ./build_KVM.sh RH7-OCP3-BST01; sleep $SLEEPYTIME
  ;;
esac
```

## Finish up the bastion
```
sed -i -e '/ocp3/d' ~/.ssh/known_hosts
sed -i -e '/ocp3/d' ~/.ssh/known_hosts.matrix.lab
ssh-copy-id rh7-ocp3-bst01.matrix.lab
ssh rh7-ocp3-bst01.matrix.lab "sh /root/post_install.sh"  # This will reboot the bastion

ssh rh7-ocp3-bst01.matrix.lab
HYPERVISORS="apoc morpheus zion sati"
for HYPERVISOR in $HYPERVISORS
do 
  ssh-copy-id $HYPERVISOR
done

for HYPERVISOR in $HYPERVISORS
do
  ssh -t $HYPERVISOR "cd matrix.lab; git pull"
done

# START THE VMS 
for HOST in `virsh list --all | grep -i ocp | awk '{ print $2 }'`; do echo "$HOST"; virsh start $HOST; echo; sleep 2; done
#  Wait about 3 minutes for things to settle
```

### Make a copy of the config, then copy it to bastion
NOTE:  This is klunky and sucks, not worth the time to clean it up though.
``` 
OCP_VERSION=3.11
### THE FOLLOWING WILL NEED TO BE DONE MANUALLY (AND PROBABLY SHOULD ANYHOW)
cp ~/matrix.lab/Files/ocp-${OCP_VERSION}*.yml /tmp/
# The following updates RHN info, or update reg_auth_{user,password} manually
sed -i -e 's/<rhnuser>/PutYourRHNUserHere/'g /tmp/ocp-${OCP_VERSION}*.yml
sed -i -e 's/<rhnpass>/PutYourRHNPassHere/'g /tmp/ocp-${OCP_VERSION}*.yml
scp /tmp/ocp-${OCP_VERSION}*.yml rh7-ocp3-bst01.matrix.lab:
```

# Prep the environment (install sshkeys, etc...)
```
ssh -t rh7-ocp3-bst01.matrix.lab << EOF
(which git) || yum -y install git
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; }
cd ~/matrix.lab/Scripts
sh ./install_OCP3.sh
EOF
```

## Run the (actual) OCP Ansible Playbooks now:
```
ssh -t rh7-ocp3-bst01.matrix.lab << EOF
cd /usr/share/ansible/openshift-ansible
# The following *absolutely* makes an assumption that there is only ONE inventory file in your home dir.  Update accordingly
ansible all --list-hosts -i ~/ocp-${OCP_VERSION}*.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/prerequisites.yml
ansible-playbook -i ~/ocp-${OCP_VERSION}*.yml playbooks/deploy_cluster.yml
EOF
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
# for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd ocpadmin Passw0rd"; done
```

## Update Memory settings on the VMs
```
for HOST in `virsh list --all | grep OCP | egrep 'OCS' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'OCS' | awk '{ print $2 }'`; do virsh setmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'INF|APP' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 8G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'INF|APP' | awk '{ print $2 }'`; do virsh setmem $HOST --size 8G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 8G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST' | awk '{ print $2 }'`; do virsh setmem $HOST --size 8G --config; done
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

for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`
do
  ssh -t $HOST << EOF
    uname -n
    #sudo grep IOA /etc/systemd/system.conf.d/origin-accounting.conf
    sudo sed -i -e 's/DefaultBlockIOAccounting=yes/DefaultBlockIOAccounting=no/g' /etc/systemd/system.conf.d/origin-accounting.conf
EOF
  echo
done

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
