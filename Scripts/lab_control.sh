#!/bin/bash

# TODO:  I'll make this accept parameters - for now it's just to build

example() {
HYPERVISORS="apoc neo trinty morpheus"
for HYPERVISOR in $HYPERVISORS
do
  ssh -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts
    nohup ./lab_control.sh build &
EOF
done
}

# Make sure lab is up-to-date
get_to_gittin() {
HYPERVISORS="apoc neo trinity morpheus zion sati"
for HYPERVISOR in $HYPERVISORS
do
  ssh -t $HYPERVISOR << EOF
  (which git) || yum -y install git
  [ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
EOF
done
}

[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts/; } || { cd ~/matrix.lab/Scripts/; git pull; }

SLEEPYTIME=200;
HYPERVISOR=`hostname -s`
for GUEST in `grep -v \# .myconfig | grep  $HYPERVISOR | awk -F: '{ print $1 }'`
do
  echo "./build_KVM.sh $GUEST"
  COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done;
done

teardown() {

for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh snapshot-delete $HOST post-install-snap; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -f /var/lib/libvirt/images/$HOST/*; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rmdir /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done
}

startup() {
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh start $HOST; done
}
exit 0
