# NOTE.md

## TODO
Need to mount sdb as /var/lib/libvirt/images/SDB
Need to mount sdc as /var/lib/libvirt/images/SDC
Refactor how to:  create VMs, do the foundational stuff, take a snapshot, add the disk (vdc) - current order will not allow things to work

Fix this (output from build_KVM.sh):
  ERROR    Unknown OS name 'rhel7.7'. See `osinfo-query os` for valid values.


## Rebuilding the Lab - this is run on apoc (KVM Host)

```
# Teardown 
# Passw0rd
ssh apoc.matrix.lab
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do ssh -t $HOST "sudo subscription-manager unregister"; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh snapshot-delete $HOST post-install-snap; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -rf /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done

# Base OS Install (VM provision)
cd ~/matrix.lab/Scripts/; git pull
SLEEPYTIME=180 # In seconds
# TEST THE FOLLOWING WITH THE NEXT RUN (added that "countdown")
for GUEST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep ocp | awk '{ print $3 }' | tr [a-z] [A-Z]`; do ./build_KVM.sh $GUEST; while [ $SLEEPYTIME -gt 0 ]; do echo -ne "$SLEEPYTIME\033[0K\r"; sleep 1; : $((SLEEPYTIME--)); done; done

while [ $SLEEPYTIME -gt 0 ]; do echo -ne "$SLEEPYTIME\033[0K\r"; sleep 1; : $((SLEEPYTIME--)); done
# Create and attach new disk to VMs (third disk)
# Work around to create and attach the third disk to the appropriate systems
#  ADD THE DISK *AFTER* YOU TAKE SNAPSHOTS/
for HOST in `egrep 'inf' ~/matrix.lab/Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 102g; done
for HOST in `egrep 'ocs' ~/matrix.lab/Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 120g; done
# Uncomment this if you would like to use /dev/vdc for NFS
#qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/RH7-OCP3-BST01/RH7-OCP3-BST01-2.qcow2 50g
restorecon -RFvv /var/lib/libvirt/images/RH7-OCP3-{APP,BST,INF,MST,OCS}*/RH7-OCP3-*2.qcow2

for HOST in `egrep 'inf|ocs' ~/matrix.lab/Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do virsh attach-disk $HOST --source /var/lib/libvirt/images/${HOST}/${HOST}-2.qcow2 --target='vdc' --persistent;  done

for HOST in `virsh list --all | grep -i ocp | awk '{ print $2 }'`; do virsh start $HOST; sleep 2; done
```

```
sed -i -e '/ocp3/d' /home/jradtke/.ssh/known_hosts
sed -i -e '/ocp3/d' /home/jradtke/.ssh/known_hosts.matrix.lab
ssh-copy-id rh7-ocp3-bst01.matrix.lab 
ssh rh7-ocp3-bst01.matrix.lab "sh /root/post_install.sh"
# proceed to install_OCP3.sh script, then come back to do snapshots
```

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
for HOST in `virsh list --all | grep OCP | egrep -v 'BST|MST|OCS' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep -v 'BST|MST|OCS' | awk '{ print $2 }'`; do virsh setmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 4G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST' | awk '{ print $2 }'`; do virsh setmem $HOST --size 4G --config; done
```

## Issues
---
For some reason I cannot build a 3-disk system - it just hangs.

