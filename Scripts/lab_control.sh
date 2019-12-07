#!/bin/bash

# TODO:  I'll make this accept parameters - for now it's just to build

[ ! -d ~/matrix.lab ] && { cd; git clone https://github.com/cloudxabide/matrix.lab; cd ~/matrix.lab/Scripts/; } || { cd ~/matrix.lab/Scripts/; git pull; }

SLEEPYTIME=200;
HYPERVISOR=`hostname -s`
for GUEST in `grep -v \# .myconfig | grep  $HYPERVISOR | awk -F: '{ print $1 }'`
do
  echo "./build_KVM.sh $GUEST"
  COUNTER=${SLEEPYTIME}; ./build_KVM.sh $GUEST; while [ $COUNTER -gt 0 ]; do echo -ne "Proceed in: $COUNTER\033[0K\r"; sleep 1; : $((COUNTER--)); done;
done

