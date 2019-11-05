

# Work around to create and attach the third disk to the appropriate systems
for HOST in `egrep 'bst|inf|app' ../Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$HOST/${HOST}-2.qcow2; done

for HOST in `egrep 'bst|inf|app' ../Files/etc_hosts | awk '{ print $3 }' | tr [a-z] [A-Z]`; do virsh attach-disk $HOST --source /var/lib/libvirt/images/${HOST}/${HOST}-2.qcow2 --target='vdc' --persistent;  done


Issues
---
For some reason I cannot build a 3-disk system - it just hangs.

