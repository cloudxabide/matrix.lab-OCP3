#!/bin/bash

# TODO:  I'll make this accept parameters - for now it's just to build
#        OK - I have realized this script sucks - should it be run from the bastion, from the nodes?

usage() {
  echo "ERROR:"
  echo "usage:  ${0} <build|stop|start|update>"
  echo ""
  exit 9 
}
 
example() {
HYPERVISORS="apoc neo trinity morpheus"
for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR << EOF
    cd ~/matrix.lab/Scripts
    nohup ./lab_control.sh build &
EOF
done
}

##################################### ##########################################
# Make sure lab is up-to-date
get_to_gittin() {
HYPERVISORS="apoc neo trinity morpheus zion sati"
for HYPERVISOR in $HYPERVISORS
do
  ssh -l root -t $HYPERVISOR << EOF
  (which git) || yum -y install git
  [ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
EOF
done
}

##################################### ##########################################
build_VMS() {
SLEEPYTIME=200;
HYPERVISOR=`hostname -s`
echo "Deploying VMs"
for GUEST in `grep -v \# .myconfig | grep  $HYPERVISOR | awk -F: '{ print $1 }'`
do
  echo "./build_KVM.sh $GUEST"
  COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done;
done
}

##################################### ##########################################
teardown_VMS() {
sudo subscription-manager unregister
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh snapshot-delete $HOST post-install-snap; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rm -f /var/lib/libvirt/images/$HOST/*; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do rmdir /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh undefine  $HOST; done
# I don't recommend you do the following unless you REALLY know it's going to do what you want
find /etc/ -name "*OCP3*" -exec rm {} \; 
systemctl restart libvirtd
}

##################################### ##########################################
start_VMS() {
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh start $HOST; done
}

if [ $# -ne 1 ]; then usage; fi

case $1 in 
  start) start_VMS ;;
  stop) stop ;;
  build) build_VMS ;;
  teardown) teardown_VMS ;;
  update) update ;;
  gitpull) get_to_gittin ;;
  *) usage ;;
esac

exit 0
