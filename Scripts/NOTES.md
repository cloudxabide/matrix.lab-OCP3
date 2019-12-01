# NOTE.md

NOTES:
* I had to modify this to be "host aware" - I.e. install certain VMs on one Hypervisor and the others on the other.k

## TODO

Fix this (output from build_KVM.sh):
DONE -  ERROR    Unknown OS name 'rhel7.7'. See `osinfo-query os` for valid values.


## Rebuilding the Lab - this is run on apoc (KVM Host) (and now morpheus)

```
# Teardown 
# Passw0rd
ssh rh7-ocp3-bst01.matrix.lab
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | grep -v \# | awk '{ print $2 }'`; do ssh $HOST "uname -n; sudo subscription-manager unregister"; echo ; done

ssh apoc.matrix.lab morpheus.matrix.lab
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh snapshot-delete $HOST post-install-snap; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -rf /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done

# Do this on ALL the Hypervisors (and zion)
# Base OS Install (VM provision)
[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; }
cd ~/matrix.lab/Scripts/; git pull
# SLEEPYTIME=xxx - Time, in seconds, before script should start to build next VM (it's
# TEST THE FOLLOWING WITH THE NEXT RUN (added that "countdown")
#### BUILD   
SLEEPYTIME=240; 
case `hostname -s` in 
  apoc)
    for GUEST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep ocp | egrep '1$|3$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done; done
  ;;
  morpheus)
    for GUEST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep ocp | egrep '2$|4$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done; done
    ./build_KVM.sh RH7-OCP3-MST
  ;;
esac

# Now, go execute the install_OCP3.sh procedure

#### CREATE DISKS 
# Create and attach new disk to VMs (third disk)
# Work around to create and attach the third disk to the appropriate systems
#  ADD THE DISK *AFTER* YOU TAKE SNAPSHOTS/
case `hostname -s` in
  apoc)
    for HOST in `egrep 'ocs0' ~/matrix.lab/Files/etc_hosts | egrep '1$|3$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 120g; done
    for HOST in `egrep 'ocs1' ~/matrix.lab/Files/etc_hosts | egrep '1$|3$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 110g; done
  ;;
  morpheus)
    for HOST in `egrep 'ocs0' ~/matrix.lab/Files/etc_hosts | egrep '2$|4$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 120g; done
    for HOST in `egrep 'ocs1' ~/matrix.lab/Files/etc_hosts | egrep '2$|4$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 110g; done
  ;;
esac
# Uncomment this if you would like to use /dev/vdc for NFS
#qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/RH7-OCP3-BST01/RH7-OCP3-BST01-2.qcow2 50g

# Set the correct SELinux context
restorecon -RFvv /var/lib/libvirt/images/RH7-OCP3-{APP,BST,INF,MST,OCS}*/RH7-OCP3-*2.qcow2

#### ATTACH THE DISK
case `hostname -s` in
  apoc)
    for HOST in `egrep 'ocs' ~/matrix.lab/Files/etc_hosts | egrep '1$|3$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do virsh attach-disk $HOST --source /var/lib/libvirt/images/${HOST}/${HOST}-2.qcow2 --target='vdc' --persistent;  done
  ;;
  morpheus)
    for HOST in `egrep 'ocs' ~/matrix.lab/Files/etc_hosts | egrep '2$|4$' | awk '{ print $3 }' | tr [a-z] [A-Z]`; do virsh attach-disk $HOST --source /var/lib/libvirt/images/${HOST}/${HOST}-2.qcow2 --target='vdc' --persistent;  done
  ;;
esac

# START THE VMS
for HOST in `virsh list --all | grep -i ocp | awk '{ print $2 }'`; do echo "$HOST"; virsh start $HOST; echo; sleep 2; done
```

## Build the bastion
```
sed -i -e '/ocp3/d' ~/.ssh/known_hosts
sed -i -e '/ocp3/d' ~/.ssh/known_hosts.matrix.lab
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
for HOST in `virsh list --all | grep OCP | egrep 'OCS' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'OCS' | awk '{ print $2 }'`; do virsh setmem $HOST --size 6G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'INF' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 4G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'INF' | awk '{ print $2 }'`; do virsh setmem $HOST --size 4G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST|APP' | awk '{ print $2 }'`; do virsh setmaxmem $HOST --size 5G --config; done
for HOST in `virsh list --all | grep OCP | egrep 'MST|APP' | awk '{ print $2 }'`; do virsh setmem $HOST --size 5G --config; done
```

## Issues
---
For some reason I cannot build a 3-disk system - it just hangs.

