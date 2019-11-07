# NOTE.md


### Create and attach new disk to VMs (third disk)
```
# Work around to create and attach the third disk to the appropriate systems
cd matrix.lab/Scripts
for HOST in `egrep 'inf|app' ../Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 100g; done
qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/RH7-OCP3-BST01/RH7-OCP3-BST01-2.qcow2 50g
restorecon -RFvv /var/lib/libvirt/images/RH7-OCP3-{BST,INF,APP}*/RH7-OCP3-*2.qcow2

for HOST in `egrep 'bst|inf|app' ../Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do virsh attach-disk $HOST --source /var/lib/libvirt/images/${HOST}/${HOST}-2.qcow2 --target='vdc' --persistent;  done

```

# Issues
---
For some reason I cannot build a 3-disk system - it just hangs.

## Rebuilding the Lab - this is run on apoc (KVM Host)
```
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -rf /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done

for GUEST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep ocp | awk '{ print $3 }' | tr [a-z] [A-Z]`; do ./build_KVM.sh $GUEST; sleep 240; done

for HOST in `virsh list --all | grep -i ocp | awk '{ print $2 }'`; do virsh start $HOST; sleep 2; done
rm /home/jradtke/.ssh/known_hosts.matrix.lab

ssh-copy-id rh7-ocp3-bst01.matrix.lab 
ssh rh7-ocp3-bst01.matrix.lab "sh /root/post_install.sh"
# proceed to install_OCP3.sh script
```

### Update Login Password
Discovered this as I had put the plain-text password in my inventory.. Ugh.
for HOST in `grep -v \#  ~/matrix.lab/Files/etc_hosts | grep mst0 | awk '{ print $3 }'`; do ssh $HOST  "sudo htpasswd -b /etc/origin/master/htpasswd ocpadmin Passw0rd"; done
