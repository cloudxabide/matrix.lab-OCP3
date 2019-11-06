# NOTES.md


```
# Work around to create and attach the third disk to the appropriate systems
cd matrix.lab/Scripts
for HOST in `egrep 'inf|app' ../Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2 100g; done
restorecon -RFvv /var/lib/libvirt/images/RH7-OCP3-{INF,APP}*/RH7-OCP3-*2.qcow2

for HOST in `egrep 'inf|app' ../Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do virsh attach-disk $HOST --source /var/lib/libvirt/images/${HOST}/${HOST}-2.qcow2 --target='vdc' --persistent;  done
```

# Issues
---
For some reason I cannot build a 3-disk system - it just hangs.

## Rebuilding the Lab
```
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -rf /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done

for GUEST in `grep -v \#  ../Files/etc_hosts | grep ocp | awk '{ print $3 }' | tr [a-z] [A-Z]`; do ./build_KVM.sh $GUEST; sleep 240; done

for HOST in `virsh list --all | grep -i ocp | awk '{ print $2 }'`; do virsh start $HOST; done
ssh rh7-ocp3-bst01.matrix.lab "sh /root/post_install.sh"
```
