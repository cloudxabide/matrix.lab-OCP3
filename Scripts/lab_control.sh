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
  echo "Connecting to: $HYPERVISOR"
  ssh -l root -t $HYPERVISOR << EOF
  (which git) || yum -y install git
  [ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts; } || { cd ~/matrix.lab/Scripts; git pull; }
  [ -d /var/www/html ] && { chcon -Rvv -t httpd_sys_content_t /var/www/html/*; }
EOF
done
}

##################################### ##########################################
build_VMS() {
HYPERVISOR=`hostname -s`
echo "Deploying VMs"
for GUEST in `grep -v \# .myconfig | grep $HYPERVISOR | awk -F: '{ print $1 }'`
do
  SLEEPYTIME=200
  echo "./build_KVM.sh $GUEST"
  # build_KVM.sh will exit with a 9 if the guest already exists.  If so, set the wait timer to 5.
  ./build_KVM.sh $GUEST; if [ $? -eq "9" ]; then SLEEPYTIME=5; fi
  COUNTER=${SLEEPYTIME}; 
  while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done;
done
}

unregister_VMS() {
for HOST in `grep ocp3 ~/matrix.lab/Files/etc_hosts | egrep -v '#|bst' | awk '{ print $2 }'`
do 
  ssh -l root -t $HOST "uname -n; sudo subscription-manager unregister"
  echo
done

} 
##################################### ##########################################
teardown_VMS() {
for HOST in `virsh list --all | grep OCP | egrep -v 'BST' | awk '{ print $2 }'`; do virsh snapshot-delete $HOST post-install-snap; done
for HOST in `virsh list --all | grep OCP | egrep -v 'BST' | awk '{ print $2 }'`; do virsh destroy $HOST; done
for HOST in `virsh list --all | grep OCP | egrep -v 'BST' | awk '{ print $2 }'`; do rm -f /var/lib/libvirt/images/$HOST/*; done
for HOST in `virsh list --all | grep OCP | egrep -v 'BST' | awk '{ print $2 }'`; do rmdir /var/lib/libvirt/images/$HOST; done
for HOST in `virsh list --all | grep OCP | egrep -v 'BST' | awk '{ print $2 }'`; do virsh undefine  $HOST; done
# I don't recommend you do the following unless you REALLY know it's going to do what you want
find /etc/libvirt/storage/ -name "*OCP3*" ! -name "*BST*" -exec rm {} \; 
systemctl restart libvirtd
}

##################################### ##########################################
start_VMS() {
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do virsh start $HOST; done
}

create_snapshot_VMS(){
for HOST in `virsh list --all | grep OCP | grep "shut off" | awk '{ print $2 }'`; do echo "Create Snapshot for $HOST"; virsh snapshot-create-as --domain $HOST --name "post-install-snap" --description "post_install.sh has been run"; done
}

delete_snapshot_VMS(){
for HOST in `virsh list --all | grep OCP | awk '{ print $2 }'`; do echo "Delete Snapshot for $HOST"; virsh snapshot-delete $HOST post-install-snap; done
}

if [ $# -ne 1 ]; then usage; fi
echo "##################### ######################"
echo "conntected to `hostname` at `date`"

case $1 in 
  start) start_VMS ;;
  stop) stop ;;
  build) build_VMS ;;
  teardown) teardown_VMS ;;
  update) update ;;
  gitpull) get_to_gittin ;;
  createsnapshot) create_snapshot_VMS ;;
  deletesnapshot) delete_snapshot_VMS ;;
  *) usage ;;
esac
echo 

exit 0
